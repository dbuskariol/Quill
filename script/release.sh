#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/lib/quill-release.sh"

MODE="${1:-prepare}"
: "${QUILL_RELEASE_DIR:?Set a new, external release output directory}"
OUTPUT_PARENT="$(cd "$(dirname "$QUILL_RELEASE_DIR")" && pwd -P)"
[[ "$OUTPUT_PARENT/" != "$ROOT_DIR/"* ]] || quill_fail 'release output must be external to the checkout'
[[ ! -e "$QUILL_RELEASE_DIR" ]] || quill_fail 'release output already exists; choose a new directory'
"$ROOT_DIR/script/check-identity.sh"
case "$MODE" in
  prepare|finalize) ;;
  *)
    printf 'Usage: script/release.sh [prepare|finalize]\n' >&2
    exit 64
    ;;
esac

if [[ "$MODE" == "finalize" ]]; then
  [[ "${QUILL_ALLOW_DIRTY:-0}" != "1" ]] \
    || quill_fail 'final releases can never be built from a dirty worktree'
  export QUILL_REQUIRE_RELEASE_TAG=1
fi

quill_assert_clean_worktree "$ROOT_DIR"
IFS=$'\t' read -r VERSION BUILD < <(quill_assert_release_metadata "$ROOT_DIR")
quill_note "Preparing Quill $VERSION ($BUILD) in $MODE mode"

"$ROOT_DIR/script/build-release.sh"

if [[ "$MODE" == "prepare" ]]; then
  QUILL_NOTARY_PREPARE_ONLY=1 "$ROOT_DIR/script/notarize-release.sh"
  QUILL_SKIP_BUILD=1 \
    QUILL_ALLOW_UNNOTARIZED_PACKAGE=1 \
    "$ROOT_DIR/script/package-update.sh"
  QUILL_ALLOW_UNNOTARIZED_PACKAGE=1 \
    "$ROOT_DIR/script/generate-appcast.sh"
  QUILL_ALLOW_UNNOTARIZED_PACKAGE=1 \
    "$ROOT_DIR/script/create-release-manifest.sh"
  quill_note 'Release rehearsal passed; no Apple service or publishing state was changed'
  exit 0
fi

"$ROOT_DIR/script/notarize-release.sh"
"$ROOT_DIR/script/create-release-manifest.sh"

quill_note "Quill $VERSION ($BUILD) is signed, notarized, stapled, Sparkle-signed, and ready to publish"
