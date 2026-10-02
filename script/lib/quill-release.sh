#!/usr/bin/env bash

# Shared, fail-closed release invariants. Every script that can create a
# distributable Quill artifact sources this file so local and CI releases are
# held to the same standard.

if [[ -n "${QUILL_RELEASE_LIB_LOADED:-}" ]]; then
  return 0
fi
readonly QUILL_RELEASE_LIB_LOADED=1

readonly QUILL_EXPECTED_BUNDLE_ID="com.dbuskariol.quill"
readonly QUILL_EXPECTED_MINIMUM_SYSTEM="26.0"
readonly QUILL_EXPECTED_ARCHITECTURES=(arm64 x86_64)
readonly QUILL_EXPECTED_GITHUB_REPOSITORY="dbuskariol/Quill"
readonly QUILL_EXPECTED_FEED_URL="https://github.com/$QUILL_EXPECTED_GITHUB_REPOSITORY/releases/latest/download/appcast.xml"

quill_fail() {
  printf 'Quill release error: %s\n' "$1" >&2
  exit 1
}

quill_note() {
  printf '==> %s\n' "$1"
}

quill_default_derived_data() {
  local purpose="$1"
  local base="${QUILL_DERIVED_DATA_ROOT:-${HOME:?}/Library/Developer/Xcode/DerivedData/Quill}"

  # Build and test hosts are executable code. Keep them out of protected user
  # folders so macOS never mistakes routine verification for Documents access.
  printf '%s/%s\n' "$base" "$purpose"
}

quill_require_tool() {
  /usr/bin/command -v "$1" >/dev/null 2>&1 || quill_fail "required tool is unavailable: $1"
}

quill_plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null || true
}

quill_json_value() {
  /usr/bin/plutil -extract "$1" raw -o - "$2" 2>/dev/null || true
}

quill_codesign_details() {
  /usr/bin/codesign -dvvv --verbose=4 "$1" 2>&1
}

quill_signature_team() {
  /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}' <<<"$(quill_codesign_details "$1")"
}

quill_assert_developer_id_signature() {
  local signed_path="$1"
  local expected_team="${2:-}"
  local require_hardened_runtime="${3:-0}"
  local signing_details team

  /usr/bin/codesign --verify --strict --verbose=2 "$signed_path" \
    || quill_fail "the code signature is invalid: $signed_path"
  signing_details="$(quill_codesign_details "$signed_path")"
  /usr/bin/grep -q '^Authority=Developer ID Application:' <<<"$signing_details" \
    || quill_fail "Developer ID Application did not sign: $signed_path"
  /usr/bin/grep -Eq '^Timestamp=.+$' <<<"$signing_details" \
    || quill_fail "the signature is missing a trusted timestamp: $signed_path"
  if [[ "$require_hardened_runtime" == "1" ]]; then
    /usr/bin/grep -Eq '^CodeDirectory .*flags=.*\(runtime\)' <<<"$signing_details" \
      || quill_fail "the hardened runtime is not enabled: $signed_path"
  fi
  team="$(/usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}' <<<"$signing_details")"
  [[ -n "$team" && "$team" != "not set" ]] \
    || quill_fail "the signature is missing its team identifier: $signed_path"
  if [[ -n "$expected_team" && "$team" != "$expected_team" ]]; then
    quill_fail "signature team $team does not match expected team $expected_team: $signed_path"
  fi
}

quill_find_developer_id_identity() {
  /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
    | /usr/bin/awk -F\" '/Developer ID Application/ { print $2; exit }'
}

quill_assert_clean_worktree() {
  local root="$1"
  if [[ "${QUILL_ALLOW_DIRTY:-0}" == "1" ]]; then
    return 0
  fi
  [[ -z "$(/usr/bin/git -C "$root" status --porcelain --untracked-files=normal)" ]] \
    || quill_fail 'the worktree is dirty; commit the verified release source first (or set QUILL_ALLOW_DIRTY=1 for a non-shipping rehearsal)'
}

quill_assert_release_metadata() {
  local root="$1"
  local settings version build notes_heading tag
  settings="$(/usr/bin/xcodebuild \
    -project "$root/Quill.xcodeproj" \
    -scheme Quill \
    -configuration Release \
    -showBuildSettings 2>/dev/null)"
  version="$(/usr/bin/awk '/MARKETING_VERSION =/{print $3; exit}' <<<"$settings")"
  build="$(/usr/bin/awk '/CURRENT_PROJECT_VERSION =/{print $3; exit}' <<<"$settings")"

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] \
    || quill_fail "MARKETING_VERSION is not a release version: ${version:-missing}"
  [[ "$build" =~ ^[1-9][0-9]*$ ]] \
    || quill_fail "CURRENT_PROJECT_VERSION must be a positive integer: ${build:-missing}"


  notes_heading="$(/usr/bin/sed -n '1p' "$root/Documentation/RELEASE_NOTES.md" 2>/dev/null || true)"
  [[ "$notes_heading" == "# Quill $version" ]] \
    || quill_fail "release notes must start with '# Quill $version'"

  tag="${QUILL_RELEASE_TAG:-}"
  if [[ -z "$tag" && "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    tag="${GITHUB_REF_NAME:-}"
  fi
  # An exact tag describes the committed tree, not uncommitted version work.
  # Release builds already require a clean worktree; local verification must
  # remain usable while preparing the next version directly from a release tag.
  if [[ -z "$tag" && -z "$(/usr/bin/git -C "$root" status --porcelain --untracked-files=normal)" ]]; then
    tag="$(/usr/bin/git -C "$root" describe --tags --exact-match 2>/dev/null || true)"
  fi
  if [[ -n "$tag" ]]; then
    [[ "$tag" == "v$version" ]] \
      || quill_fail "release tag $tag does not match MARKETING_VERSION $version"
  elif [[ "${QUILL_REQUIRE_RELEASE_TAG:-0}" == "1" ]]; then
    quill_fail "a v$version release tag is required"
  fi

  printf '%s\t%s\n' "$version" "$build"
}

quill_assert_release_app() {
  local app="$1"
  local expected_team="${2:-}"
  local info executable bundle_id minimum_system version build architectures team entitlements

  [[ -d "$app" ]] || quill_fail "app bundle not found: $app"
  info="$app/Contents/Info.plist"
  [[ -f "$info" ]] || quill_fail "Info.plist is missing from $app"
  /usr/bin/plutil -lint "$info" >/dev/null || quill_fail 'Info.plist is invalid'

  bundle_id="$(quill_plist_value CFBundleIdentifier "$info")"
  minimum_system="$(quill_plist_value LSMinimumSystemVersion "$info")"
  version="$(quill_plist_value CFBundleShortVersionString "$info")"
  build="$(quill_plist_value CFBundleVersion "$info")"
  executable="$app/Contents/MacOS/$(quill_plist_value CFBundleExecutable "$info")"

  [[ "$bundle_id" == "$QUILL_EXPECTED_BUNDLE_ID" ]] \
    || quill_fail "unexpected bundle identifier: ${bundle_id:-missing}"
  [[ "$minimum_system" == "$QUILL_EXPECTED_MINIMUM_SYSTEM" ]] \
    || quill_fail "minimum system must be macOS $QUILL_EXPECTED_MINIMUM_SYSTEM"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] \
    || quill_fail "invalid app version: ${version:-missing}"
  [[ "$build" =~ ^[1-9][0-9]*$ ]] \
    || quill_fail "invalid app build: ${build:-missing}"
  [[ -x "$executable" ]] || quill_fail "main executable is missing: $executable"
  /usr/bin/codesign --verify --strict --deep --verbose=2 "$app" \
    || quill_fail 'the app signature is invalid'
  quill_assert_developer_id_signature "$app" "$expected_team" 1
  team="$(quill_signature_team "$app")"

  architectures="$(/usr/bin/lipo -archs "$executable")"
  local architecture
  for architecture in "${QUILL_EXPECTED_ARCHITECTURES[@]}"; do
    [[ " $architectures " == *" $architecture "* ]] \
      || quill_fail "the release is missing $architecture (found: $architectures)"
  done

  entitlements="$(/usr/bin/mktemp -t quill-entitlements.XXXXXX)"
  /usr/bin/codesign -d --entitlements :- "$app" >"$entitlements" 2>/dev/null \
    || { /bin/rm -f "$entitlements"; quill_fail 'unable to inspect release entitlements'; }
  [[ -z "$(quill_plist_value com.apple.security.get-task-allow "$entitlements")" ]] \
    || { /bin/rm -f "$entitlements"; quill_fail 'release contains the debug get-task-allow entitlement'; }
  [[ -z "$(quill_plist_value com.apple.security.cs.disable-library-validation "$entitlements")" ]] \
    || { /bin/rm -f "$entitlements"; quill_fail 'release disables library validation'; }
  /bin/rm -f "$entitlements"

  [[ -f "$app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" ]] \
    || quill_fail 'the embedded Sparkle framework is missing'
  local sparkle_code
  for sparkle_code in \
    "$app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" \
    "$app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" \
    "$app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" \
    "$app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" \
    "$app/Contents/Frameworks/Sparkle.framework"
  do
    [[ -e "$sparkle_code" ]] || quill_fail "embedded Sparkle code is missing: $sparkle_code"
    quill_assert_developer_id_signature "$sparkle_code" "$team" 1
  done
  local feed_url public_key
  feed_url="$(quill_plist_value SUFeedURL "$info")"
  public_key="$(quill_plist_value SUPublicEDKey "$info")"
  [[ "$feed_url" == "$QUILL_EXPECTED_FEED_URL" ]] \
    || quill_fail "unexpected Sparkle feed URL: ${feed_url:-missing}"
  [[ "$public_key" =~ ^[A-Za-z0-9+/]{43}=$ ]] \
    || quill_fail 'the Sparkle EdDSA public key is invalid'
  [[ "$(quill_plist_value SURequireSignedFeed "$info")" == "true" ]] \
    || quill_fail 'signed Sparkle feeds are not required by the app'
  [[ "$(quill_plist_value SUVerifyUpdateBeforeExtraction "$info")" == "true" ]] \
    || quill_fail 'Sparkle update verification before extraction is disabled'
}

quill_assert_notarized_app() {
  local app="$1"
  /usr/bin/xcrun stapler validate "$app" >/dev/null \
    || quill_fail 'the app does not contain a valid stapled notarization ticket'
  /usr/sbin/spctl --assess --type execute --verbose=4 "$app" \
    || quill_fail 'Gatekeeper rejected the app'
}

quill_assert_signed_disk_image() {
  local disk_image="$1"
  local expected_team="${2:-}"

  [[ -f "$disk_image" ]] || quill_fail "disk image not found: $disk_image"
  /usr/bin/hdiutil verify "$disk_image" >/dev/null \
    || quill_fail 'the disk image failed its integrity check'
  quill_assert_developer_id_signature "$disk_image" "$expected_team"
}

quill_assert_notarized_disk_image() {
  local disk_image="$1"
  local expected_team="${2:-}"

  quill_assert_signed_disk_image "$disk_image" "$expected_team"
  /usr/bin/xcrun stapler validate "$disk_image" >/dev/null \
    || quill_fail 'the disk image does not contain a valid stapled notarization ticket'
  /usr/sbin/spctl \
    --assess \
    --type open \
    --context context:primary-signature \
    --verbose=4 \
    "$disk_image" \
    || quill_fail 'Gatekeeper rejected the disk image'
}

QUILL_NOTARY_ARGS=()

quill_configure_notary_credentials() {
  QUILL_NOTARY_ARGS=()
  if [[ -n "${QUILL_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    QUILL_NOTARY_ARGS=(--keychain-profile "$QUILL_NOTARY_KEYCHAIN_PROFILE")
  elif [[ -n "${QUILL_NOTARY_KEY_PATH:-}" \
    && -n "${QUILL_NOTARY_KEY_ID:-}" \
    && -n "${QUILL_NOTARY_ISSUER_ID:-}" ]]; then
    [[ -f "$QUILL_NOTARY_KEY_PATH" ]] \
      || quill_fail "App Store Connect API key is missing: $QUILL_NOTARY_KEY_PATH"
    QUILL_NOTARY_ARGS=(
      --key "$QUILL_NOTARY_KEY_PATH"
      --key-id "$QUILL_NOTARY_KEY_ID"
      --issuer "$QUILL_NOTARY_ISSUER_ID"
    )
  else
    /bin/cat >&2 <<'EOF'
Notarization credentials are not configured. Use a stored Keychain profile:

  QUILL_NOTARY_KEYCHAIN_PROFILE="Quill Notary" script/release.sh finalize

CI may instead provide QUILL_NOTARY_KEY_PATH, QUILL_NOTARY_KEY_ID, and
QUILL_NOTARY_ISSUER_ID. Passwords and Apple IDs are never accepted inline.
EOF
    exit 1
  fi
}

quill_submit_notarization() {
  local artifact="$1"
  local submission_json="$2"
  local log_json="$3"
  local submission_id status log_status issue_count issue_type

  quill_configure_notary_credentials
  /bin/rm -f "$submission_json" "$log_json"
  /usr/bin/xcrun notarytool submit \
    "$artifact" \
    "${QUILL_NOTARY_ARGS[@]}" \
    --wait \
    --output-format json >"$submission_json"

  submission_id="$(quill_json_value id "$submission_json")"
  status="$(quill_json_value status "$submission_json")"
  [[ -n "$submission_id" ]] || quill_fail 'Apple notarization returned no submission identifier'
  /usr/bin/xcrun notarytool log \
    "$submission_id" \
    "$log_json" \
    "${QUILL_NOTARY_ARGS[@]}" \
    >/dev/null

  log_status="$(quill_json_value status "$log_json")"
  if ! issue_count="$(/usr/bin/plutil -extract issues raw -o - "$log_json" 2>/dev/null)"; then
    issue_type="$(/usr/bin/plutil -type issues "$log_json" 2>/dev/null || true)"
    [[ "$issue_type" == "(any)" ]] \
      || quill_fail "Apple's notarization log has an unreadable issues field; inspect $log_json"
    issue_count=0
  fi
  [[ "$status" == "Accepted" && "$log_status" == "Accepted" ]] \
    || quill_fail "notarization failed with status ${status:-unknown}; inspect $log_json"
  [[ "$issue_count" == "0" ]] \
    || quill_fail "notarization reported ${issue_count:-unknown} issues; inspect $log_json"
}

quill_resolve_sparkle_tool() {
  local root="$1"
  local derived_data="$2"
  local tool="$3"
  local path="$derived_data/SourcePackages/artifacts/sparkle/Sparkle/bin/$tool"
  if [[ ! -x "$path" ]]; then
    /usr/bin/xcodebuild \
      -project "$root/Quill.xcodeproj" \
      -scheme Quill \
      -configuration Release \
      -destination 'generic/platform=macOS' \
      -derivedDataPath "$derived_data" \
      -resolvePackageDependencies >/dev/null
  fi
  [[ -x "$path" ]] || quill_fail "Sparkle tool was not resolved: $tool"
  printf '%s\n' "$path"
}

quill_assert_sparkle_signing_key() {
  local root="$1"
  local app="$2"
  local derived_data="$3"
  local embedded_key actual_key generate_keys
  embedded_key="$(quill_plist_value SUPublicEDKey "$app/Contents/Info.plist")"

  if [[ -n "${QUILL_SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
    [[ -f "$QUILL_SPARKLE_PRIVATE_KEY_FILE" ]] \
      || quill_fail "Sparkle private key file is missing: $QUILL_SPARKLE_PRIVATE_KEY_FILE"
    actual_key="$(/usr/bin/xcrun swift "$root/script/sparkle-public-key.swift" "$QUILL_SPARKLE_PRIVATE_KEY_FILE")" \
      || quill_fail 'unable to derive the Sparkle public key'
  else
    generate_keys="$(quill_resolve_sparkle_tool "$root" "$derived_data" generate_keys)"
    actual_key="$("$generate_keys" --account "${QUILL_SPARKLE_KEY_ACCOUNT:-quill-ed25519}" -p 2>/dev/null)" \
      || quill_fail 'unable to read the Sparkle signing key from Keychain'
  fi
  [[ "$actual_key" == "$embedded_key" ]] \
    || quill_fail 'the Sparkle signing key does not match SUPublicEDKey embedded in Quill'
}
