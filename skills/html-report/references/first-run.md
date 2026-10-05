# First run: write .html-report.json

Follow this once per repo, when `.html-report.json` is missing at the repo root. Find facts
yourself; ask the user only for the names.

## Fields

| Field | Holds |
| --- | --- |
| `outDir` | Folder for built pages, relative to the repo root; each page is `<outDir>/<slug>/index.html` |
| `client` | Name the masthead and footer show first, and the third-person name the prose uses |
| `product` | Product name shown beside the client in the masthead |
| `siblingUrls` | Reader-facing URL of each related report, by slug, for closing-note links |
| `artifactUrls` | Claude Artifact URL of each published page, by slug, passed as `url` on every republish |

`assets/html-report.example.json` shows the shape.

## Steps

1. Detect `outDir` without asking. Take the folder that already holds built pages
   (`grep -rl --include=index.html 'id="md-source"' . --exclude-dir=node_modules`, the parent of
   each `<slug>/` folder found); otherwise `docs/artifacts`.
2. Guess the client and product from the repo: the app or package name (`app.json`,
   `package.json`, `Cargo.toml` or the README title) for the product, the README or git remote
   owner for the client.
3. Ask once, in one `AskUserQuestion` round of two questions (client name, product name), each
   with the guess from step 2 as the first, recommended option. Skip a question the request
   already answers.
4. Write `.html-report.json` with those values and empty `siblingUrls` and `artifactUrls`. Add a
   URL only when the conversation or an existing page shows it; never guess one.
5. Leave `.gitignore` and the decision to commit the config to the user and the repo's rules.

**Done when** `python3 -c 'import json; json.load(open(".html-report.json"))'` exits 0 and the
file holds `outDir`, `client` and `product`.
