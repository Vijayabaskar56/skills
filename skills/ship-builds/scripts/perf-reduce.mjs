#!/usr/bin/env node
// Usage: perf-reduce.mjs <stop.json> <analyze.json>
// Reduces one profiled flow run to a flat JSON of numbers on stdout.
// stop.json is `argent run react-profiler-stop --json`; analyze.json is `react-profiler-analyze --json`,
// whose sessionFiles point at the commit dump and the Hermes CPU profile.
import { readFileSync } from "node:fs";

const [stopPath, analyzePath] = process.argv.slice(2);
if (!stopPath || !analyzePath) {
  console.error("usage: perf-reduce.mjs <stop.json> <analyze.json>");
  process.exit(2);
}

const SLOW_COMMIT_MS = 16;
const IDLE = new Set(["(idle)", "(program)", "(root)", "[idle]", "[root]"]);
const isGc = (name = "") => name === "(garbage collector)" || name.startsWith("[GC");
const GENERIC = new Set(["View", "Text", "Image", "Anonymous", "Context.Provider", "Context.Consumer"]);

const readJson = (path) => JSON.parse(readFileSync(path, "utf8"));
const round = (n) => Math.round(n * 10) / 10;

function findPath(value, suffix) {
  if (typeof value === "string") return value.endsWith(suffix) ? value : null;
  if (value && typeof value === "object") {
    for (const child of Object.values(value)) {
      const hit = findPath(child, suffix);
      if (hit) return hit;
    }
  }
  return null;
}

const stop = readJson(stopPath);
const analyze = readJson(analyzePath);
const commitsPath = findPath(analyze.sessionFiles ?? analyze, "_commits.json");
const cpuPath = findPath(analyze.sessionFiles ?? analyze, "_cpu.json");
if (!commitsPath || !cpuPath) {
  console.error(`no session files in ${analyzePath}`);
  process.exit(1);
}

const { commits, meta } = readJson(commitsPath);
const durationByCommit = new Map();
const hotRenders = new Map();
for (const fiber of commits) {
  durationByCommit.set(fiber.commitIndex, fiber.commitDuration);
  if (fiber.commitDuration >= SLOW_COMMIT_MS && fiber.didRender && !GENERIC.has(fiber.componentName)) {
    hotRenders.set(fiber.componentName, (hotRenders.get(fiber.componentName) ?? 0) + 1);
  }
}
const slow = [...durationByCommit.values()].filter((ms) => ms >= SLOW_COMMIT_MS);

const cpu = readJson(cpuPath);
const nameById = new Map(cpu.nodes.map((node) => [node.id, node.callFrame?.functionName ?? ""]));
let busyUs = 0;
let gcUs = 0;
cpu.samples.forEach((nodeId, i) => {
  const us = cpu.timeDeltas[i + 1] ?? 0;
  const name = nameById.get(nodeId);
  if (isGc(name)) gcUs += us;
  else if (!IDLE.has(name)) busyUs += us;
});

const topRenders = Object.fromEntries(
  [...hotRenders.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5),
);

console.log(
  JSON.stringify(
    {
      durationMs: round((cpu.endTime - cpu.startTime) / 1000),
      commits: meta?.totalReactCommits ?? stop.total_react_commits ?? 0,
      fiberRenders: stop.fiber_renders_captured ?? 0,
      slowCommits: slow.length,
      slowCommitMs: round(slow.reduce((a, b) => a + b, 0)),
      maxCommitMs: round(Math.max(0, ...durationByCommit.values())),
      jsBusyMs: round(busyUs / 1000),
      gcMs: round(gcUs / 1000),
      topRenders,
    },
    null,
    2,
  ),
);
