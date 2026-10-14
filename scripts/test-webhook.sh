#!/usr/bin/env bash
# Fire a fake alert at the webhook, exactly like GHL will.
# Usage:  bash scripts/test-webhook.sh                       (sample booking alert)
#         bash scripts/test-webhook.sh recipes/new-lead.json  (any recipe's example body)
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source .env

BODY='{"title":"TEST - Strategy Call Booked","emoji":"📅","name":"Test Contact","email":"test@example.com","phone":"+64 21 000 0000","booked_for":"Thursday 16 Oct, 10:00 AM","with":"Angie"}'
[ -n "${1:-}" ] && BODY="$(cat "$1")"

curl -sS -X POST "https://${PUBLIC_HOSTNAME}/webhook/ghl-alert" \
  -H "Content-Type: application/json" \
  -H "X-GHL-Secret: ${GHL_WEBHOOK_SECRET}" \
  -d "$BODY"
echo
