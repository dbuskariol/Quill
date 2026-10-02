# Releasing Quill

Quill follows Reccy's distribution process: a universal Xcode archive exported with Developer ID, hardened and timestamped nested signatures, separate app and DMG notarization, stapled tickets, Gatekeeper acceptance, and signed Sparkle archives, release notes and feeds. Quill uses its own bundle identifier, public update feed and signing key.

## Release identity

- Bundle: `com.dbuskariol.quill`; minimum macOS: 26.0.
- Feed: `https://github.com/dbuskariol/Quill/releases/latest/download/appcast.xml`.
- Sparkle key: login Keychain account `quill-ed25519`, generated specifically for Quill. The public key is committed in `Configuration/Quill-Info.plist`; the private key stays in Keychain and is never published. Keep a secure owner-managed backup before moving release machines. Sparkle's documented key rotation rules apply if the key is lost or compromised.
- Developer ID and notarization credentials belong to the Apple developer team. Supply them explicitly for each release; Quill does not embed them or borrow another app's update key.

Automatic update checks, downloads and system profiling default off. Manual checking uses the signed feed. Feed verification and archive verification before extraction are required.

## Verify and rehearse

Update the version, increment the build, write `Documentation/RELEASE_NOTES.md`, and commit the verified source. All commits and GitHub operations use the repository's dbuskariol identity policy.

```sh
./script/verify-ci.sh
QUILL_RELEASE_DIR="/absolute/external/new-output-directory" \
QUILL_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
QUILL_DEVELOPMENT_TEAM="TEAMID" \
./script/release.sh prepare
```

The output directory must be new and outside the checkout. DerivedData also stays external. Rehearsal builds the universal `.xcarchive`, exports and validates nested code, preserves dSYMs, creates a signed DMG and Sparkle ZIP, signs and verifies the feed and release notes, and compares the expanded ZIP and mounted DMG to the verified app. It does not submit to Apple or publish. Its manifest explicitly records `artifactStatus: rehearsal` and `notarized: false`. Rehearsal artifacts must never be published as a notarized release.

## Finalize

Finalization requires a clean worktree at the exact `v<version>` tag and a provisioned notarization credential. Use a stored Keychain profile or the supported App Store Connect API-key environment variables documented in `script/lib/quill-release.sh`. Passwords are never accepted inline.

```sh
git tag v0.1.0
QUILL_RELEASE_DIR="/absolute/external/new-final-directory" \
QUILL_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
QUILL_DEVELOPMENT_TEAM="TEAMID" \
QUILL_NOTARY_KEYCHAIN_PROFILE="Your Notary Profile" \
./script/release.sh finalize
```

The pipeline submits the app, verifies Apple's acceptance log, staples and assesses it, packages the update, submits the signed DMG separately, staples and assesses it, validates its mounted app, and writes checksums plus a commit-exact manifest. Any failed gate stops the pipeline. It never installs or replaces a running Quill app and never publishes automatically.

## Publish

After the verification gate, both notarizations, signature verification, and artifact checks pass, use `script/gh-quill.sh release create` with the exact tag, release notes and verified files from the output's `updates` directory. Publish the DMG, ZIP, signed Markdown notes, `appcast.xml`, `SHA256SUMS`, and `release.json`. Keep `.xcarchive`, dSYMs and Apple evidence privately for diagnostics. Do not upload credentials or unnotarized rehearsal artifacts.

GitHub CI verifies the product on Apple silicon and Intel. Signing and publishing are local for this milestone; no unattended release workflow or repository signing secrets have been provisioned.

## Acceptance boundaries

Artifact validation does not establish permission-enabled expansion, VoiceOver, Zendesk editor paste behavior or an actual older-to-newer Sparkle installation. Those remain explicit acceptance work. Test update rejection, interruption, offline behavior and library preservation before claiming updater end-to-end acceptance. Quill supports SQLite schema v1 and JSON interchange v3, with no legacy migration or downgrade shim.

Official references: [Sparkle distribution and signing](https://sparkle-project.org/documentation/) and [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
