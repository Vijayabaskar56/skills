#!/usr/bin/env python3
"""Usage: compare.py BASELINE.json CURRENT.json [--pct 20] [--abs-ms 5] [--abs-pts 1.5]

Compares two bench.py run.json files metric by metric and prints a table. A metric regresses when
it grows by more than --pct percent AND by more than the absolute floor (--abs-ms for millisecond
metrics, --abs-pts for percentage metrics), so tiny metrics cannot fail on noise. Exits 1 when any
metric regresses, 2 when the runs are not comparable (different device model or refresh rate).
"""

import argparse
import json
import sys

METRICS = [
    ("open", "missedMs", "ms"),
    ("open", "worstFrameMs", "ms"),
    ("open", "mainMaxMs", "ms"),
    ("open", "framesOver50Ms", "count"),
    ("scroll", "p50Ms", "ms"),
    ("scroll", "p90Ms", "ms"),
    ("scroll", "p99Ms", "ms"),
    ("scroll", "jankyPct", "pts"),
    ("scroll", "over16MsPct", "pts"),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline")
    parser.add_argument("current")
    parser.add_argument("--pct", type=float, default=20)
    parser.add_argument("--abs-ms", type=float, default=5)
    parser.add_argument("--abs-pts", type=float, default=1.5)
    args = parser.parse_args()
    with open(args.baseline) as f:
        base = json.load(f)
    with open(args.current) as f:
        cur = json.load(f)

    for key in ("model", "refreshHz"):
        if base["device"].get(key) != cur["device"].get(key):
            print(f"error not comparable: baseline {key}={base['device'].get(key)} current {key}={cur['device'].get(key)}")
            sys.exit(2)

    floors = {"ms": args.abs_ms, "pts": args.abs_pts, "count": 2}
    regressed = []
    print(f"baseline {base['sha']} {base['date']}  current {cur['sha']}{' (dirty)' if cur.get('dirty') else ''} {cur['date']}")
    print(f"{'screen':<12}{'metric':<22}{'baseline':>10}{'current':>10}{'change':>9}  verdict")
    for name, screen in cur["screens"].items():
        old = base["screens"].get(name)
        if old is None:
            print(f"{name:<12}{'(new screen, no baseline)':<22}")
            continue
        for section, metric, unit in METRICS:
            b = (old.get(section) or {}).get(metric)
            c = (screen.get(section) or {}).get(metric)
            if b is None or c is None:
                continue
            change = (c - b) / b * 100 if b else (100.0 if c else 0.0)
            worse = c > b and change > args.pct and (c - b) > floors[unit]
            better = c < b and -change > args.pct and (b - c) > floors[unit]
            verdict = "REGRESSED" if worse else "improved" if better else "same"
            if worse:
                regressed.append(f"{name}.{section}.{metric}")
            print(f"{name:<12}{section + '.' + metric:<22}{b:>10}{c:>10}{change:>8.0f}%  {verdict}")
    if cur.get("crashes"):
        print(f"crashes during run: {len(cur['crashes'])}")
    print("FAIL " + ", ".join(regressed) if regressed else "PASS")
    sys.exit(1 if regressed else 0)


if __name__ == "__main__":
    main()
