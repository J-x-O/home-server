#!/usr/bin/env bash
# Prompts for a secret (input hidden) and writes it straight into the encrypted
# secrets/secrets.yaml. The plain value never touches the disk.
#
#   nix shell nixpkgs#sops nixpkgs#jq -c ./scripts/set-secret.sh ionos/api-key
set -euo pipefail

[[ $# -eq 1 ]] || { echo "usage: $0 <group/name>" >&2; exit 1; }
cd "$(dirname "$0")/.."

# ionos/api-key -> ["ionos"]["api-key"]
index=$(printf '%s' "$1" | jq -Rr 'split("/") | map("[" + tojson + "]") | join("")')

read -rsp "Value for $1 (hidden): " value
echo
[[ -n $value ]] || { echo "empty value, nothing stored" >&2; exit 1; }

printf '%s' "$value" | jq -Rs . | sops set --value-stdin secrets/secrets.yaml "$index"
unset value
echo "Stored $1 (encrypted)."
