#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/lib/quill-release.sh"

APP="${QUILL_DMG_APP:-${QUILL_RELEASE_DIR:?Set an external release output directory}/Quill.app}"
UPDATES_DIR="${QUILL_DMG_OUTPUT_DIR:-${QUILL_RELEASE_DIR:?Set an external release output directory}/updates}"
NOTARY_OUTPUT_DIR="${QUILL_NOTARY_OUTPUT_DIR:-${QUILL_RELEASE_DIR:?Set an external release output directory}/notarization}"
PREPARE_ONLY="${QUILL_NOTARY_PREPARE_ONLY:-0}"
SIGNING_IDENTITY="${QUILL_CODESIGN_IDENTITY:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(quill_find_developer_id_identity)"
fi
[[ -n "$SIGNING_IDENTITY" ]] || quill_fail 'no Developer ID Application signing identity is available'
quill_assert_release_app "$APP" "${QUILL_DEVELOPMENT_TEAM:-}"
if [[ "$PREPARE_ONLY" != "1" ]]; then
  quill_assert_notarized_app "$APP"
fi

VERSION="$(quill_plist_value CFBundleShortVersionString "$APP/Contents/Info.plist")"
BUILD="$(quill_plist_value CFBundleVersion "$APP/Contents/Info.plist")"
BASE_NAME="Quill-$VERSION-$BUILD"
DISK_IMAGE="$UPDATES_DIR/$BASE_NAME.dmg"
SUBMISSION_JSON="$NOTARY_OUTPUT_DIR/notary-submit-dmg-$VERSION-$BUILD.json"
LOG_JSON="$NOTARY_OUTPUT_DIR/notary-log-dmg-$VERSION-$BUILD.json"
STAGING_DIR="$(/usr/bin/mktemp -d -t quill-dmg-stage.XXXXXX)"
MOUNT_POINT="$(/usr/bin/mktemp -d -t quill-dmg-mount.XXXXXX)"
IS_MOUNTED=0

cleanup() {
  if [[ "$IS_MOUNTED" == "1" ]]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  /bin/rm -rf "$STAGING_DIR" "$MOUNT_POINT"
}
trap cleanup EXIT INT TERM

/bin/mkdir -p "$UPDATES_DIR" "$NOTARY_OUTPUT_DIR"
/usr/bin/ditto "$APP" "$STAGING_DIR/Quill.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/bin/rm -f "$DISK_IMAGE" "$SUBMISSION_JSON" "$LOG_JSON"

quill_note "Creating compressed disk image $DISK_IMAGE"
/usr/bin/hdiutil create \
  -quiet \
  -ov \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -volname "Quill $VERSION" \
  -srcfolder "$STAGING_DIR" \
  "$DISK_IMAGE"
/usr/bin/codesign --sign "$SIGNING_IDENTITY" --timestamp "$DISK_IMAGE"
quill_assert_signed_disk_image "$DISK_IMAGE" "${QUILL_DEVELOPMENT_TEAM:-}"

if [[ "$PREPARE_ONLY" != "1" ]]; then
  quill_note 'Submitting the signed disk image to Apple notarization'
  quill_submit_notarization "$DISK_IMAGE" "$SUBMISSION_JSON" "$LOG_JSON"
  /usr/bin/xcrun stapler staple "$DISK_IMAGE"
  quill_assert_notarized_disk_image "$DISK_IMAGE" "${QUILL_DEVELOPMENT_TEAM:-}"
fi

/usr/bin/hdiutil attach \
  -quiet \
  -readonly \
  -nobrowse \
  -mountpoint "$MOUNT_POINT" \
  "$DISK_IMAGE"
IS_MOUNTED=1
[[ -d "$MOUNT_POINT/Quill.app" ]] || quill_fail 'the disk image does not contain Quill.app'
[[ -L "$MOUNT_POINT/Applications" ]] || quill_fail 'the disk image does not contain the Applications shortcut'
[[ "$(/usr/bin/readlink "$MOUNT_POINT/Applications")" == "/Applications" ]] \
  || quill_fail 'the disk image Applications shortcut has an unexpected destination'
quill_assert_release_app "$MOUNT_POINT/Quill.app" "${QUILL_DEVELOPMENT_TEAM:-}"
if [[ "$PREPARE_ONLY" != "1" ]]; then
  quill_assert_notarized_app "$MOUNT_POINT/Quill.app"
fi

SOURCE_HASH="$(/usr/bin/shasum -a 256 "$APP/Contents/MacOS/Quill" | /usr/bin/awk '{print $1}')"
MOUNTED_HASH="$(/usr/bin/shasum -a 256 "$MOUNT_POINT/Quill.app/Contents/MacOS/Quill" | /usr/bin/awk '{print $1}')"
[[ "$SOURCE_HASH" == "$MOUNTED_HASH" ]] \
  || quill_fail 'the disk image app executable differs from the verified release app'
/usr/bin/hdiutil detach "$MOUNT_POINT" -quiet
IS_MOUNTED=0

if [[ "$PREPARE_ONLY" == "1" ]]; then
  quill_note "Prepared signed disk image $DISK_IMAGE without contacting Apple"
else
  quill_note "Created and verified notarized disk image $DISK_IMAGE"
fi
