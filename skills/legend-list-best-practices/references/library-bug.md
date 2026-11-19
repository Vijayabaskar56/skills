# When evidence shows a library bug

Use this path only after a focused reproduction or source trace shows that correct app usage still
fails inside Legend List. Skip it for routine builds and best-practices audits.

1. Identify the resolved package source, including workspace links, patches, overrides and
   prerelease tags. For registry installs only, compare registry channels with
   `npm view @legendapp/list version dist-tags --json`.
2. Search the official [changelog](https://github.com/LegendApp/legend-list/blob/main/CHANGELOG.md),
   [releases](https://github.com/LegendApp/legend-list/releases) and
   [issues](https://github.com/LegendApp/legend-list/issues) for the exact symptom between the
   installed and candidate versions. The installed package also ships `CHANGELOG.md`.
3. Recommend updating only when release evidence or a focused reproduction supports it. State
   migration, peer-dependency, patch and prerelease risks.
4. After an approved upgrade, rerun the original reproduction.
