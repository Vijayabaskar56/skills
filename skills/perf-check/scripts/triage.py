#!/usr/bin/env python3
"""Usage: triage.py TRACE.pftrace --package PKG --size WxH

Names the known costly patterns in one Perfetto trace, most expensive first, and lists the slowest
main-thread frames split into mount and draw time. Culprit ids match references/culprits.md.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scorelib  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("trace")
    parser.add_argument("--package", required=True)
    parser.add_argument("--size", required=True, help="device screen in pixels, for example 1260x2800")
    args = parser.parse_args()
    w, h = (int(v) for v in args.size.lower().split("x"))

    findings = scorelib.triage(args.trace, args.package, w, h)
    if not findings:
        print("culprits none of the known patterns")
    for f in findings:
        print(f"culprit {f['culprit']:<20} {f.get('costMs', 0):>7.1f}ms  {f['detail']}")
    for frame in scorelib.long_frames(args.trace, args.package):
        created = ", ".join(f"{k} x{v}" for k, v in frame["created"].items())
        print(
            f"frame {frame['frameMs']:>6.1f}ms  mount {frame['mountMs']}ms  draw {frame['drawMs']}ms"
            f"  wait-render {frame['waitRenderThreadMs']}ms  created: {created or '-'}"
        )


if __name__ == "__main__":
    main()
