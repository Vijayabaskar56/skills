# Convert a prose document

Follow this when the request turns an existing prose report into this style. It produces the
`body.html` rows for SKILL.md step 4.

1. Split the old body at every `<h2>` and `<h3>`. Each section's inner HTML becomes one detail row.
2. Strip the section wrappers that straddle a split
   (`</div></section><section ...><div class="vbg-flow">`), or the tag-balance check in
   `scripts/build.py` fails.
3. Take each row's one-liner from the document's own summary table when it has one.
4. Set each row's status by reading the item (SKILL.md step 3), not from the old document's wording.
5. Measure each converted detail against its source section so nothing is dropped. Split the
   built body on the next `<tr class="vbg-custom-row"`, not with a non-greedy regex: a detail that
   holds nested tables ends a non-greedy match early and the measurement lies.

**Done when** every source section maps to one row and each detail's text length equals its
section's, less the stripped wrappers.
