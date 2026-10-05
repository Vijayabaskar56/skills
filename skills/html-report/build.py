#!/usr/bin/env python3
"""Compose a client report page from a body fragment + markdown mirror.

    python3 build.py \
        --body body.html --md source.md --title "Page Name" --out docs/artifacts/<slug>/index.html

body.html: everything from <body> to </body> (see assets/template-body.html).
source.md: the same content as Markdown, for the "Copy as Markdown" button.
The stylesheet (assets/vbg-bundle.css), fonts, page CSS, disclosure JS and copy JS are injected here,
so a body never carries its own <style>/<script>. Exits non-zero when validation fails.
"""
import argparse, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "assets")

PAGE_CSS = """
/* Page-owned: host theme stamp lands on <html>, the foundation reads classes on the report root. */
html, body { margin: 0; background: transparent; }
.vbg-report { min-height: 100vh; background: var(--vbg-surface-primary); color: var(--vbg-text-primary); }
.vbg-custom-identity { font-weight: var(--vbg-weight-semibold); letter-spacing: -0.01em; }
.vbg-custom-identity small { font-weight: var(--vbg-weight-regular); color: var(--vbg-text-secondary); margin-left: var(--vbg-space-2); }
.vbg-custom-code {
  margin: 0; padding: var(--vbg-space-4) var(--vbg-space-5);
  border: 1px solid var(--vbg-border-subtle); border-radius: var(--vbg-radius);
  background: var(--vbg-surface-secondary);
  font-size: var(--vbg-type-compact); line-height: var(--vbg-leading-compact);
  overflow-x: auto; white-space: pre; max-width: 100%;
}
.vbg-custom-code code { font: inherit; }
.vbg-custom-actions { align-items: center; gap: var(--vbg-space-3); }
.vbg-custom-legend { margin-block-start: var(--vbg-space-2); }
/* Disclosure rows: one summary row + one hidden detail row per item. */
.vbg-custom-toggle-col { width: 2.5rem; }
.vbg-custom-toggle { appearance: none; background: transparent; border: 0; padding: 0; cursor: pointer; color: var(--vbg-text-secondary); font: inherit; line-height: 1; display: inline-flex; }
.vbg-custom-toggle span[aria-hidden] { display: inline-block; transition: transform 150ms ease; }
.vbg-custom-row.is-open .vbg-custom-toggle span[aria-hidden] { transform: rotate(90deg); }
.vbg-custom-row { cursor: pointer; }
.vbg-custom-row:hover td, .vbg-custom-row.is-open td { background: var(--vbg-background-200); }
.vbg-custom-status { text-align: center; white-space: nowrap; width: 1%; }
.vbg-custom-detail > td { padding: var(--vbg-space-4) var(--vbg-space-5) var(--vbg-space-6); background: var(--vbg-surface-secondary); }
.vbg-custom-detail > td > * + * { margin-block-start: var(--vbg-space-4); }
.vbg-custom-detail > td > p { max-width: var(--vbg-reading-width); margin: 0; }
.vbg-custom-detail table { width: 100%; }
.vbg-custom-toggle:focus-visible { outline: 2px solid currentColor; outline-offset: 2px; border-radius: 2px; }
@media (prefers-reduced-motion: reduce) { .vbg-custom-toggle span[aria-hidden] { transition: none; } }
"""

DISCLOSURE_JS = """
(function () {
  var table = document.getElementById("inventory");
  if (!table) return;
  function setOpen(row, open) {
    var detail = document.getElementById(row.getAttribute("data-detail"));
    var btn = row.querySelector(".vbg-custom-toggle");
    if (!detail || !btn) return;
    detail.hidden = !open;
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    row.classList.toggle("is-open", open);
  }
  function isOpen(row) { return row.querySelector(".vbg-custom-toggle").getAttribute("aria-expanded") === "true"; }
  table.addEventListener("click", function (e) {
    if (e.target.closest("a")) return;
    var row = e.target.closest(".vbg-custom-row");
    if (row) setOpen(row, !isOpen(row));
  });
  function all(open) { table.querySelectorAll(".vbg-custom-row").forEach(function (r) { setOpen(r, open); }); }
  var ex = document.getElementById("expand-all"), co = document.getElementById("collapse-all");
  if (ex) ex.addEventListener("click", function () { all(true); });
  if (co) co.addEventListener("click", function () { all(false); });
  function openHash() {
    var id = location.hash.slice(1);
    if (!id) return;
    var row = table.querySelector('.vbg-custom-row[data-detail="' + id + '"]');
    if (row) { setOpen(row, true); row.scrollIntoView({ block: "start" }); }
  }
  openHash();
  window.addEventListener("hashchange", openHash);
})();
"""

COPY_JS = """
(function () {
  var btn = document.getElementById("copy-md"), status = document.getElementById("copy-status");
  var src = document.getElementById("md-source");
  if (!btn || !src) return;
  var source = src.textContent.replace(/<\\\\\\/script/g, "</script");
  function say(msg) { status.textContent = msg; clearTimeout(say.t); say.t = setTimeout(function () { status.textContent = ""; }, 2400); }
  function fallback() {
    var ta = document.createElement("textarea");
    ta.value = source; ta.setAttribute("readonly", ""); ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta); ta.select();
    var ok = false; try { ok = document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(ta); return ok;
  }
  btn.addEventListener("click", function () {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(source).then(function () { say("Copied"); }, function () { say(fallback() ? "Copied" : "Copy failed"); });
    } else { say(fallback() ? "Copied" : "Copy failed"); }
  });
})();
"""

THEME_JS = """
(function () {
  var root = document.documentElement, report = document.getElementById("report");
  function sync() {
    var t = root.getAttribute("data-theme");
    report.classList.toggle("dark", t === "dark");
    report.classList.toggle("light", t === "light");
  }
  sync();
  new MutationObserver(sync).observe(root, { attributes: true, attributeFilter: ["data-theme"] });
})();
"""


def validate(body: str, head_css: str) -> list[str]:
    problems = []
    body = re.sub(r"<script\b.*?</script>", "", body, flags=re.S)
    defined = set(re.findall(r"\.(vbg-[a-z0-9-]+)", head_css))
    used = {c for m in re.findall(r'class="([^"]+)"', body) for c in m.split()}
    undefined = sorted(c for c in used - defined if c.startswith("vbg-") and c not in {"vbg-custom-disclosure"})
    if undefined:
        problems.append(f"classes with no CSS: {undefined}")
    for tag in ["div", "section", "table", "thead", "tbody", "tr", "td", "th", "p", "ul", "ol", "li",
                "a", "code", "strong", "em", "span", "button", "h1", "h2", "h3", "main", "header", "footer", "pre"]:
        o = len(re.findall(rf"<{tag}[\s>]", body)); c = len(re.findall(rf"</{tag}>", body))
        if o != c:
            problems.append(f"<{tag}> opened {o} closed {c}")
    rows = re.findall(r'data-detail="([^"]+)"', body)
    details = re.findall(r'class="vbg-custom-detail" id="([^"]+)"', body)
    if set(rows) != set(details):
        problems.append(f"row/detail id mismatch: {sorted(set(rows) ^ set(details))}")
    if rows and len(rows) != len(set(rows)):
        problems.append("duplicate data-detail ids")
    anchors = set(re.findall(r'href="#([^"]+)"', body)); ids = set(re.findall(r'id="([^"]+)"', body))
    dangling = sorted(a for a in anchors - ids - set(rows))
    if dangling:
        problems.append(f"anchors with no target: {dangling}")
    text = re.sub(r"<[^>]+>", " ", body)
    text = re.sub(r'"[^"]*"', "", text)  # quoted app copy is allowed to say "you"
    direct = re.findall(r"\b(?:you|your|yours|we|our|ours|us)\b", text, flags=re.I)
    if direct:
        problems.append(f"direct address ({len(direct)}x: {sorted(set(w.lower() for w in direct))}) — write in third person")
    if re.search(r"\b[0-9]+[a-f]\.\s", text):
        problems.append("section codes like '2b.' found — use plain headings")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--body", required=True)
    ap.add_argument("--md", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--allow-direct-address", action="store_true", help="skip the third-person check")
    a = ap.parse_args()

    bundle = open(os.path.join(ASSETS, "vbg-bundle.css")).read()
    links = open(os.path.join(ASSETS, "head-links.html")).read().strip()
    body = open(a.body).read().strip()
    md = open(a.md).read().replace("</script", "<\\/script")
    if not body.startswith("<body>") or not body.endswith("</body>"):
        print("body.html must start with <body> and end with </body>", file=sys.stderr); return 2
    inner = body[len("<body>"):-len("</body>")]

    head_css = bundle + PAGE_CSS
    problems = validate(inner, head_css)
    if a.allow_direct_address:
        problems = [p for p in problems if not p.startswith("direct address")]
    if problems:
        print("VALIDATION FAILED", file=sys.stderr)
        for p in problems: print(" -", p, file=sys.stderr)
        return 1

    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{a.title}</title>
{links}
<style>
{bundle}
</style>
<style>
{PAGE_CSS}
</style>
</head>
<body>{inner}
<script id="md-source" type="text/markdown">
{md}
</script>
<script>{DISCLOSURE_JS}</script>
<script>{COPY_JS}</script>
<script>{THEME_JS}</script>
</body>
</html>
"""
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "w").write(html)
    print(f"wrote {a.out} ({len(html):,} bytes, {len(re.findall(r'data-detail=', inner))} rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
