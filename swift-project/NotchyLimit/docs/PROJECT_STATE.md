# Notchy Limit Project State

This file is the durable handoff for a new development session. It records
verified repository facts and local release state. Do not put passwords, OAuth
tokens, cookies, private keys, or app-specific passwords in this file.

## Last Verified

- Date: 2026-10-04
- Host: macOS, Europe/Berlin
- Working directory: `/Users/pedroahlers/Development/NOTCHY`
- Project directory: `/Users/pedroahlers/Development/NOTCHY/swift-project/NotchyLimit`

## Repository State

- Branch: `codex-notchy-pill-ui-polish`
- HEAD: `9e1f8ab` (`Stabilize Claude Keychain access and release signing`)
- Working tree: clean at the time of this update
- Base branch: `main`
- Pull request: [Polish notch pill interaction](https://github.com/I-N-SILVA/NOTCHYLIMIT/pull/26)
- Fetch/push remote: `https://github.com/pmahli/NOTCHY.git`
- Upstream remote: `https://github.com/I-N-SILVA/NOTCHY.git`
- The local fork and upstream PR have different repository names. Confirm the
  intended remote before creating releases or changing PR metadata.

## Product Scope

Notchy Limit is a native Swift macOS menu-bar/notch utility. It polls usage
for configured AI providers locally, stores credentials in the macOS Keychain
or reads the provider's existing CLI credential files, and displays usage in a
compact notch pill plus an expanded panel.

The source layout is:

- `Sources/Core`: domain models and application state
- `Sources/Providers`: provider adapters implementing `UsageProvider`
- `Sources/Services`: polling, authentication, notifications, and incidents
- `Sources/Platform`: Keychain, display, screen, and notch integration
- `Sources/UI`: notch window, menu bar, onboarding, settings, diagnostics, and theme
- `Tests`: unit tests for mapping, state, notifications, and provider behavior

Supported providers currently documented in the project README are Claude,
Codex, Gemini, OpenAI, OpenRouter, DeepSeek, ElevenLabs, and Perplexity.

## Current Claude Authentication Model

Claude authentication is resolved in this order:

1. A user-saved `claude setup-token` bearer token in Notchy's Keychain.
2. Claude Code OAuth from `~/.claude/credentials.json` or the Keychain item
   `Claude Code-credentials`.
3. A Claude.ai browser session cookie stored in Notchy's Keychain.

The OAuth path is preferred over the browser cookie because it is scoped and
short-lived. If the OAuth credential includes an organization UUID, the
provider can skip the bootstrap request. The usage request uses the OAuth
endpoint for OAuth credentials and the Claude.ai organization endpoint for a
cookie.

## Keychain Prompt Incident and Fix

### Observed problem

Notchy asked for the macOS account password every few minutes while reading
`Claude Code-credentials`. The app polls usage roughly every five minutes and
multiple status/onboarding paths could resolve the credential independently.
The Keychain item belongs to Claude Code, so an ad-hoc or changing Notchy
binary can trigger its access-control prompt repeatedly. The prompt was about
Keychain access to the Claude Code OAuth credential, not about Notchy's own
stored API credentials.

### Implemented fix

`ClaudeOAuthCredential` now:

- serializes the first Keychain read with an `NSLock`;
- caches the parsed OAuth credential for the app lifetime while it is usable;
- allows an interactive Keychain prompt only on the first read;
- sets `LAContext.interactionNotAllowed` for later background reads;
- exposes cache invalidation after an OAuth 401/403 response.

`ClaudeProvider` invalidates the OAuth cache after an unauthorized OAuth
request, while keeping the cookie fallback separate. This prevents repeated
background prompt attempts and avoids treating an unreadable Keychain item as
an available credential during onboarding.

### Operational expectation

The first successful access may still require one macOS Keychain approval.
The stable Developer ID signed build should preserve the approval better than
changing ad-hoc builds. Repeated prompts after a fresh install should be
diagnosed as a Keychain ACL, duplicate app identity, or credential refresh
issue rather than solved by repeatedly entering the password.

## Signing, Notarization, and Installation

The local Developer ID identity is:

```text
Developer ID Application: Pedro Ahlers (85QS24P23L)
Team ID: 85QS24P23L
```

The certificate/private key are installed in the user's login Keychain. The
certificate/CSR working directory is `DevCertificate/` at the repository root;
it is ignored by Git and must remain private.

The notarytool credentials are stored in the login Keychain under the profile
name `notchylimit-notarize`. The Apple app-specific password is intentionally
not documented or stored in the repository.

The current installed app is:

```text
/Applications/NotchyLimit.app
Bundle ID: com.notchylimit.NotchyLimit
Version: 0.5.1 (build 3)
Architecture: arm64
```

The installed app was verified with:

- `codesign --verify --deep --strict`: passed
- `xcrun stapler validate`: passed
- `spctl --assess --type execute`: accepted
- Gatekeeper source: `Notarized Developer ID`
- Hardened runtime: enabled
- Notarization ticket: stapled

Local app copies in `/Applications`, `build`, `dmg-staging`, and Xcode
DerivedData were cleaned on 2026-10-04. A future Xcode/build run can recreate
additional app bundles; use exact paths when launching and do not rely on
Spotlight while multiple copies are indexed.

## Build and Release Commands

From the project directory:

```bash
# Local development build; ad-hoc signed by default.
bash scripts/build.sh

# Stable local build for Keychain approvals.
SIGNING_IDENTITY="Developer ID Application: Pedro Ahlers (85QS24P23L)" \
  bash scripts/build.sh

# Create the installer DMG.
bash scripts/create_dmg.sh

# Sign, submit, wait, and staple using the stored notary profile.
export DEVELOPER_ID_APP="Developer ID Application: Pedro Ahlers (85QS24P23L)"
export NOTARY_PROFILE="notchylimit-notarize"
bash scripts/sign_and_notarize.sh
```

`build.sh` defaults to ad-hoc signing. Use the Developer ID identity for any
build that should retain a stable Keychain identity or be distributed. The
release script is still an upstream-oriented, ad-hoc/Homebrew workflow and is
not the source of truth for the notarized local installation described here.

## Verification Status

- Release build completed successfully with the Developer ID identity.
- `xcodebuild ... build-for-testing` completed successfully after fixing the
  optional-window assertions in `Tests/NotchyLimitTests.swift`.
- A full `xcodebuild test` run was started but the Xcode test host did not
  materialize and the run was interrupted. The complete suite is therefore
  **not** recorded as passing.
- The installed app is currently the only indexed `NotchyLimit.app` bundle
  and was started successfully after installation.

## Known Risks and Follow-up

- Claude usage endpoints are undocumented and may change.
- The app sandbox is currently disabled in `NotchyLimit.entitlements`; do not
  enable it casually because the current CLI/Keychain access model depends on
  the existing setup.
- A stable signing identity reduces Keychain prompts but does not replace a
  deliberate Keychain access design or a user approval on first access.
- Add a deterministic test for the credential cache and non-interactive
  Keychain path where the platform APIs can be safely abstracted.
- Re-run the full test suite on a clean Xcode test host before merging further
  changes.
- Update the public README's unsigned-release wording if this fork begins
  publishing the notarized Developer ID DMG as its official release artifact.

## New Session Start Checklist

1. Read this file and `docs/UPDATE_PROJECT_WORKFLOW.md`.
2. Run `git status --short --branch` and `git log -5 --oneline --decorate`.
3. Confirm the active branch and PR before editing.
4. Inspect only the relevant source files and preserve unrelated user changes.
5. Re-run the smallest meaningful build/test check after each change.
6. Update this file with verified facts, test results, and remaining risks.
7. Never record secrets or commit `DevCertificate/` contents.
