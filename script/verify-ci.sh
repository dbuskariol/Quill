#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${QUILL_CI_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Quill/CI}"
RESULT="$DERIVED_DATA/Results/$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p "$(dirname "$RESULT")"
while IFS= read -r script; do bash -n "$ROOT_DIR/$script"; done < <(git -C "$ROOT_DIR" ls-files --cached --others --exclude-standard "script/*.sh" "script/**/*.sh" ".githooks/*")
plutil -lint "$ROOT_DIR/Configuration/Quill-Info.plist"
git -C "$ROOT_DIR" diff --check
xcodebuild -project "$ROOT_DIR/Quill.xcodeproj" -scheme Quill -configuration Debug -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$DERIVED_DATA" -resultBundlePath "$RESULT" CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
xcrun xcresulttool get test-results summary --path "$RESULT" > "$DERIVED_DATA/test-summary.json"
COUNT="$(plutil -extract totalTestCount raw -o - "$DERIVED_DATA/test-summary.json")"
FAILED="$(plutil -extract failedTests raw -o - "$DERIVED_DATA/test-summary.json")"
[[ "$COUNT" -gt 0 && "$FAILED" -eq 0 ]] || { echo 'Missing or failed tests' >&2; exit 1; }
echo "Verified $COUNT tests"
xcodebuild -project "$ROOT_DIR/Quill.xcodeproj" -scheme Quill -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
ARCHS="$(lipo -archs "$DERIVED_DATA/Build/Products/Release/Quill.app/Contents/MacOS/Quill")"
[[ " $ARCHS " == *' arm64 '* && " $ARCHS " == *' x86_64 '* ]] || { echo "Missing universal architectures: $ARCHS" >&2; exit 1; }
echo "Quill verification passed"
