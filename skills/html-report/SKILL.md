---
name: html-report
description: Use when asked to write, rewrite or update a client-facing or cross-team report (API inventory, backend asks, audit, status report, "what is hardcoded") that a non-engineer or an agent will read. Builds one progressive-disclosure table with a three-emoji status column, plain third-person prose, the shared vbg stylesheet and a Markdown mirror. Not for a general Artifact page or slide deck; use artifact-design.
argument-hint: "report topic, or the slug of a page to update"
---

# HTML report

Every report in this style is one table: a row per item with a status emoji and a one-line
summary, and a detail row the reader opens on demand. Reviewers rejected long prose reports as
unparseable. Project facts (output folder, client, product, sibling and Artifact URLs) live in
`.html-report.json` at the repo root, shaped like `assets/html-report.example.json`. Scripts are in
this skill's `scripts/`; a value in the request overrides the config for one run.

## 0. Check setup

Run `scripts/doctor.sh`. Fix each `missing` line with `references/setup.md`, asking once before
installing anything, and confirm each `session` line yourself.

**Done when** doctor exits 0.

## 1. Load the project config

If `.html-report.json` is missing at the repo root, follow `references/first-run.md`.

**Done when** the config holds `outDir`, `client` and `product`.

## 2. Read a reference page

If `<outDir>` already holds built pages, read the one closest to this request before writing; they
are the reference implementations. To change a built page, recreate its sources with
`references/update.md`. To turn a prose document into this style, follow `references/convert.md`.

**Done when** you can name the reference page you read, or `<outDir>` holds none.

## 3. Read the facts

Read the code, API or system the report covers on the day you write; never copy a fact from an
earlier document. Count endpoints, rows and constants with grep before writing a number. Set each
row's status by reading the item itself, never by grepping prose for words like "already" or "now
documented": in a report about a client app those words usually describe what the app does, not
what the backend delivers. Keep the partly-done set as a literal list while you write.

**Done when** every planned row has a status taken from the item and every number has a count
behind it.

## 4. Write body.html and source.md

Work in a scratch folder outside the repo. Copy `assets/template-body.html` to `body.html` and
replace every placeholder: CLIENT, PRODUCT, MEANING, KIND, ITEM NAME, STATUS COLUMN NAME,
D MONTH YYYY and the sample row.

**Structure**
1. Masthead: `client` and `product` from the config, a five-word recipient line, and "Checked
   against the app as of D Month YYYY", dated the day the facts were read, not the day of the edit.
2. Opening: a one-sentence claim as `<h1>`; a lede of two or three sentences saying what the table
   holds and in what order; the legend; the buttons Expand all, Collapse all, Copy as Markdown. Add
   a `.vbg-stat-strip` only when three or four numbers are the point.
3. One table, `id="inventory"`, columns: toggle, status, Kind, Item, In one line. Each item is a
   `tr.vbg-custom-row[data-detail=slug]` followed directly by `tr.vbg-custom-detail#slug[hidden]`
   whose cell has `colspan` equal to the column count. Weights, rates, option lists and payload
   shapes go in a nested table inside the detail.
4. Row order is reading order: what exists, then what is missing, then what should move. Group with
   the Kind column, never with headings.
5. One closing section (`vbg-heading-20`) of one or two paragraphs: who owns what, said once, and
   links to sibling reports from `siblingUrls`. Only the footer follows it.
6. Every row is addressable as `#slug`; the page opens that row on load.

**Status.** Three emoji, each with its hidden label: ✅ `Yes`, ⚠️ `Partly`, ❌ `No`. The legend
under the lede defines all three for this page and says what "partly" means here (for example "the
route exists but is empty, thin or buggy"). A ⚠️ row's one-liner names the missing part.

**Language**
- Third person: "the app", "the backend", "the mobile team", the client's name. Product copy that
  addresses its user is quoted inside double quotes, straight or curly ("saved for you").
- Describe what an end user or a product owner sees: "5% of the order total", not the constant
  behind it. Constant, file and env-var names, cache times, section codes and numbered headings
  stay out. An endpoint path or other identifier goes in `<code class="vbg-mono">`.
- Describe each hardcoded rule as it works, with its real numbers, and say where it is wrong ("the
  same three items on every area"). Ask the reader no questions.

**Style.** Use only `vbg-*` classes from `assets/vbg-bundle.css` and the `vbg-custom-*` set in
`scripts/build.py`. The status emoji are the only colour: no page-specific colours or fonts, no
callouts, badges or tinted boxes. The `<title>` is a short noun phrase with nothing after a dash
("What the App Calls and Hardcodes").

**Mirror.** `source.md` carries the same claim, lede and legend, then one Markdown table with one
line per item in body order (status emoji, Kind, Item, one-liner), then each item's detail. Status
emoji appear in no other table line.

**Done when** both files exist and no template placeholder remains.

## 5. Run build.py

```
python3 <skill>/scripts/build.py --body <scratch>/body.html --md <scratch>/source.md \
  --title "Page Name" --out <outDir>/<slug>/index.html
```

The builder injects the stylesheet, fonts and scripts, and fails on: template placeholders; a
missing or inconsistent checked-as-of date; unknown `vbg-*` classes; attributes outside double
quotes; unbalanced tags; a row without its detail, out of order, not hidden, or with the wrong cell
count or `colspan`; a status cell that is not exactly one of the three emoji with its label; any
other emoji; dangling `#anchors`; first or second person outside double quotes; section codes
(`1a`, `2b.`, `section 3`); numbered headings; `ALL_CAPS_NAMES` outside `vbg-mono`; and a
`source.md` whose item rows differ from the body in count or status. Fix the sources and rebuild.
`--allow-direct-address REASON` skips only the third-person check, for a page that quotes the
reader at length, and prints the reason.

**Done when** build.py prints `wrote <outDir>/<slug>/index.html (N bytes, M rows, checked as of
D Month YYYY)` and exits 0.

## 6. Publish to the recorded URL

If the request asks to publish, or `artifactUrls` in the config has this slug, publish; otherwise
stop at the built file. With a saved URL, read that Artifact (`action: read`), then publish the
built file with `url` set to it: a new conversation does not reuse a URL by file path. Without one,
publish once and save the returned URL as `artifactUrls.<slug>` in the config. When the change
alters a fact another report states, update and republish that report too.

**Done when** the Artifact tool returns a URL equal to `artifactUrls.<slug>` in the config, or the
report gives the reason publishing was skipped.

## Hard rules

- Use exactly three status emoji, ✅ ⚠️ ❌, each with its hidden label, and no other emoji.
- Write in the third person; quote product copy that addresses its user in double quotes.
- Build every page with `scripts/build.py`, and fix the sources when a check fails.
- Publish only when the request asks or to the URL saved for that slug in `.html-report.json`, and
  pass that URL as `url` so a slug never gets a second Artifact.
- Take client and product names from the config or the request, and facts from a read made today.
- Commit the config or built pages only when the user asks.

## Report

- The `wrote ...` line from build.py: output path, byte count and row count
- The checked-as-of date
- The published URL, and whether it is new (saved to `artifactUrls`) or an update
- The reference page read in step 2, or "none"
- Sibling reports updated in the same change
- Each skipped check or step with its reason, including any `--allow-direct-address` reason
