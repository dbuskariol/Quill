#!/usr/bin/env bash
set -euo pipefail
export GH_TOKEN="$(gh auth token --hostname github.com --user dbuskariol)"
[[ "$(gh api user --jq '.login + ":" + (.id | tostring)')" == 'dbuskariol:32349796' ]] || { echo 'Unexpected GitHub identity' >&2; exit 1; }
exec gh "$@"
