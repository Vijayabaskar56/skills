#!/usr/bin/env node
// Usage: perf-compare.mjs <baseline.json> <current.json> [thresholdPct=20]
// Prints one row per flow and metric and exits 1 when any gated metric grew by more than
// thresholdPct and by more than its noise floor. Exits 2 on bad input.
import { readFileSync } from "node:fs";

const [basePath, currentPath, thresholdArg] = process.argv.slice(2);
if (!basePath || !currentPath) {
  console.error("usage: perf-compare.mjs <baseline.json> <current.json> [thresholdPct=20]");
  process.exit(2);
}
const threshold = Number(thresholdArg ?? 20);
if (!Number.isFinite(threshold) || threshold < 0) {
  console.error(`thresholdPct must be a non-negative number, got ${thresholdArg}`);
  process.exit(2);
}

// A regression must clear the percentage AND this absolute floor, so 1 -> 2 slow commits or a
// 3 ms wobble on a 10 ms commit does not fail a ship. durationMs is wall time and not gated.
const FLOORS = {
  commits: 5,
  fiberRenders: 50,
  slowCommits: 2,
  slowCommitMs: 30,
  maxCommitMs: 10,
  jsBusyMs: 100,
  gcMs: 30,
};

const load = (path) => {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    console.error(`cannot read ${path}: ${error.message}`);
    process.exit(2);
  }
};
const base = load(basePath);
const current = load(currentPath);
if (!base.flows || !current.flows) {
  console.error("both files need a top-level `flows` object");
  process.exit(2);
}

const rows = [];
let regressions = 0;
for (const [flow, baseMetrics] of Object.entries(base.flows)) {
  const now = current.flows[flow];
  if (!now) {
    rows.push([flow, "-", "-", "-", "-", "MISSING"]);
    regressions++;
    continue;
  }
  for (const [metric, floor] of Object.entries(FLOORS)) {
    const was = baseMetrics[metric];
    const is = now[metric];
    if (typeof was !== "number" || typeof is !== "number") continue;
    const delta = is - was;
    const pct = was === 0 ? (is === 0 ? 0 : Infinity) : (delta / was) * 100;
    const regressed = pct > threshold && delta > floor;
    if (regressed) regressions++;
    const status = regressed
      ? "REGRESSED"
      : pct > threshold
        ? "under floor"
        : pct < -threshold && -delta > floor
          ? "better"
          : "ok";
    const pctText = Number.isFinite(pct) ? `${pct >= 0 ? "+" : ""}${pct.toFixed(0)}%` : "new";
    rows.push([flow, metric, String(was), String(is), pctText, status]);
  }
}

const header = ["flow", "metric", "baseline", "current", "change", "status"];
const widths = header.map((h, i) => Math.max(h.length, ...rows.map((r) => r[i].length)));
const line = (cells) => cells.map((c, i) => c.padEnd(widths[i])).join("  ").trimEnd();
console.log(`baseline ${base.sha ?? "?"} (${base.date ?? "?"})  current ${current.sha ?? "?"}  threshold ${threshold}%`);
for (const [label, file] of [["baseline", base], ["current", current]]) {
  if (file.source?.changedDuringRun) console.log(`warn ${label}: source changed while measuring`);
  if (file.busyCpu) console.log(`warn ${label}: measured while a build used the CPU`);
  if (base.device && file.device && file.device !== base.device) {
    console.log(`warn ${label}: measured on ${file.device}, baseline on ${base.device}`);
  }
}
console.log(line(header));
for (const row of rows) console.log(line(row));
console.log(regressions ? `FAIL ${regressions} regression(s)` : "PASS no regressions");
process.exit(regressions ? 1 : 0);
