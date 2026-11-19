"""Usage: imported by bench.py and triage.py; not run directly.

Scoring shared by bench.py and triage.py: Perfetto frame timeline, gfxinfo and culprit signatures.
"""

import re
import statistics

from perfetto.trace_processor import TraceProcessor

MIN_COST_MS = 1.5


def _rows(tp, sql):
    return list(tp.query(sql))


def _app(tp, package):
    rows = _rows(tp, f"select upid, pid from process where name = '{package}'")
    if not rows:
        return None
    return rows[0]


def open_metrics(trace_path, package):
    """Frame cost of one screen open. `valid` is False when the app drew no frames (screen off, crash)."""
    tp = TraceProcessor(trace=trace_path)
    try:
        app = _app(tp, package)
        if app is None:
            return {"valid": False, "reason": "app process not in trace"}
        frames = _rows(tp, f"select dur, jank_type from actual_frame_timeline_slice where upid = {app.upid}")
        if len(frames) < 10:
            return {"valid": False, "reason": f"only {len(frames)} frames: screen off, app not in front, or it crashed"}
        missed = [f.dur / 1e6 for f in frames if f.jank_type and "App Deadline Missed" in f.jank_type]
        main = [
            r.dur / 1e6
            for r in _rows(
                tp,
                f"""select s.dur from slice s join thread_track tt on s.track_id = tt.id join thread t using(utid)
                    where t.upid = {app.upid} and t.tid = {app.pid} and s.depth = 0 and s.name like 'Choreographer#doFrame%'""",
            )
        ]
        return {
            "valid": True,
            "frames": len(frames),
            "missedFrames": len(missed),
            "missedMs": round(sum(missed), 1),
            "worstFrameMs": round(max(missed, default=0), 1),
            "framesOver50Ms": sum(1 for d in missed if d > 50),
            "mainMaxMs": round(max(main, default=0), 1),
            "mainOver33Ms": sum(1 for d in main if d > 33),
        }
    finally:
        tp.close()


def scroll_metrics(gfxinfo_text):
    """Frame stats from `dumpsys gfxinfo <package>` after a scripted scroll."""

    def grab(pattern, cast=float):
        m = re.search(pattern, gfxinfo_text, re.M)
        return cast(m.group(1)) if m else None

    return {
        "frames": grab(r"^Total frames rendered: (\d+)", int),
        "jankyPct": grab(r"^Janky frames: \d+ \(([\d.]+)%\)"),
        "over16MsPct": grab(r"^Janky frames \(legacy\): \d+ \(([\d.]+)%\)"),
        "p50Ms": grab(r"^50th percentile: (\d+)ms"),
        "p90Ms": grab(r"^90th percentile: (\d+)ms"),
        "p99Ms": grab(r"^99th percentile: (\d+)ms"),
        "gpuP90Ms": grab(r"^90th gpu percentile: (\d+)ms"),
        "slowBitmapUploads": grab(r"^Number Slow bitmap uploads: (\d+)", int),
    }


def median_of(runs, key):
    values = [r[key] for r in runs if r.get(key) is not None]
    return round(statistics.median(values), 1) if values else None


def triage(trace_path, package, screen_w, screen_h):
    """Known costly patterns in a trace, most expensive first. Each finding names a culprit id from references/culprits.md."""
    tp = TraceProcessor(trace=trace_path)
    findings = []
    try:
        app = _app(tp, package)
        if app is None:
            return [{"culprit": "no-app", "detail": "app process not in trace"}]
        in_app = f"(select utid from thread where upid = {app.upid})"
        screen_px = screen_w * screen_h

        bitmap_sizes = {
            re.search(r"(\d+x\d+)", r.name).group(1)
            for r in _rows(
                tp,
                f"""select distinct s.name from slice s join thread_track tt on s.track_id = tt.id
                    where tt.utid in {in_app} and s.name like 'Bitmap#prepareToDraw%'""",
            )
            if re.search(r"(\d+x\d+)", r.name)
        }
        shadow_masks = {}
        uploads = _rows(
            tp,
            f"""select s.name, count(*) n, sum(s.dur) / 1e6 ms, max(s.dur) / 1e6 mx
                from slice s join thread_track tt on s.track_id = tt.id
                where tt.utid in {in_app} and s.name like 'Texture upload%'
                group by substr(s.name, instr(s.name, ')') + 2) order by ms desc""",
        )
        for u in uploads:
            m = re.search(r"(\d+)x(\d+)", u.name)
            if not m:
                continue
            w, h = int(m.group(1)), int(m.group(2))
            if f"{w}x{h}" in bitmap_sizes:
                continue
            if w == h and w * h >= screen_px * 0.4:
                culprit = "svg-raster"
            elif w > screen_w:
                culprit = "cpu-shadow-blur"
            elif w == screen_w and h == screen_h:
                culprit = "full-screen-bitmap"
            elif w * h >= screen_px * 0.5:
                culprit = "oversized-bitmap"
            else:
                continue
            if culprit == "cpu-shadow-blur":
                masks = shadow_masks.setdefault(w, {"n": 0, "ms": 0.0, "heights": set()})
                masks["n"] += u.n
                masks["ms"] += u.ms
                masks["heights"].add(h)
                continue
            findings.append(
                {"culprit": culprit, "costMs": round(u.ms, 1), "detail": f"texture upload {w}x{h} x{u.n}, worst {u.mx:.1f}ms"}
            )
        for w, masks in shadow_masks.items():
            findings.append(
                {
                    "culprit": "cpu-shadow-blur",
                    "costMs": round(masks["ms"], 1),
                    "detail": f"{masks['n']} blur masks {w}px wide in {len(masks['heights'])} heights (upload time only; the CPU blur costs more)",
                }
            )

        for b in _rows(
            tp,
            f"""select s.name, count(*) n, sum(s.dur) / 1e6 ms from slice s join thread_track tt on s.track_id = tt.id
                where tt.utid in {in_app} and s.name like 'Bitmap#prepareToDraw%' group by s.name order by ms desc limit 5""",
        ):
            m = re.search(r"(\d+)x(\d+)", b.name)
            if m and int(m.group(1)) * int(m.group(2)) >= screen_px * 0.3:
                findings.append(
                    {"culprit": "oversized-bitmap", "costMs": round(b.ms, 1), "detail": f"bitmap {m.group(1)}x{m.group(2)} decoded at full size x{b.n}"}
                )

        web = _rows(
            tp,
            f"""select count(*) n, coalesce(sum(s.dur), 0) / 1e6 ms from slice s join thread_track tt on s.track_id = tt.id
                where tt.utid in {in_app} and s.name like 'WebViewFunctor::draw%'""",
        )[0]
        if web.n:
            findings.append({"culprit": "eager-webview", "costMs": round(web.ms, 1), "detail": f"a WebView drew {web.n} times"})

        for t in _rows(
            tp,
            f"""select t.name, sum(sc.dur) / 1e6 ms from sched sc join thread t using(utid)
                where t.upid = {app.upid} and (t.name like 'GL-Map%' or t.name like 'androidmapsapi%')
                group by t.name having ms > 20 order by ms desc""",
        ):
            findings.append({"culprit": "live-map", "costMs": round(t.ms, 1), "detail": f"{t.name} used {t.ms:.0f}ms CPU"})

        creates = {
            r.name: (r.n, r.ms)
            for r in _rows(
                tp,
                f"""select substr(s.name, instr(s.name, '(') + 1, length(s.name) - instr(s.name, '(') - 1) name,
                       count(*) n, sum(s.dur) / 1e6 ms
                    from slice s join thread_track tt on s.track_id = tt.id
                    where tt.utid in {in_app} and s.name like 'SurfaceMountingManager::createViewUnsafe%' group by 1""",
            )
        }
        text_n, text_ms = creates.get("RCTText", (0, 0))
        if text_n >= 150:
            findings.append(
                {"culprit": "text-heavy-mount", "costMs": round(text_ms, 1), "detail": f"{text_n} Text views created ({text_ms / max(text_n, 1):.2f}ms each)"}
            )
        svg_n = sum(n for k, (n, _) in creates.items() if k.startswith("RNSVG"))
        svg_ms = sum(ms for k, (_, ms) in creates.items() if k.startswith("RNSVG"))
        if svg_n >= 60:
            findings.append({"culprit": "svg-heavy-mount", "costMs": round(svg_ms, 1), "detail": f"{svg_n} SVG nodes created"})

        findings = [f for f in findings if f.get("costMs", 0) >= MIN_COST_MS]
        findings.sort(key=lambda f: -f.get("costMs", 0))
        return findings
    finally:
        tp.close()


def long_frames(trace_path, package, threshold_ms=33, limit=8):
    """The slowest main-thread frames, split into mount (animation) and draw (traversal) time."""
    tp = TraceProcessor(trace=trace_path)
    try:
        app = _app(tp, package)
        if app is None:
            return []
        out = []
        for f in _rows(
            tp,
            f"""select s.id, s.ts, s.dur from slice s join thread_track tt on s.track_id = tt.id join thread t using(utid)
                where t.upid = {app.upid} and t.tid = {app.pid} and s.depth = 0 and s.name like 'Choreographer#doFrame%'
                and s.dur > {threshold_ms}e6 order by s.dur desc limit {limit}""",
        ):
            phases = {
                r.name: round(r.ms, 1)
                for r in _rows(
                    tp,
                    f"""select name, sum(dur) / 1e6 ms from descendant_slice({f.id})
                        where name in ('animation', 'traversal', 'Record View#draw()', 'postAndWait',
                                       'MountItemDispatcher::mountViews preMountItems',
                                       'MountItemDispatcher::mountViews mountItems to execute') group by name""",
                )
            }
            views = _rows(
                tp,
                f"""select substr(name, instr(name, '(') + 1, length(name) - instr(name, '(') - 1) kind, count(*) n
                    from descendant_slice({f.id}) where name like 'SurfaceMountingManager::createViewUnsafe%'
                    group by 1 order by n desc limit 4""",
            )
            out.append(
                {
                    "frameMs": round(f.dur / 1e6, 1),
                    "mountMs": phases.get("animation", 0),
                    "drawMs": phases.get("Record View#draw()", 0),
                    "waitRenderThreadMs": phases.get("postAndWait", 0),
                    "created": {v.kind: v.n for v in views},
                }
            )
        return out
    finally:
        tp.close()
