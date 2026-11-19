#!/usr/bin/env python3
"""Usage: bench-tap.py --repo DIR --out DIR [--interaction NAME] [--allow-debug] [--allow-busy]

Benchmarks the taps in DIR/.perf-check.json `interactions` on a connected Android device: a tap that
navigates (opens a screen in-app, leaves one, switches a tab), which a deep-link open cannot reach.
Each round runs the interaction's `before` steps to reach its start state, checks the `expect` id,
traces the tap with Perfetto and scores it. Writes OUT/interactions.json and the traces, prints one
line per round and the medians. Exits 2 when the device or build cannot give a fair number, 1 when
the start state could not be reached or every round was invalid.

Metrics, per round:
  tapToJsFreeMs   end of the JS thread's first busy block after the tap (runs merged across gaps
                  under 60 ms, blocks under 10 ms skipped); a navigation cannot start animating
                  before it, so this is the freeze the user feels before anything moves
  slideMissedMs   App Deadline Missed time from JS free to JS free + slideMs (the transition)
  afterMissedMs   the same for the 3 s after the transition
  slideViews      views created during the transition (work that should wait until it settles)
"""

import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench  # noqa: E402
import scorelib  # noqa: E402
from perfetto.trace_processor import TraceProcessor  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
#! The JS thread can wait on the UI thread for tens of ms between a press handler and the render it
#! schedules; work deferred until a transition settles starts hundreds of ms later.
JS_GAP_NS = 60_000_000
JS_MIN_RUN_NS = 1_000_000
#! A press handler can run for a few ms before the render it schedules; skip blocks shorter than this.
JS_MIN_BLOCK_NS = 10_000_000


def ui_nodes(dev):
    dev.shell("uiautomator dump /sdcard/bench-tap.xml >/dev/null", check=False)
    xml = dev.shell("cat /sdcard/bench-tap.xml", check=False)
    nodes = []
    for m in re.finditer(r"<node [^>]*>", xml):
        node = m.group(0)
        rid = re.search(r'resource-id="([^"]*)"', node).group(1)
        box = list(map(int, re.findall(r"\d+", re.search(r'bounds="([^"]*)"', node).group(1))))
        nodes.append((rid, box))
    return nodes


def find(nodes, test_id, index=0):
    """`id` matches exactly; `prefix*` matches ids that start with prefix. `index` picks the nth match."""
    if test_id.endswith("*"):
        matches = [b for rid, b in nodes if rid.startswith(test_id[:-1])]
    else:
        matches = [b for rid, b in nodes if rid == test_id]
    return matches[index] if len(matches) > index else None


def centre(box):
    return (box[0] + box[2]) // 2, (box[1] + box[3]) // 2


def run_step(dev, cfg, step):
    package = cfg["android"]["package"]
    if "link" in step:
        dev.view(step["link"], package)
    elif "tap" in step:
        box = find(ui_nodes(dev), step["tap"], step.get("tapIndex", 0))
        if box is None:
            return None if step.get("optional") else f"no element {step['tap']} to tap"
        dev.shell("input tap {} {}".format(*centre(box)))
    elif "scrollTop" in step:
        w, h = dev.size()
        for _ in range(step["scrollTop"]):
            dev.shell(f"input swipe {w // 2} {int(h * 0.3)} {w // 2} {int(h * 0.9)} 150")
            time.sleep(0.4)
    elif "scrollDown" in step:
        w, h = dev.size()
        for _ in range(step["scrollDown"]):
            dev.shell(f"input swipe {w // 2} {int(h * 0.55)} {w // 2} {int(h * 0.25)} 300")
            time.sleep(0.6)
    elif "key" in step:
        dev.shell(f"input keyevent {step['key']}")
    time.sleep(step.get("wait", 3))
    return None


def reach_start(dev, cfg, interaction):
    for step in interaction.get("before", []):
        problem = run_step(dev, cfg, step)
        if problem:
            return None, problem
    nodes = ui_nodes(dev)
    if interaction.get("expect") and find(nodes, interaction["expect"]) is None:
        return None, f"start state not reached: {interaction['expect']} is not on screen"
    box = find(nodes, interaction["tap"], interaction.get("tapIndex", 0))
    if box is None:
        return None, f"start state not reached: no {interaction['tap']} to tap"
    return centre(box), None


def trace_tap(dev, cfg, x, y, path, seconds):
    package = cfg["android"]["package"]
    with open(os.path.join(HERE, "..", "assets", "perfetto.cfg")) as f:
        text = f.read().replace("__PACKAGE__", package).replace("__DURATION_MS__", str(seconds * 1000))
    remote = f"{bench.TRACE_DIR}/bench-tap.pftrace"
    dev.shell(f"rm -f {remote}", check=False)
    proc = subprocess.Popen(
        ["adb", "-s", dev.serial, "shell", f"perfetto --txt -c - -o {remote}"],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True,
    )
    proc.stdin.write(text)
    proc.stdin.close()
    time.sleep(1.5)
    dev.shell(f"input tap {x} {y}")
    proc.wait(timeout=seconds + 30)
    dev.adb("pull", remote, path)
    dev.shell(f"rm -f {remote}", check=False)


def tap_metrics(path, package, slide_ms):
    tp = TraceProcessor(trace=path)
    try:
        app = scorelib._app(tp, package)
        if app is None:
            return {"valid": False, "reason": "app process not in trace"}
        taps = scorelib._rows(tp, f"""select s.ts from slice s join thread_track tt on s.track_id = tt.id
            join thread t using(utid) where t.upid = {app.upid} and s.name like 'deliverInputEvent%' order by s.ts""")
        js = scorelib._rows(tp, f"select utid from thread where upid = {app.upid} and name like 'mqt%js%'")
        if not taps or not js:
            return {"valid": False, "reason": "no input event or no JS thread in the trace"}
        tap = taps[-1].ts
        runs = scorelib._rows(tp, f"""select ts, dur from sched where utid = {js[0].utid}
            and ts + dur > {tap} and ts < {tap + 2_000_000_000} and dur >= {JS_MIN_RUN_NS} order by ts""")
        blocks = []
        for r in runs:
            start = max(r.ts, tap)
            if blocks and start - blocks[-1][1] <= JS_GAP_NS:
                blocks[-1][1] = max(blocks[-1][1], r.ts + r.dur)
            else:
                blocks.append([start, r.ts + r.dur])
        work = next((b for b in blocks if b[1] - b[0] >= JS_MIN_BLOCK_NS), blocks[0] if blocks else [tap, tap])
        block_end = work[1]
        slide_end = block_end + slide_ms * 1_000_000
        frames = scorelib._rows(tp, f"select ts, dur, jank_type from actual_frame_timeline_slice where upid = {app.upid}")

        def missed(lo, hi):
            return round(sum(f.dur / 1e6 for f in frames
                             if lo <= f.ts < hi and f.jank_type and "App Deadline Missed" in f.jank_type), 1)

        views = scorelib._rows(tp, f"""select count(*) n from slice s join thread_track tt on s.track_id = tt.id
            join thread t using(utid) where t.upid = {app.upid} and s.ts >= {block_end} and s.ts < {slide_end}
            and s.name like 'SurfaceMountingManager::createViewUnsafe%'""")
        return {
            "valid": True,
            "tapToJsFreeMs": round((block_end - tap) / 1e6, 1),
            "slideMissedMs": missed(block_end, slide_end),
            "afterMissedMs": missed(slide_end, slide_end + 3_000_000_000),
            "slideViews": views[0].n,
        }
    finally:
        tp.close()


def bench_interaction(dev, cfg, interaction, out_dir, w, h):
    rounds, invalid = [], []
    seconds = interaction.get("traceSeconds", 6)
    for i in range(interaction.get("rounds", 8)):
        point, problem = reach_start(dev, cfg, interaction)
        if problem:
            bench.die(1, f"{interaction['name']} round {i + 1}: {problem}")
        path = os.path.join(out_dir, f"{interaction['name']}-{i + 1}.pftrace")
        trace_tap(dev, cfg, *point, path, seconds)
        m = tap_metrics(path, cfg["android"]["package"], interaction.get("slideMs", 500))
        m["trace"] = os.path.basename(path)
        (rounds if m["valid"] else invalid).append(m)
        print(f"tap {interaction['name']} round {i + 1}: " + (
            " ".join(f"{k}={m[k]}" for k in ("tapToJsFreeMs", "slideMissedMs", "afterMissedMs", "slideViews"))
            if m["valid"] else f"invalid: {m['reason']}"))
        time.sleep(2)
    if not rounds:
        bench.die(1, f"every round of {interaction['name']} was invalid: {invalid[:1]}")
    keys = ("tapToJsFreeMs", "slideMissedMs", "afterMissedMs", "slideViews")
    median = {k: statistics.median(r[k] for r in rounds) for k in keys}
    print(f"median {interaction['name']}: " + " ".join(f"{k}={v}" for k, v in median.items()))
    worst = max(rounds, key=lambda r: r["slideMissedMs"])
    triage = scorelib.triage(os.path.join(out_dir, worst["trace"]), cfg["android"]["package"], w, h)
    for f in triage[:5]:
        print(f"culprit {interaction['name']} {f['culprit']} {f.get('costMs', 0)}ms {f['detail']}")
    return {"median": median, "rounds": rounds, "invalid": invalid, "triage": triage}


def main():
    parser = argparse.ArgumentParser(description="Android frame benchmark for in-app taps in .perf-check.json")
    parser.add_argument("--repo", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--interaction")
    parser.add_argument("--allow-debug", action="store_true")
    parser.add_argument("--allow-busy", action="store_true")
    args = parser.parse_args()

    with open(os.path.join(args.repo, ".perf-check.json")) as f:
        cfg = json.load(f)
    interactions = [i for i in cfg.get("interactions", []) if not args.interaction or i["name"] == args.interaction]
    if not interactions:
        bench.die(2, "no matching `interactions` in .perf-check.json: see references/interactions.md")
    os.makedirs(args.out, exist_ok=True)

    dev = bench.Device(bench.pick_serial(cfg["android"].get("serial", "")))
    device = bench.preflight(dev, cfg, args)
    w, h = dev.size()
    print(f"device {device['model']} {w}x{h} {device['refreshHz']}Hz debuggable={device['debuggable']}")
    bench.relaunch(dev, cfg["android"]["package"], cfg["android"].get("settleSeconds", 8))

    result = {"device": device, "interactions": {}}
    for interaction in interactions:
        result["interactions"][interaction["name"]] = bench_interaction(dev, cfg, interaction, args.out, w, h)
    with open(os.path.join(args.out, "interactions.json"), "w") as f:
        json.dump(result, f, indent=2)
    print(f"run {os.path.join(args.out, 'interactions.json')}")


if __name__ == "__main__":
    main()
