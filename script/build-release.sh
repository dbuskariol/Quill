#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/lib/quill-release.sh"

DERIVED_DATA="${QUILL_DERIVED_DATA:-$(quill_default_derived_data Release)}"
OUTPUT_DIR="${QUILL_OUTPUT_DIR:-${QUILL_RELEASE_DIR:?Set an external release output directory}}"
ARCHIVE_PATH="${QUILL_ARCHIVE_PATH:-$OUTPUT_DIR/Quill.xcarchive}"
BUILT_APP="$ARCHIVE_PATH/Products/Applications/Quill.app"
EXPORT_PATH="${QUILL_EXPORT_PATH:-$OUTPUT_DIR/export}"
EXPORTED_APP="$EXPORT_PATH/Quill.app"
EXPORT_OPTIONS_PLIST="$OUTPUT_DIR/DeveloperIDExportOptions.plist"
OUTPUT_APP="$OUTPUT_DIR/Quill.app"
SIGNING_IDENTITY="${QUILL_CODESIGN_IDENTITY:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(quill_find_developer_id_identity)"
fi
[[ -n "$SIGNING_IDENTITY" ]] || quill_fail 'no Developer ID Application signing identity is available'

quill_note "Archiving a universal Developer ID release with $SIGNING_IDENTITY"
/bin/mkdir -p "$OUTPUT_DIR"
/bin/rm -rf "$ARCHIVE_PATH"

XCODE_ARGS=(
  -project "$ROOT_DIR/Quill.xcodeproj"
  -scheme Quill
  -configuration Release
  -destination "generic/platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
  -archivePath "$ARCHIVE_PATH"
  CLANG_ENABLE_CODE_COVERAGE=NO
  GCC_GENERATE_TEST_COVERAGE_FILES=NO
  GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=NO
  ONLY_ACTIVE_ARCH=NO
  CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY"
)

if [[ -n "${QUILL_DEVELOPMENT_TEAM:-}" ]]; then
  XCODE_ARGS+=(DEVELOPMENT_TEAM="$QUILL_DEVELOPMENT_TEAM")
fi
if [[ "${QUILL_VERBOSE_BUILD:-0}" != "1" ]]; then
  XCODE_ARGS=(-quiet "${XCODE_ARGS[@]}")
fi

/usr/bin/xcodebuild "${XCODE_ARGS[@]}" clean archive

[[ -d "$BUILT_APP" ]] || quill_fail "release app was not archived at $BUILT_APP"

ARCHIVED_TEAM="$(quill_signature_team "$BUILT_APP")"
[[ -n "$ARCHIVED_TEAM" && "$ARCHIVED_TEAM" != "not set" ]] \
  || quill_fail 'the archived app signature is missing its team identifier'
if [[ -n "${QUILL_DEVELOPMENT_TEAM:-}" && "$ARCHIVED_TEAM" != "$QUILL_DEVELOPMENT_TEAM" ]]; then
  quill_fail "archive team $ARCHIVED_TEAM does not match expected team $QUILL_DEVELOPMENT_TEAM"
fi

# Exporting is a required distribution step, not a redundant copy. Xcode
# re-signs every nested Sparkle helper in the correct inside-out order with the
# selected Developer ID identity and secure timestamp.
/bin/rm -rf "$EXPORT_PATH"
/bin/rm -f "$EXPORT_OPTIONS_PLIST"
/usr/bin/plutil -create xml1 "$EXPORT_OPTIONS_PLIST"
/usr/bin/plutil -insert method -string developer-id "$EXPORT_OPTIONS_PLIST"
/usr/bin/plutil -insert signingStyle -string manual "$EXPORT_OPTIONS_PLIST"
/usr/bin/plutil -insert teamID -string "$ARCHIVED_TEAM" "$EXPORT_OPTIONS_PLIST"
/usr/bin/plutil -insert signingCertificate -string "$SIGNING_IDENTITY" "$EXPORT_OPTIONS_PLIST"

EXPORT_ARGS=(
  -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_PATH"
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
)
if [[ "${QUILL_VERBOSE_BUILD:-0}" != "1" ]]; then
  EXPORT_ARGS=(-quiet "${EXPORT_ARGS[@]}")
fi
/usr/bin/xcodebuild "${EXPORT_ARGS[@]}"

[[ -d "$EXPORTED_APP" ]] || quill_fail "Developer ID export did not produce $EXPORTED_APP"
/bin/rm -rf "$OUTPUT_APP"
/usr/bin/ditto "$EXPORTED_APP" "$OUTPUT_APP"
quill_assert_release_app "$OUTPUT_APP" "${QUILL_DEVELOPMENT_TEAM:-}"

DSYM="$ARCHIVE_PATH/dSYMs/Quill.app.dSYM"
if [[ -d "$DSYM" ]]; then
  VERSION="$(quill_plist_value CFBundleShortVersionString "$OUTPUT_APP/Contents/Info.plist")"
  BUILD="$(quill_plist_value CFBundleVersion "$OUTPUT_APP/Contents/Info.plist")"
  SYMBOLS_DIR="$OUTPUT_DIR/symbols"
  SYMBOLS_ARCHIVE="$SYMBOLS_DIR/Quill-$VERSION-$BUILD.dSYM.zip"
  /bin/mkdir -p "$SYMBOLS_DIR"
  /bin/rm -f "$SYMBOLS_ARCHIVE"
  /usr/bin/ditto -c -k --keepParent "$DSYM" "$SYMBOLS_ARCHIVE"
else
  quill_fail 'the release archive did not contain Quill.app.dSYM'
fi

quill_note "Built and verified $OUTPUT_APP"
quill_note "Archived debug symbols at $SYMBOLS_ARCHIVE"
