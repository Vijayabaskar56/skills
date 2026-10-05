# Update a built page

Follow this when the request changes a page that is already built.

1. If the scratch `body.html` and `source.md` from the last build are gone, recreate them:

   ```
   python3 <skill>/scripts/extract.py <outDir>/<slug>/index.html <scratch>
   ```

   It writes `body.html` (the `<body>` content without the trailing scripts) and `source.md` (the
   `#md-source` block). `build.py` escapes every `</script` in the Markdown as `<\/script` so the
   block cannot close early; `extract.py` turns it back into `</script`. Copying the block by hand
   needs the same unescape, or the next build escapes it twice.
2. Re-read the facts that changed (SKILL.md step 3) and edit both files. Move the checked-as-of
   date to the day of that read in the masthead, the footer and `source.md`.
3. Rebuild to the same `--out` path (SKILL.md step 5) and publish to `artifactUrls.<slug>`
   (step 6).
4. When another report states a fact that changed, update it in the same change and name it in
   the report.

**Done when** `build.py` prints the same path with the new date, and every sibling report that
states a changed fact is rebuilt too.
