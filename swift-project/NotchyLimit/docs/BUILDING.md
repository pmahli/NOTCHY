# Building Notchy Limit

## Requirements

- macOS 12 (Monterey) or newer
- Xcode 15+ with the macOS SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## One-line build

```bash
./scripts/build.sh
open build/NotchyLimit.app
```

The `build.sh` script will:

1. Run `xcodegen generate` to produce `NotchyLimit.xcodeproj` from `project.yml`.
2. Build with `xcodebuild` (Release config) using the local toolchain.
3. Copy the `.app` bundle to `build/`.

## Working in Xcode

```bash
xcodegen generate
open NotchyLimit.xcodeproj
```

Select the **NotchyLimit** scheme and ⌘R.

## Creating a DMG installer

```bash
./scripts/build.sh
./scripts/create_dmg.sh
# build/NotchyLimit-Installer.dmg
```

## Signing + Notarization (distribution)

You need an Apple Developer account. Once you have a Developer ID Application
certificate installed in Keychain and a stored notarytool credential, run:

```bash
export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
./scripts/sign_and_notarize.sh
```

For a locally installed build with a stable Keychain identity, pass the same
Developer ID identity to the build script:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build.sh
```

Ad-hoc builds are suitable for development only. macOS may not preserve
Keychain "Always Allow" decisions across changing ad-hoc binaries.

This hard-runtime-signs the `.app`, signs the DMG, submits to Apple, waits,
and staples the ticket.

## Troubleshooting

- **`xcodegen: command not found`** — `brew install xcodegen`
- **"App is damaged" on first open** — unsigned local builds: right-click the
  app → Open. For distribution use `sign_and_notarize.sh`.
- **Cookie not validating** — see `docs/COOKIE_SETUP.md`.
