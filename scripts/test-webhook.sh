#!/usr/bin/env bash
# Fire a fake "call booked" at the webhook, exactly like GHL will.
# Usage:  bash scripts/test-webhook.sh
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source .env

curl -sS -X POST "https://${PUBLIC_HOSTNAME}/webhook/ghl-booking" \
  -H "Content-Type: application/json" \
  -H "X-GHL-Secret: ${GHL_WEBHOOK_SECRET}" \
  -d '{
    "title": "TEST - Strategy Call Booked",
    "name": "Test Contact",
    "email": "test@example.com",
    "phone": "+64 21 000 0000",
    "booked": "Thursday 16 Oct, 10:00 AM",
    "with": "Angie",
    "calendar": "Strategy Call"
  }'
echo
