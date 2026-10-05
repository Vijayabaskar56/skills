# Signing

## iOS, automatic

Needs Xcode signed in to an account on the team (Xcode, Settings, Accounts) and
`DEVELOPMENT_TEAM` on the target (Expo: `ios.appleTeamId`). Without an Xcode account, pass the
API key through `build-ios.sh`'s extra flags:

```
-allowProvisioningUpdates -authenticationKeyPath=/path/AuthKey.p8 -authenticationKeyID=<KEY_ID> -authenticationKeyIssuerID=<ISSUER_ID>
```

## iOS, manual

Use this when certificates live elsewhere, for example with EAS. The distribution private key has
to reach this Mac once:

```bash
eas credentials -p ios      # production, Build Credentials, Download credentials
security import credentials/ios/dist-cert.p12 -k ~/Library/Keychains/login.keychain-db \
  -P "<password from credentials.json>" -T /usr/bin/codesign -T /usr/bin/xcodebuild
cp credentials/ios/profile.mobileprovision ~/Library/MobileDevice/"Provisioning Profiles"/<UUID>.mobileprovision
security find-identity -v -p codesigning    # expect an iPhone or Apple Distribution line
```

Keep `credentials.json` and `credentials/` out of git. The first codesign afterwards shows a
keychain prompt, and the build waits until the user clicks Always Allow.

Scope signing to the app target's Release configuration only. Copy
`assets/xcode-signing.template.json` to `.asc/xcode-signing.json`, fill in target, team and
profile UUID, then:

```bash
mv .asc/xcode/signing/receipt.json .asc/xcode/signing/receipt.$(date +%F).json 2>/dev/null || true
asc xcode signing plan --project ios/<App>.xcodeproj --settings-file .asc/xcode-signing.json --overwrite
asc xcode signing apply --plan .asc/xcode/signing/plan.json --confirm
```

asc cannot set `CODE_SIGN_IDENTITY`, so add `"CODE_SIGN_IDENTITY" = "iPhone Distribution";` to that
Release block by hand. Generate export options once from a good archive with
`asc xcode export-options generate --archive-path <archive> --signing-style manual`, and save the
path as `ios.exportOptions`.

A prebuild erases all of this. Re-apply it after every prebuild.

## Android

The React Native and Expo templates sign release builds with `debug.keystore`. That APK is fine to
sideload and share, and Play rejects it. For Play, the user supplies an upload keystore through
`~/.gradle/gradle.properties` and a `signingConfigs.release` entry. Expo prebuild rewrites
`android/`, so wire it with a config plugin, or build Play releases with EAS.
