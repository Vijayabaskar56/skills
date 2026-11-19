# EAS Android builds

Used when `android.builder` is `eas`.

## Queue the build (SKILL.md step 5)

With `android.builder: eas`, skip build-android.sh and queue the build in the cloud instead. EAS
uploads the working tree, so commit first and start it after the tree holds what ships. Add
`--auto-submit` when `android.eas.autoSubmit` is true or this request asks for a Play release:

```bash
SKIP_ENV_VALIDATION=1 npx eas-cli build -p android --profile <android.eas.profile> \
  --non-interactive --no-wait --json [--auto-submit]   # prints build id, versionCode, submission URL
```

- Check that the printed URLs are under `accounts/<android.eas.owner>/projects/<android.eas.project>`.
- `SKIP_ENV_VALIDATION=1` covers only the local config read; the build reads its env from the EAS
  environment of that profile, so `eas env:list --environment <env>` must hold the required keys.
- `--auto-submit` uses the `eas.json` submit profile with the same name as the build profile (its
  `android.track`, e.g. `internal`) and the Google Play service account key stored on EAS. EAS
  bumps versionCode itself when the build profile has `autoIncrement` with `appVersionSource:
  remote`, so there is nothing to bump locally.
- The build runs in the cloud, so a local session restart cannot kill it. Keep the build id and the
  submission URL; they are all step 8 needs.

## Read the result (SKILL.md step 8)

With `android.builder: eas`, there is no file to copy. Once the build has had time to finish
(30 to 60 minutes including the queue), read it and, when submitted, its Play submission:

```bash
SKIP_ENV_VALIDATION=1 npx eas-cli build:view <id> --json | jq -r '[.status,.appBuildVersion,.artifacts.buildUrl] | @tsv'
SKIP_ENV_VALIDATION=1 npx eas-cli status --json --non-interactive | jq '.submissions[] | select(.buildId=="<id>")'
```

`eas submission:view` does not exist; `eas status` lists recent submissions with `status`,
`androidTrack` and `androidReleaseStatus`. Without `--auto-submit`, submit to a store only when
this request asks (`npx eas-cli submit -p android --id <build id> --profile <profile>`).

**Done when** the build is FINISHED and, if submitted, the submission is FINISHED.
