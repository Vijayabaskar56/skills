#!/usr/bin/env node
// Usage: text-diff.mjs <raw.json> <rendered.txt>
// Compares every Figma text string from the raw read against the strings a render exposes.
// <rendered.txt> can be argent `describe` output (React Native), an agent-browser `snapshot`
// (web), or plain text with one string per line. Prints exact, case-only, spacing-only or missing
// per Figma string, then a count of each. Exits 1 when any string is spacing-only (always a transcription bug), 2 on
// bad input.
import { readFileSync } from "node:fs";

const [rawPath, renderedPath] = process.argv.slice(2);
if (!rawPath || !renderedPath) {
  console.error("usage: text-diff.mjs <raw.json> <rendered.txt>");
  process.exit(2);
}

function renderedStrings(text) {
  const trimmed = text.trimStart();
  const body = trimmed.startsWith("{") ? (JSON.parse(trimmed).description ?? "") : text;
  return body.split("\n").flatMap((line) => {
    const quoted = [...line.matchAll(/"((?:[^"\\]|\\.)*)"/g)].map((m) => m[1].replace(/\\"/g, '"'));
    if (quoted.length > 0) return quoted;
    const plain = line.trim();
    return plain && !/^[-─│┌└├┬┴┼]+$/.test(plain) ? [plain] : [];
  });
}

const collapse = (value) => value.replace(/\s+/g, "");
function locate(figma, labels, normalize) {
  const wanted = normalize(figma);
  return (
    labels.find((label) => normalize(label) === wanted) ??
    labels.find((label) => normalize(label).includes(wanted)) ??
    null
  );
}

let raw;
try {
  raw = JSON.parse(readFileSync(rawPath, "utf8"));
} catch (error) {
  console.error(`cannot read ${rawPath}: ${error.message}`);
  process.exit(2);
}
const labels = renderedStrings(readFileSync(renderedPath, "utf8"));
const rows = (raw.texts ?? [])
  .map((entry) => (typeof entry === "string" ? entry : entry.text ?? "").trim())
  .filter(Boolean)
  .map((figma) => {
    for (const [match, normalize] of [
      ["exact", (v) => v],
      ["case-only", (v) => v.toLowerCase()],
      ["spacing-only", (v) => collapse(v.toLowerCase())],
    ]) {
      const found = locate(figma, labels, normalize);
      if (found !== null) return { figma, match, rendered: found };
    }
    return { figma, match: "missing", rendered: null };
  });

for (const row of rows) {
  const rendered = row.rendered === null ? "" : `  <- rendered "${row.rendered}"`;
  console.log(`${row.match.padEnd(12)} "${row.figma}"${rendered}`);
}
const count = (match) => rows.filter((row) => row.match === match).length;
const spacing = count("spacing-only");
const missing = count("missing");
console.log(
  `\n${rows.length} Figma strings: ${count("exact")} exact, ${count("case-only")} case-only, ` +
    `${spacing} spacing-only, ${missing} missing.`,
);
if (missing > 0) console.log("Name each missing string: live data by design, or a dropped span.");
process.exit(spacing > 0 ? 1 : 0);
