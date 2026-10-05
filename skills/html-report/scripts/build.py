#!/usr/bin/env python3
"""Usage: build.py --body body.html --md source.md --title "Page Name" --out <outDir>/<slug>/index.html
                [--allow-direct-address REASON]

Validates a report body (from <body> to </body>, started from assets/template-body.html) and its
Markdown mirror, then writes one self-contained page: the vbg stylesheet, fonts, page CSS,
disclosure, copy-as-Markdown and theme scripts are injected here, so a body carries no <style> or
<script>. On success prints "wrote PATH (N bytes, M rows, checked as of D Month YYYY)" and exits 0.
On a validation failure prints each problem to stderr and exits 1; a malformed body file exits 2.
Runs on Python 3.9 or later.
"""
import argparse
import html
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(os.path.dirname(HERE), "assets")

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


STATUS = {"\u2705": "Yes", "\u26a0": "Partly", "\u274c": "No"}
STATUS_LIST = "\u2705 \u26a0\ufe0f \u274c"
EMOJI = re.compile("[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\u231A\u231B\u23E9-\u23FA]")
PLACEHOLDERS = ["CLIENT", "PRODUCT", "MEANING", "KIND", "D MONTH YYYY", "STATUS COLUMN NAME",
                "WHAT THE PAGE IS", "ITEM NAME", "One-sentence claim", "Closing note heading", "example-row"]
MONTHS = "January|February|March|April|May|June|July|August|September|October|November|December"
CHECKED_DATE = re.compile(r"as of ([0-9]{1,2} (?:%s) [0-9]{4})" % MONTHS)
DIRECT = re.compile(r"\b(?:you|your|yours|yourself|we|our|ours|us)\b", re.I)
QUOTED = re.compile('"[^"\\n]{0,300}"|\u201c[^\u201d\\n]{0,300}\u201d')
SECTION_CODE = re.compile(r"(?<![\w#/.-])[0-9]{1,2}[a-f](?![\w-])")
SECTION_REF = re.compile(r"\b(?:section|part|chapter)\s+[0-9]+[a-z]?\b", re.I)
NUMBERED_HEADING = re.compile(r"<h[1-6]\b[^>]*>\s*(?:<[^>]+>\s*)*[0-9]+[.)]\s")
CAPS_IDENT = re.compile(r"\b[A-Z][A-Z0-9]*_[A-Z0-9_]*[A-Z0-9]\b")
MONO = re.compile(r'<(\w+)\b[^>]*\bclass="[^"]*\b(?:vbg-mono|vbg-custom-code)\b[^"]*"[^>]*>.*?</\1>', re.S)
SUMMARY_ROW = re.compile(r'<tr\b([^>]*\bclass="[^"]*\bvbg-custom-row\b[^"]*"[^>]*)>(.*?)</tr>', re.S)
DETAIL_ROW = re.compile(r'<tr\b([^>]*\bclass="[^"]*\bvbg-custom-detail\b[^"]*"[^>]*)>\s*<td\b([^>]*)>', re.S)
STATUS_CELL = re.compile(r'<td\b[^>]*\bclass="[^"]*\bvbg-custom-status\b[^"]*"[^>]*>(.*?)</td>', re.S)


def attr(attrs, name):
    m = re.search(r'(?<![\w-])%s="([^"]*)"' % re.escape(name), attrs)
    return m.group(1) if m else None


def has_flag(attrs, name):
    return re.search(r"(?<![\w-])%s(?![\w-])" % re.escape(name), attrs) is not None


def visible_text(fragment):
    fragment = re.sub(r"<(script|style)\b.*?</\1>", " ", fragment, flags=re.S | re.I)
    return html.unescape(re.sub(r"<[^>]+>", " ", fragment))


def status_marks(text):
    return [c for c in EMOJI.findall(text) if c in STATUS]


def markdown_statuses(md, problems):
    statuses = []
    for number, line in enumerate(md.splitlines(), 1):
        if not line.lstrip().startswith("|"):
            continue
        marks = status_marks(line)
        if len(marks) > 1:
            problems.append("source.md line %d has %d status emoji; an item row carries one" % (number, len(marks)))
        if marks:
            statuses.append(marks[0])
    return statuses


def validate(body, md, head_css):
    """Returns (problems, rows, checked_date)."""
    problems = []
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    body = re.sub(r"<script\b.*?</script>", "", body, flags=re.S)

    for p in PLACEHOLDERS:
        pattern = re.compile(r"(?<![A-Za-z0-9_-])%s(?![A-Za-z0-9_-])" % re.escape(p))
        where = [name for name, text in (("body", body), ("source.md", md)) if pattern.search(text)]
        if where:
            problems.append("template placeholder '%s' left in %s" % (p, " and ".join(where)))
    if re.search(r'href="https?://example\.', body):
        problems.append("template link https://example... left in the body; link the real sibling URL")

    unquoted = sorted({m for tag in re.findall(r"<[a-zA-Z][^>]*>", body)
                       for m in re.findall(r"\s([\w:-]+)=(?!\")", tag)})
    if unquoted:
        problems.append("attributes not in double quotes: %s; the checks below read only double-quoted values" % unquoted)

    defined = set(re.findall(r"\.(vbg-[a-z0-9-]+)", head_css))
    used = {c for m in re.findall(r'class="([^"]+)"', body) for c in m.split()}
    undefined = sorted(c for c in used - defined if c.startswith("vbg-") and c != "vbg-custom-disclosure")
    if undefined:
        problems.append("classes with no CSS: %s" % undefined)

    for tag in ["div", "section", "table", "thead", "tbody", "tr", "td", "th", "p", "ul", "ol", "li",
                "a", "code", "strong", "em", "span", "button", "h1", "h2", "h3", "main", "header", "footer", "pre"]:
        opened = len(re.findall(r"<%s[\s>]" % tag, body))
        closed = len(re.findall(r"</%s>" % tag, body))
        if opened != closed:
            problems.append("<%s> opened %d closed %d" % (tag, opened, closed))

    head = re.search(r'<table\b[^>]*\bid="inventory"[^>]*>(.*?)</thead>', body, re.S)
    columns = len(re.findall(r"<th\b", head.group(1))) if head else 0
    if not head:
        problems.append('no <table id="inventory"> with a <thead>')

    rows, statuses = [], []
    for attrs, inner in SUMMARY_ROW.findall(body):
        slug = attr(attrs, "data-detail")
        if not slug:
            problems.append("a summary row has no data-detail")
            continue
        rows.append(slug)
        cells = len(re.findall(r"<td\b", inner))
        if head and cells != columns:
            problems.append("row %s has %d cells; the table has %d columns" % (slug, cells, columns))
        cell = STATUS_CELL.search(inner)
        if not cell:
            problems.append("row %s has no vbg-custom-status cell" % slug)
            continue
        text = visible_text(cell.group(1))
        marks = EMOJI.findall(text)
        if len(marks) != 1 or marks[0] not in STATUS:
            problems.append("row %s status cell holds %s; use exactly one of %s" % (slug, marks or "no emoji", STATUS_LIST))
            continue
        statuses.append(marks[0])
        label = re.sub(r"\s+", " ", EMOJI.sub("", text).replace("\ufe0f", "")).strip()
        if label != STATUS[marks[0]]:
            problems.append("row %s hidden label is '%s'; %s needs '%s'" % (slug, label, marks[0], STATUS[marks[0]]))

    details = []
    for tr_attrs, td_attrs in DETAIL_ROW.findall(body):
        slug = attr(tr_attrs, "id")
        details.append(slug)
        if not has_flag(tr_attrs, "hidden"):
            problems.append("detail row %s is not hidden" % slug)
        colspan = attr(td_attrs, "colspan")
        if head and colspan != str(columns):
            problems.append("detail row %s has colspan %s; the table has %d columns" % (slug, colspan, columns))
    if set(rows) != set(details):
        problems.append("row/detail id mismatch: %s" % sorted(set(rows) ^ {d for d in details if d}))
    elif rows != details:
        problems.append("detail rows are not in summary-row order; each detail follows its row")
    if len(rows) != len(set(rows)):
        problems.append("duplicate data-detail ids")

    anchors = set(re.findall(r'href="#([^"]+)"', body))
    ids = set(re.findall(r'(?<![\w-])id="([^"]+)"', body))
    dangling = sorted(anchors - ids - set(rows))
    if dangling:
        problems.append("anchors with no target: %s" % dangling)

    page_text = visible_text(body)
    others = sorted({c for c in EMOJI.findall(page_text + md) if c not in STATUS})
    if others:
        problems.append("emoji other than %s: %s; never a fourth status or a decoration" % (STATUS_LIST, others))

    prose = QUOTED.sub("", visible_text(MONO.sub(" ", body)))
    direct = [w for w in DIRECT.findall(prose) if w != "US"]
    if direct:
        problems.append("direct address (%dx: %s); write in third person, or put quoted copy in double quotes"
                        % (len(direct), sorted({w.lower() for w in direct})))
    codes = sorted({c for c in SECTION_CODE.findall(prose) if c not in ("2d", "3d")} | set(SECTION_REF.findall(prose)))
    if codes:
        problems.append("section codes %s; use plain words" % codes)
    if NUMBERED_HEADING.search(body):
        problems.append("numbered heading; headings carry no numbers")
    caps = sorted(set(CAPS_IDENT.findall(prose)))
    if caps:
        problems.append("identifiers %s outside <code class=\"vbg-mono\">; describe what the reader sees" % caps)

    md_statuses = markdown_statuses(md, problems)
    if len(md_statuses) != len(rows):
        problems.append("source.md has %d item rows (table lines with a status emoji); the body has %d"
                        % (len(md_statuses), len(rows)))
    elif md_statuses != statuses and len(statuses) == len(rows):
        first = next(i for i, (a, b) in enumerate(zip(statuses, md_statuses)) if a != b)
        problems.append("source.md row %d (%s) shows %s; the body shows %s"
                        % (first + 1, rows[first], md_statuses[first], statuses[first]))

    dates = sorted(set(CHECKED_DATE.findall(re.sub(r"\s+", " ", page_text))))
    if not dates:
        problems.append("no 'as of D Month YYYY' date; the masthead states the day the facts were read")
    elif len(dates) > 1:
        problems.append("checked-as-of dates disagree: %s" % dates)
    return problems, rows, dates[0] if len(dates) == 1 else None


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def main():
    ap = argparse.ArgumentParser(description="Validate and build a report page.")
    ap.add_argument("--body", required=True)
    ap.add_argument("--md", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--allow-direct-address", metavar="REASON",
                    help="skip only the third-person check, for a page that quotes the reader; the reason is printed")
    a = ap.parse_args()
    if a.allow_direct_address is not None and not a.allow_direct_address.strip():
        print("--allow-direct-address needs a reason", file=sys.stderr)
        return 2

    bundle = read(os.path.join(ASSETS, "vbg-bundle.css"))
    links = read(os.path.join(ASSETS, "head-links.html")).strip()
    body = read(a.body).strip()
    md_raw = read(a.md)
    md = md_raw.replace("</script", "<\\/script")
    if not body.startswith("<body>") or not body.endswith("</body>"):
        print("body.html must start with <body> and end with </body>", file=sys.stderr)
        return 2
    inner = body[len("<body>"):-len("</body>")]

    head_css = bundle + PAGE_CSS
    problems, rows, checked = validate(inner, md_raw, head_css)
    if a.allow_direct_address:
        problems = [p for p in problems if not p.startswith("direct address")]
        print("direct-address check skipped: %s" % a.allow_direct_address.strip())
    if problems:
        print("VALIDATION FAILED", file=sys.stderr)
        for p in problems:
            print(" -", p, file=sys.stderr)
        return 1

    page = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
%s
<style>
%s
</style>
<style>
%s
</style>
</head>
<body>%s
<script id="md-source" type="text/markdown">
%s
</script>
<script>%s</script>
<script>%s</script>
<script>%s</script>
</body>
</html>
""" % (html.escape(a.title, quote=False), links, bundle, PAGE_CSS, inner, md, DISCLOSURE_JS, COPY_JS, THEME_JS)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(page)
    size = len(page.encode("utf-8"))
    print("wrote %s (%s bytes, %d rows, checked as of %s)" % (a.out, format(size, ","), len(rows), checked))
    return 0


if __name__ == "__main__":
    sys.exit(main())
