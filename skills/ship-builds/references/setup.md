# Setup

`scripts/doctor.sh` names a section here for each `missing` line. Install anything only after the
user says yes. Xcode, Android Studio and Homebrew itself need the user; give the link and continue
with the other platform.

## git

`xcode-select --install`

## node

Install the version in `.nvmrc` or `package.json` `engines` with the repo's version manager (nvm,
mise or Homebrew).

## jq

`brew install jq`

## xcode

Install Xcode from the App Store, open it once, then `sudo xcode-select -s /Applications/Xcode.app`.
Needs the user.

## asc

`brew install asc`

## cocoapods

`brew install cocoapods`

## asc-auth

The user logs in with their App Store Connect API key (Users and Access, Integrations, App Store
Connect API, role App Manager or higher). Suggest they type it with a `!` prefix so the output
lands in the session:

```bash
chmod 600 /path/to/AuthKey_XXX.p8
asc auth login --name <profile> --key-id <KEY_ID> --issuer-id <ISSUER_ID> --private-key /path/to/AuthKey_XXX.p8
```

## java

`brew install --cask zulu@17`

## android-sdk

Install Android Studio, install an SDK with its build tools, then set `ANDROID_HOME` (default
`~/Library/Android/sdk`). Needs the user.

## curl

Ships with macOS. If it is gone, `brew install curl`.

## argent

The perf step needs the argent CLI on PATH or in the npx cache: `npm i -g @swmansion/argent`, or
the repo's own argent setup.

## metro

A `session metro` line means Metro was not answering on `perf.metroPort`. Start it with the repo's
start script (for example `npx expo start`) before the perf step.

## dev-build

A `session dev-build` line is for you to confirm: the booted simulator has a development build of
the app, signed in and past onboarding, so a cold launch lands on `perf.ready`.
