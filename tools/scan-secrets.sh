#!/usr/bin/env bash
# Fails if anything that looks like a credential is committed. Cheap first line of
# defence; GitHub secret scanning should also be enabled on the repo.
set -euo pipefail

patterns=(
  'x-api-key[[:space:]]*[:=][[:space:]]*["'\''][A-Za-z0-9+/=_-]{20,}'
  'ROBLOX_API_KEY[[:space:]]*=[[:space:]]*["'\'']?[A-Za-z0-9+/=_-]{20,}'
  '_\|WARNING:-DO-NOT-SHARE-THIS'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'gh[pousr]_[A-Za-z0-9]{36,}'
)

status=0
for pattern in "${patterns[@]}"; do
  if git grep -nIE -e "$pattern" -- ':!tools/scan-secrets.sh' >/dev/null 2>&1; then
    echo "Possible secret matching: $pattern"
    git grep -nIE -e "$pattern" -- ':!tools/scan-secrets.sh' | cut -c1-120
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "No secrets found"
fi
exit "$status"
