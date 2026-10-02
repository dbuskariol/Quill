#!/usr/bin/env bash
set -euo pipefail
# Supply the pinned account directly to Git's credential protocol. gh auth
# git-credential can select the globally active account despite GH_TOKEN.
[[ "${1:-}" == get ]] || exit 0
host=''
protocol=''
while IFS='=' read -r key value; do
  [[ -n "$key" ]] || break
  case "$key" in
    host) host="$value" ;;
    protocol) protocol="$value" ;;
  esac
done
[[ "$protocol" == https && "$host" == github.com ]] || exit 0
token="$(gh auth token --hostname github.com --user dbuskariol)"
# Git consumes this output privately; never log or persist the token.
printf 'username=dbuskariol\npassword=%s\n\n' "$token"
