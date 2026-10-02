#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/lib/quill-release.sh"

APP="${QUILL_NOTARY_APP:-${QUILL_RELEASE_DIR:?Set an external release output directory}/Quill.app}"
OUTPUT_DIR="${QUILL_NOTARY_OUTPUT_DIR:-${QUILL_RELEASE_DIR:?Set an external release output directory}/notarization}"
PREPARE_ONLY="${QUILL_NOTARY_PREPARE_ONLY:-0}"

quill_assert_release_app "$APP" "${QUILL_DEVELOPMENT_TEAM:-}"

SHORT_VERSION="$(quill_plist_value CFBundleShortVersionString "$APP/Contents/Info.plist")"
BUILD_VERSION="$(quill_plist_value CFBundleVersion "$APP/Contents/Info.plist")"
ARCHIVE="$OUTPUT_DIR/Quill-$SHORT_VERSION-$BUILD_VERSION-notarization.zip"
SUBMISSION_JSON="$OUTPUT_DIR/notary-submit-app-$SHORT_VERSION-$BUILD_VERSION.json"
LOG_JSON="$OUTPUT_DIR/notary-log-app-$SHORT_VERSION-$BUILD_VERSION.json"

/bin/mkdir -p "$OUTPUT_DIR"
/bin/rm -f "$ARCHIVE" "$SUBMISSION_JSON" "$LOG_JSON"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  /usr/bin/unzip -tqq "$ARCHIVE" || quill_fail 'the notarization archive is unreadable'
  QUILL_NOTARY_PREPARE_ONLY=1 "$ROOT_DIR/script/create-dmg.sh"
  quill_note "Prepared $ARCHIVE"
  exit 0
fi

quill_note 'Submitting the signed app to Apple notarization'
quill_submit_notarization "$ARCHIVE" "$SUBMISSION_JSON" "$LOG_JSON"

/usr/bin/xcrun stapler staple "$APP"
quill_assert_release_app "$APP" "${QUILL_DEVELOPMENT_TEAM:-}"
quill_assert_notarized_app "$APP"

QUILL_SKIP_BUILD=1 "$ROOT_DIR/script/package-update.sh"
"$ROOT_DIR/script/generate-appcast.sh"
"$ROOT_DIR/script/create-dmg.sh"

quill_note "Notarized, stapled, and packaged $APP"
