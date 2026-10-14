#!/usr/bin/env bash
# Run on your Mac. Queries WAHA over SSH for the list of WhatsApp groups
# the bot account is a member of. Copy the `id` of your target group into
# .env as WHATSAPP_TO, then redeploy.
#
# Usage:  bash scripts/list-groups.sh <vm-public-ip>

set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source .env

VM_HOST="${1:-}"
[ -z "$VM_HOST" ] && { echo "Usage: $0 <vm-public-ip>"; exit 1; }
VM_USER="${VM_USER:-ubuntu}"

# Reuse SSH tunnel pattern from pair-whatsapp.sh
pkill -f "ssh -fN -L 3000:127.0.0.1:3000" 2>/dev/null || true
ssh -fN -L 3000:127.0.0.1:3000 "${VM_USER}@${VM_HOST}"
trap 'pkill -f "ssh -fN -L 3000:127.0.0.1:3000" 2>/dev/null || true' EXIT
sleep 1

curl -sf -H "X-Api-Key: ${WAHA_API_KEY}" 'http://localhost:3000/api/default/groups?limit=200' \
  | python3 -c '
import json, sys
groups = json.load(sys.stdin)
print(f"{\"NAME\":<40} {\"ID (paste into WHATSAPP_TO)\"}")
print("-" * 80)
for g in groups:
    name = g.get("name") or g.get("subject") or "(unnamed)"
    print(f"{name[:38]:<40} {g.get(\"id\",\"?\")}")
'
