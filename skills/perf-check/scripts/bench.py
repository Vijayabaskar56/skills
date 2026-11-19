#!/usr/bin/env python3
"""Usage: bench.py --repo DIR --out DIR [--screen NAME] [--allow-debug] [--allow-busy]

Benchmarks each screen in DIR/.perf-check.json on a connected Android device: every open starts
from the home link and records a Perfetto trace with the frame timeline, then presses back once;
a scripted scroll is scored from gfxinfo. Writes OUT/run.json and the traces, prints one line per
metric. Exits 2 when the device or build cannot give a fair number (screen off, debuggable build,
busy host, app not in front), 1 when every open of a screen was invalid.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scorelib  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TRACE_DIR = "/data/misc/perfetto-traces"
BUSY_WAIT_SECONDS = 120


def die(code, message):
    print(f"error {message}")
    sys.exit(code)


def sh(*args, check=True):
    result = subprocess.run(args, capture_output=True, text=True)
    if check and result.returncode != 0:
        die(2, f"{' '.join(args[:4])} failed: {result.stderr.strip()[:200]}")
    return result.stdout


class Device:
    def __init__(self, serial):
        self.serial = serial

    def adb(self, *args, check=True):
        return sh("adb", "-s", self.serial, *args, check=check)

    def shell(self, command, check=True):
        return self.adb("shell", command, check=check)

    def size(self):
        out = self.shell("wm size")
        m = re.search(r"Override size: (\d+)x(\d+)", out) or re.search(r"Physical size: (\d+)x(\d+)", out)
        return int(m.group(1)), int(m.group(2))

    def foreground(self):
        out = self.shell("dumpsys activity activities | grep -m1 topResumedActivity", check=False)
        return out.strip()

    def view(self, url, package):
        self.shell(f"am start -a android.intent.action.VIEW -d '{url}' {package}", check=False)


def pick_serial(configured):
    lines = sh("adb", "devices").splitlines()[1:]
    serials = [line.split()[0] for line in lines if line.strip().endswith("device")]
    if configured:
        if configured not in serials:
            die(2, f"configured device {configured} is not connected; connected: {serials or 'none'}")
        return configured
    if not serials:
        die(2, "no Android device connected over adb")
    return serials[0]


def preflight(dev, cfg, args):
    package = cfg["android"]["package"]
    power = dev.shell("dumpsys power | grep -m1 mWakefulness=", check=False)
    if "Awake" not in power:
        die(2, "screen is off: wake and unlock the device (a trace of a dark screen scores as a perfect run)")
    if "isKeyguardShowing=true" in dev.shell("dumpsys window | grep -m1 isKeyguardShowing", check=False):
        die(2, "device is locked: unlock it")
    flags = dev.shell(f"dumpsys package {package} | grep -m1 'flags=\\['", check=False)
    if not flags:
        die(2, f"{package} is not installed")
    debuggable = "DEBUGGABLE" in flags
    if debuggable and not args.allow_debug:
        die(2, "the installed build is debuggable: install a release build (install-release.sh); debug native code runs several times slower")
    limit = (os.cpu_count() or 8) * 1.5
    waited = 0
    while os.getloadavg()[0] > limit and waited < BUSY_WAIT_SECONDS and not args.allow_busy:
        if waited == 0:
            print(f"wait host load {os.getloadavg()[0]:.0f} is above {limit:.0f}; waiting up to {BUSY_WAIT_SECONDS}s for it to drop")
        time.sleep(10)
        waited += 10
    load = os.getloadavg()[0]
    busy = load > limit
    if busy and not args.allow_busy:
        die(2, f"host load average is {load:.0f}: wait for builds and other agents, or pass --allow-busy")
    rate = re.search(r"renderFrameRate ([\d.]+)", dev.shell("dumpsys display | grep -m1 renderFrameRate", check=False))
    model = dev.shell("getprop ro.product.model").strip()
    return {"debuggable": debuggable, "busyHost": busy, "refreshHz": round(float(rate.group(1))) if rate else None, "model": model}


def relaunch(dev, package, settle):
    dev.shell(f"am force-stop {package}")
    dev.shell(f"monkey -p {package} -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1", check=False)
    time.sleep(settle)
    if package not in dev.foreground():
        die(2, f"{package} is not in front after launch: {dev.foreground()}")


def trace_open(dev, cfg, url, local_path, seconds):
    package = cfg["android"]["package"]
    with open(os.path.join(HERE, "..", "assets", "perfetto.cfg")) as f:
        text = f.read().replace("__PACKAGE__", package).replace("__DURATION_MS__", str(seconds * 1000))
    remote = f"{TRACE_DIR}/perf-check.pftrace"
    dev.shell(f"rm -f {remote}", check=False)
    proc = subprocess.Popen(
        ["adb", "-s", dev.serial, "shell", f"perfetto --txt -c - -o {remote}"],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True,
    )
    proc.stdin.write(text)
    proc.stdin.close()
    time.sleep(1.5)
    dev.shell(f"dumpsys gfxinfo {package} reset >/dev/null", check=False)
    dev.view(url, package)
    proc.wait(timeout=seconds + 30)
    dev.adb("pull", remote, local_path)
    dev.shell(f"rm -f {remote}", check=False)


def scroll(dev, package, w, h, flings):
    x = w // 2
    dev.shell(f"dumpsys gfxinfo {package} reset >/dev/null", check=False)
    for _ in range(flings):
        dev.shell(f"input swipe {x} {int(h * 0.79)} {x} {int(h * 0.25)} 220")
        time.sleep(0.9)
    for _ in range(flings // 2):
        dev.shell(f"input swipe {x} {int(h * 0.3)} {x} {int(h * 0.8)} 180")
        time.sleep(0.9)
    time.sleep(1)
    return dev.shell(f"dumpsys gfxinfo {package}")


def crashes_since(dev, package, since):
    out = dev.adb("logcat", "-d", "-b", "crash", "-T", since, check=False)
    found, current = [], None
    for line in out.splitlines():
        if "FATAL EXCEPTION" in line:
            current = {"time": " ".join(line.split()[:2])}
        elif current is not None and f"Process: {package}" in line:
            found.append(current)
        elif current is not None and "first" not in current and re.search(r"(Error|Exception)\b", line):
            current["first"] = line.split("AndroidRuntime: ", 1)[-1].strip()[:160]
    return found


def bench_screen(dev, cfg, screen, out_dir, w, h):
    package = cfg["android"]["package"]
    home = cfg["android"]["home"]
    opens, invalid = [], []
    rounds = screen.get("rounds", 2)
    seconds = screen.get("traceSeconds", 7)
    for r in range(rounds):
        for item in screen["ids"]:
            dev.view(home, package)
            time.sleep(3)
            url = screen["open"].replace("{id}", str(item))
            path = os.path.join(out_dir, f"{screen['name']}-open-{r + 1}-{item}.pftrace")
            trace_open(dev, cfg, url, path, seconds)
            metrics = scorelib.open_metrics(path, package)
            metrics["id"] = item
            metrics["trace"] = os.path.basename(path)
            (opens if metrics["valid"] else invalid).append(metrics)
            print(f"open {screen['name']} {item} round {r + 1}: " + (
                f"missed {metrics['missedMs']}ms worst {metrics['worstFrameMs']}ms" if metrics["valid"] else f"invalid: {metrics['reason']}"
            ))
            dev.shell("input keyevent 4")
            time.sleep(2)
            if package not in dev.foreground():
                print("note back left the app; relaunching so the next open starts from home")
                relaunch(dev, package, cfg["android"].get("settleSeconds", 8))
    if not opens:
        die(1, f"every open of {screen['name']} was invalid: {invalid[:1]}")

    result = {"open": {k: scorelib.median_of(opens, k) for k in ("missedMs", "worstFrameMs", "framesOver50Ms", "mainMaxMs", "missedFrames")},
              "openRuns": opens, "invalidOpens": invalid}
    worst = max(opens, key=lambda m: m["missedMs"])
    worst_trace = os.path.join(out_dir, worst["trace"])
    result["openTriage"] = scorelib.triage(worst_trace, package, w, h)
    result["openLongFrames"] = scorelib.long_frames(worst_trace, package)
    for f in result["openTriage"][:6]:
        print(f"culprit {screen['name']} {f['culprit']} {f.get('costMs', 0)}ms {f['detail']}")

    if screen.get("scroll", True):
        dev.view(home, package)
        time.sleep(3)
        dev.view(screen["open"].replace("{id}", str(screen["ids"][0])), package)
        time.sleep(cfg["android"].get("settleSeconds", 8))
        runs = []
        for i in range(screen.get("scrollRuns", 2)):
            text = scroll(dev, package, w, h, screen.get("flings", 6))
            with open(os.path.join(out_dir, f"{screen['name']}-scroll-{i + 1}.gfxinfo.txt"), "w") as f:
                f.write(text)
            runs.append(scorelib.scroll_metrics(text))
            print(f"scroll {screen['name']} run {i + 1}: p50 {runs[-1]['p50Ms']}ms p90 {runs[-1]['p90Ms']}ms janky {runs[-1]['jankyPct']}%")
        result["scroll"] = {k: scorelib.median_of(runs, k) for k in ("p50Ms", "p90Ms", "p99Ms", "jankyPct", "over16MsPct", "slowBitmapUploads")}
        result["scrollRuns"] = runs
    return result


def main():
    parser = argparse.ArgumentParser(description="Android frame benchmark for the screens in .perf-check.json")
    parser.add_argument("--repo", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--screen")
    parser.add_argument("--allow-debug", action="store_true")
    parser.add_argument("--allow-busy", action="store_true")
    args = parser.parse_args()

    config_path = os.path.join(args.repo, ".perf-check.json")
    if not os.path.exists(config_path):
        die(2, f"{config_path} is missing: follow references/first-run.md")
    with open(config_path) as f:
        cfg = json.load(f)
    screens = [s for s in cfg["screens"] if not args.screen or s["name"] == args.screen]
    if not screens:
        die(2, f"no screen named {args.screen} in .perf-check.json")
    os.makedirs(args.out, exist_ok=True)

    dev = Device(pick_serial(cfg["android"].get("serial", "")))
    device = preflight(dev, cfg, args)
    w, h = dev.size()
    device.update({"serial": dev.serial, "width": w, "height": h})
    print(f"device {device['model']} {w}x{h} {device['refreshHz']}Hz debuggable={device['debuggable']}")
    started = dev.shell("date '+%m-%d %H:%M:%S.000'").strip()
    relaunch(dev, cfg["android"]["package"], cfg["android"].get("settleSeconds", 8))

    head = subprocess.run(["git", "-C", args.repo, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "-C", args.repo, "status", "--porcelain", "--untracked-files=no"], capture_output=True, text=True).stdout.strip())
    run = {
        "date": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "sha": head, "dirty": dirty, "device": device, "screens": {},
    }
    for screen in screens:
        run["screens"][screen["name"]] = bench_screen(dev, cfg, screen, args.out, w, h)
    run["crashes"] = crashes_since(dev, cfg["android"]["package"], started)
    for c in run["crashes"]:
        print(f"crash {c['time']} {c.get('first', '')}")

    with open(os.path.join(args.out, "run.json"), "w") as f:
        json.dump(run, f, indent=2)
    print(f"run {os.path.join(args.out, 'run.json')}")


if __name__ == "__main__":
    main()
