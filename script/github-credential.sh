#!/usr/bin/env bash
set -euo pipefail
# Token remains in the process environment; never print it or persist it.
export GH_TOKEN="$(gh auth token --hostname github.com --user dbuskariol)"
exec gh auth git-credential "$@"
