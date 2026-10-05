---
name: html-report
description: House style for client-facing and cross-team documents (API inventories, backend asks, audits, status reports). Use whenever asked to write, rewrite or update a doc under docs/artifacts/, a "docs for the client", "backend asks", "list of APIs", "what is hardcoded", or any report a non-engineer or an agent will read. Enforces one progressive-disclosure table, emoji status column, plain third-person language, the shared vbg stylesheet, and a Markdown mirror.
---

# HTML report

Every document in this style is **one table**. A reader — human skimming on a phone, or an agent
parsing the page — gets one row per item with a status emoji and a one-line summary, and opens a
row only when they want the detail. Long prose documents were rejected by reviewers as unparseable;
do not go back to them.

When the project already has pages under `docs/artifacts/`, read one before writing; they are the
reference implementations (for example an API inventory, or a list of asks to the backend team).

## Build it, never hand-assemble it

```
python3 <this skill's directory>/build.py \
  --body <scratch>/body.html --md <scratch>/source.md \
  --title "Page Name" --out docs/artifacts/<slug>/index.html
```

- `body.html` starts at `<body>` and ends at `</body>`; copy `assets/template-body.html` and fill it.
  No `<style>` or `<script>` in the body — the builder injects the stylesheet, disclosure JS,
  copy-to-Markdown JS and theme sync.
- `source.md` is the same content as Markdown (the "Copy as Markdown" button serves it). Keep it in
  step with the table: same rows, same emoji, same one-liners.
- The builder **fails** on: unknown `vbg-*` classes, unbalanced tags, a summary row without its
  detail row (or vice versa), dangling `#anchors`, second-person / first-person words, and section
  codes like `2b.`. Fix the body; do not bypass the check (`--allow-direct-address` exists only
  for a page that genuinely quotes the reader, and needs a stated reason).
- Output goes to `docs/artifacts/<slug>/index.html`; that is the file that gets deployed or
  published as an Artifact (same path → same URL on republish).

## Conventions (all required)

**Structure**
1. Masthead: the client and product (`Acme mobile`), a five-word recipient line, "Checked against the app as of
   D Month YYYY". The date is the day the code was read, not the day the page was edited.
2. Opening: one-sentence claim as `<h1>`, a two-to-three sentence lede saying what the table holds
   and in what order, the emoji legend, then the three buttons: **Expand all · Collapse all ·
   Copy as Markdown**. A `.vbg-stat-strip` only when three or four numbers are the point.
3. **One table** (`id="inventory"`): columns `▸ · status emoji · Kind · Item · In one line`.
   Each item is a `tr.vbg-custom-row[data-detail=slug]` followed by `tr.vbg-custom-detail#slug[hidden]`
   with `colspan` equal to the column count. Detail cells may hold paragraphs and nested tables;
   the nested table is where weights, rates, option lists and payload shapes live.
4. Row order = reading order: the things that exist first, then the things that are missing,
   then the things that should move. Group with the Kind column, never with headings.
5. One closing section (`vbg-heading-20`) of one or two paragraphs, linking sibling documents by
   real URL (e.g. `https://backend-asks.example.app/`). Nothing after it but the footer.
6. Deep links: every row is addressable as `#slug`; the page opens that row on load.

**Status emoji** — exactly three, with a legend line under the lede that defines them for *this* page:
- ✅ in place / comes from the backend / done
- ⚠️ partly — and the one-liner must say which part
- ❌ missing / built into the app / not wired / open ask
Each emoji carries `<span class="vbg-visually-hidden">Yes|Partly|No</span>` beside it. Never a
fourth symbol, never emoji as decoration or section markers.

Set each row's status **explicitly, by reading the item**. Never infer it by grepping the prose for
words like "already" or "now documented" — in a doc about a client app those usually describe what
the *app* does, not what the backend delivers, and the whole table ends up wrong. Write the partial
set as a literal list in the generator and say in the legend what "partly" means on this page
(e.g. "the route exists but is empty, thin or buggy").

**Language**
- Third person only: "the app", "the backend", "the mobile team", the client's name. Never "you", "your",
  "we", "our", "us". Quoted app copy ("saved for you") is exempt and must be in quotes.
- No section codes (`1a`, `2b`), no numbered headings, no constant or file names, no env-var
  names, no cache times. Describe what a buyer or a product owner sees: "5% of the order total",
  not `TAX_RATE`. An endpoint path in `<code class="vbg-mono">` is fine; it is the item's id.
- Every hardcoded rule is described as it works, with its actual numbers (weights, cut-offs,
  rates, limits, option lists). State where it is wrong ("the same three items on every area").
  Do not ask the reader questions; do not write "decision needed". Ownership goes in the closing
  note, once.
- Facts come from the code read that day, not from an earlier document. Count things (endpoints,
  rows, constants) by grep before writing the number.

**Style**
- The stylesheet is `assets/vbg-bundle.css` — the Geist-derived `vbg-*` system. Use only classes
  it defines plus the `vbg-custom-*` set in `build.py`. Never add page-specific colours or fonts.
- Tone of the emoji column is the only colour on the page. Callouts, badges and tinted boxes are
  not used in this style.
- Title (`<title>`, also the Artifact name) is a short distinctive noun phrase, no explainer after
  a dash: "What the App Calls and Hardcodes", "Acme Backend Asks".

## Converting an existing prose document

Split the old body at every `<h2>`/`<h3>`, keep each section's inner HTML as one detail row, and
strip the section wrappers that straddle the split (`</div></section><section…><div class="vbg-flow">`)
or the tag balance check will fail. Derive each row's one-liner from the document's own summary
table when it has one. Measure each converted detail against its source section length to prove
nothing was dropped — a non-greedy regex will lie to you when the detail contains nested tables,
so split on the next summary row instead.

## Updating an existing page

Edit the body/markdown sources (recreate them from the built file if the scratch copies are gone:
body is `<body>…</body>` minus the trailing scripts; markdown is the `#md-source` block), rebuild,
republish to the **same path**. When a fact changes in one document and is referenced by another,
update both in the same change and say so.

## Checklist before saying it is done

- [ ] `build.py` exited 0
- [ ] every row has an emoji, a Kind, an Item, a one-liner, and a detail
- [ ] legend defines all three emoji for this page
- [ ] no "you / we"; no `1a`-style codes; no constant names
- [ ] Markdown mirror carries the same rows and emoji
- [ ] closing note links sibling docs by URL
- [ ] every detail row measured against its source (nothing silently dropped)
- [ ] published/deployed to the same URL as before, and the link is in the reply

## Where these live

`docs/artifacts/` is gitignored — the built pages are local, then deployed or published as a Claude Artifact. Republish to the same path/URL so shared links keep
working.
