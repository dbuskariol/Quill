#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/lib/quill-release.sh"

DERIVED_DATA="${QUILL_DERIVED_DATA:-$(quill_default_derived_data Release)}"
UPDATES_DIR="${QUILL_RELEASE_DIR:?Set an external release output directory}/updates"
APP="${QUILL_RELEASE_DIR:?Set an external release output directory}/Quill.app"
REPOSITORY="$QUILL_EXPECTED_GITHUB_REPOSITORY"
DOWNLOAD_PREFIX="https://github.com/$REPOSITORY/releases/latest/download/"
APPCAST_STAGE="$(/usr/bin/mktemp -d -t quill-appcast.XXXXXX)"

cleanup() {
  /bin/rm -rf "$APPCAST_STAGE"
}
trap cleanup EXIT INT TERM

[[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] \
  || quill_fail "invalid GitHub repository: $REPOSITORY"
quill_assert_release_app "$APP" "${QUILL_DEVELOPMENT_TEAM:-}"
if [[ "${QUILL_ALLOW_UNNOTARIZED_PACKAGE:-0}" != "1" ]]; then
  quill_assert_notarized_app "$APP"
fi
GENERATE_APPCAST="$(quill_resolve_sparkle_tool "$ROOT_DIR" "$DERIVED_DATA" generate_appcast)"
quill_assert_sparkle_signing_key "$ROOT_DIR" "$APP" "$DERIVED_DATA"

if [[ ! -d "$UPDATES_DIR" || -z "$(/usr/bin/find "$UPDATES_DIR" -maxdepth 1 -name 'Quill-*.zip' -print -quit)" ]]; then
  "$ROOT_DIR/script/package-update.sh"
fi

# Sparkle treats every supported archive in its input directory as an update.
# Keep the GitHub-facing DMG beside the ZIP in the updates directory, but give Sparkle a
# ZIP-only workspace so two containers for the same build cannot be mistaken
# for duplicate updates.
for archive in "$UPDATES_DIR"/Quill-*.zip; do
  [[ -f "$archive" ]] || continue
  /bin/cp "$archive" "$APPCAST_STAGE/"
  notes="${archive%.zip}.md"
  if [[ -f "$notes" ]]; then
    /bin/cp "$notes" "$APPCAST_STAGE/"
  fi
done
for delta in "$UPDATES_DIR"/*.delta; do
  [[ -f "$delta" ]] || continue
  /bin/cp "$delta" "$APPCAST_STAGE/"
done
if [[ -f "$UPDATES_DIR/appcast.xml" ]]; then
  /bin/cp "$UPDATES_DIR/appcast.xml" "$APPCAST_STAGE/appcast.xml"
fi
[[ -n "$(/usr/bin/find "$APPCAST_STAGE" -maxdepth 1 -name 'Quill-*.zip' -print -quit)" ]] \
  || quill_fail 'no Sparkle update ZIP is available for appcast generation'

SIGNING_ARGS=(--account "${QUILL_SPARKLE_KEY_ACCOUNT:-quill-ed25519}")
if [[ -n "${QUILL_SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  SIGNING_ARGS=(--ed-key-file "$QUILL_SPARKLE_PRIVATE_KEY_FILE")
fi

"$GENERATE_APPCAST" \
  "${SIGNING_ARGS[@]}" \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  --release-notes-url-prefix "$DOWNLOAD_PREFIX" \
  --maximum-versions 5 \
  --maximum-deltas 4 \
  --delta-compression lzfse \
  --phased-rollout-interval "${QUILL_PHASED_ROLLOUT_INTERVAL:-86400}" \
  "$APPCAST_STAGE"

[[ -f "$APPCAST_STAGE/appcast.xml" ]] \
  || quill_fail 'Sparkle did not generate an appcast'
/bin/cp "$APPCAST_STAGE/appcast.xml" "$UPDATES_DIR/appcast.xml"
for notes in "$APPCAST_STAGE"/Quill-*.md; do
  [[ -f "$notes" ]] || continue
  /bin/cp "$notes" "$UPDATES_DIR/"
done
for delta in "$APPCAST_STAGE"/*.delta; do
  [[ -f "$delta" ]] || continue
  /bin/cp "$delta" "$UPDATES_DIR/"
done

quill_note "Generated $UPDATES_DIR/appcast.xml"
