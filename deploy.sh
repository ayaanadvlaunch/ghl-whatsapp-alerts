#!/usr/bin/env bash
# Run this ONCE on a fresh Oracle Always Free Ubuntu 22.04/24.04 ARM VM.
# Usage:
#   1. SCP this whole project to the VM:  rsync -avz ./ ubuntu@VM_IP:~/ghl-wa-bridge/
#   2. SSH in:                            ssh ubuntu@VM_IP
#   3. cd ~/ghl-wa-bridge && cp .env.example .env  (then fill in .env)
#   4. bash deploy.sh

set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "ERROR: .env missing. Copy .env.example to .env and fill it in first." >&2
  exit 1
fi

# shellcheck disable=SC1091
source .env

if [ -z "${PUBLIC_HOSTNAME:-}" ] || [ -z "${N8N_ENCRYPTION_KEY:-}" ] || [ -z "${WAHA_API_KEY:-}" ]; then
  echo "ERROR: PUBLIC_HOSTNAME / N8N_ENCRYPTION_KEY / WAHA_API_KEY must be set in .env" >&2
  exit 1
fi

echo "==> Updating apt"
sudo apt-get update -y

echo "==> Installing Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi

echo "==> Opening firewall ports 80, 443 (Ubuntu's iptables)"
# Oracle Ubuntu images use iptables with a default-DROP on INPUT for non-22 traffic.
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80  -j ACCEPT || true
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT || true
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 443 -j ACCEPT || true
# Persist
if ! command -v netfilter-persistent >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
fi
sudo netfilter-persistent save

echo "==> Bringing up the stack"
sudo docker compose pull
sudo docker compose up -d

echo "==> Waiting for n8n to come up"
for i in $(seq 1 30); do
  if curl -sk "https://${PUBLIC_HOSTNAME}/" -o /dev/null; then
    break
  fi
  sleep 2
done

echo
echo "================================================"
echo "DONE. Next:"
echo "  1. Open https://${PUBLIC_HOSTNAME}/  → set up the n8n owner account."
echo "  2. From your Mac, run: bash scripts/pair-whatsapp.sh <your VM public IP>"
echo "     (will open SSH tunnel + browser to the WAHA QR)."
echo "  3. After pairing, scripts/list-groups.sh if you want a group instead of a person."
echo "  4. Put the recipient in .env WHATSAPP_TO, then: docker compose up -d (re-applies env)"
echo "  5. In n8n, import n8n/workflows/booking-to-whatsapp.json and Activate it."
echo "================================================"
