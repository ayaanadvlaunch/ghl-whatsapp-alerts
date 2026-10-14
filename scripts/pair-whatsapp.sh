#!/usr/bin/env bash
# Run on your Mac. Opens an SSH tunnel to WAHA on the Oracle VM,
# starts a WhatsApp session, and opens the QR in your browser to scan.
#
# Usage:  bash scripts/pair-whatsapp.sh <vm-public-ip>
# Env:    VM_USER (default: ubuntu)

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "ERROR: .env missing. Run from project root with .env in place." >&2
  exit 1
fi
# shellcheck disable=SC1091
source .env

VM_HOST="${1:-}"
[ -z "$VM_HOST" ] && { echo "Usage: $0 <vm-public-ip>"; exit 1; }
VM_USER="${VM_USER:-ubuntu}"

WAHA="http://localhost:3000"
HDR=(-H "X-Api-Key: ${WAHA_API_KEY}" -H "Content-Type: application/json")

echo "==> Opening SSH tunnel: localhost:3000 -> ${VM_HOST}:127.0.0.1:3000"
# Kill any existing tunnel on 3000
pkill -f "ssh -fN -L 3000:127.0.0.1:3000" 2>/dev/null || true
ssh -fN -L 3000:127.0.0.1:3000 "${VM_USER}@${VM_HOST}"
sleep 1
trap 'echo "==> Closing tunnel"; pkill -f "ssh -fN -L 3000:127.0.0.1:3000" 2>/dev/null || true' EXIT

# Check current status. WAHA returns 404 if session does not exist.
status_response=$(curl -s -o /tmp/wa_status.json -w "%{http_code}" "${HDR[@]}" "${WAHA}/api/sessions/default" || echo "000")

if [ "$status_response" = "404" ]; then
  echo "==> No 'default' session yet. Creating + starting."
  curl -sf "${HDR[@]}" -X POST "${WAHA}/api/sessions" \
    -d '{"name":"default","start":true}' >/dev/null
elif [ "$status_response" = "200" ]; then
  status=$(python3 -c 'import json,sys; print(json.load(open("/tmp/wa_status.json")).get("status",""))')
  echo "==> Existing session status: $status"
  case "$status" in
    WORKING)        echo "Already paired. Nothing to do."; exit 0 ;;
    STOPPED|FAILED) curl -sf "${HDR[@]}" -X POST "${WAHA}/api/sessions/default/start" >/dev/null ;;
    SCAN_QR_CODE)   ;;  # already waiting for scan
    *)              curl -sf "${HDR[@]}" -X POST "${WAHA}/api/sessions/default/start" >/dev/null || true ;;
  esac
else
  echo "ERROR: unexpected response from WAHA ($status_response). Is the stack up?" >&2
  exit 1
fi

echo "==> Polling for SCAN_QR_CODE state…"
for i in $(seq 1 20); do
  s=$(curl -s "${HDR[@]}" "${WAHA}/api/sessions/default" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || echo "")
  echo "    [$i] status=$s"
  [ "$s" = "SCAN_QR_CODE" ] && break
  [ "$s" = "WORKING" ] && { echo "Session became WORKING — already paired."; exit 0; }
  sleep 2
done

echo "==> Fetching QR PNG to ./qr.png"
curl -sf "${HDR[@]}" "${WAHA}/api/default/auth/qr" -o qr.png
if [ ! -s qr.png ]; then
  echo "ERROR: QR fetch returned empty. Check WAHA logs on VM." >&2
  exit 1
fi

echo "==> Opening qr.png — scan with WhatsApp on the bot phone (QR expires in 60s, then 20s × 5 retries)"
open qr.png 2>/dev/null || xdg-open qr.png 2>/dev/null || echo "Open ./qr.png manually"

echo
echo "After scanning, press ENTER to verify session status..."
read -r

echo "==> Final session status:"
curl -s "${HDR[@]}" "${WAHA}/api/sessions/default" | python3 -m json.tool
