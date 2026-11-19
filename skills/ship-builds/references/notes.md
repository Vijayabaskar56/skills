# Test notes style

Read before drafting TestFlight notes (SKILL.md step 6) or an OTA message (`ota.md` step 5).

Write the notes minimal, fragments over grammar:

```
- Dashboard: new video carousel. Swipe down to close a video
- Settings: dark mode switch
- Text size capped at 1.3x
- Known issue: payments not wired, offline screen placeholder
- Please check: play and close videos. Toggle dark mode on every tab
```

One line per change. Merge cosmetic tweaks and skip refactors. Carry unresolved known issues from
`asc builds test-notes list --app <appId> --latest`. End with one `Please check:` line. Use
straight quotes and no em dashes, and keep it near 1200 characters.
