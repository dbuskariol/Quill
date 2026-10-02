#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/lib/quill-release.sh"

APP="${QUILL_RELEASE_DIR:?Set an external release output directory}/Quill.app"
UPDATES_DIR="${QUILL_RELEASE_DIR:?Set an external release output directory}/updates"
NOTES_SOURCE="${QUILL_RELEASE_NOTES_FILE:-$ROOT_DIR/Documentation/RELEASE_NOTES.md}"

if [[ "${QUILL_SKIP_BUILD:-0}" != "1" ]]; then
  "$ROOT_DIR/script/build-release.sh"
fi

[[ -d "$APP" ]] || quill_fail "app bundle not found: $APP"
[[ -f "$NOTES_SOURCE" ]] || quill_fail "release notes not found: $NOTES_SOURCE"
quill_assert_release_app "$APP" "${QUILL_DEVELOPMENT_TEAM:-}"
if [[ "${QUILL_ALLOW_UNNOTARIZED_PACKAGE:-0}" != "1" ]]; then
  quill_assert_notarized_app "$APP"
fi

SHORT_VERSION="$(quill_plist_value CFBundleShortVersionString "$APP/Contents/Info.plist")"
BUILD_VERSION="$(quill_plist_value CFBundleVersion "$APP/Contents/Info.plist")"
BASE_NAME="Quill-$SHORT_VERSION-$BUILD_VERSION"
ARCHIVE="$UPDATES_DIR/$BASE_NAME.zip"
NOTES="$UPDATES_DIR/$BASE_NAME.md"

[[ "$(/usr/bin/sed -n '1p' "$NOTES_SOURCE")" == "# Quill $SHORT_VERSION" ]] \
  || quill_fail "release notes do not match Quill $SHORT_VERSION"

/bin/mkdir -p "$UPDATES_DIR"
/bin/rm -f "$ARCHIVE" "$NOTES"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
/bin/cp "$NOTES_SOURCE" "$NOTES"
/usr/bin/unzip -tqq "$ARCHIVE" || quill_fail 'the generated update archive is unreadable'

quill_note "Packaged $ARCHIVE"
