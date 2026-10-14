# GHL → WhatsApp alerts

Send a WhatsApp message for **anything that happens in GoHighLevel** (a call booked, a new lead,
a deal won, a payment, a reply) **without connecting anyone's WhatsApp to GHL.** Free, and
yours to change.

```
Something happens in GHL ──(webhook)──▶ n8n ──▶ WAHA ──▶ WhatsApp to a person or a group
```

- **GHL** only fires a webhook. Nothing WhatsApp-related is set up inside GHL.
- **n8n** (free automation tool) turns the data into a clean message.
- **WAHA** (free WhatsApp Web API) sends it from a separate "bot" WhatsApp number.
- Set up once. After that, **every new alert is just a new GHL workflow.** No code.

Example:

```
📅 Strategy Call Booked

Name
Jane Doe

Phone
+64 21 123 4567

Booked For
Thursday 16 Oct, 10:00 AM

With
Angie
```

| Read | For |
|---|---|
| This README | One-time setup (~45 min) |
| [recipes/](recipes/README.md) | Copy-paste alerts: call booked, new lead, quiz, cancelled, deal won, payment, reply, hot lead |
| [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) | What each piece does, how to build your own, exercises, troubleshooting |

---

## What you need

1. **A spare phone number for the bot.** A cheap prepaid SIM is the most reliable option.
   Install WhatsApp (or WhatsApp Business) with it on any phone. **Not the owner's own number.**
2. **An Oracle Cloud free account** (https://www.oracle.com/cloud/free/). It asks for a card;
   the Always Free server is not charged. Any Linux server with Docker also works.
3. **A computer with a terminal** (Mac/Linux; Windows → WSL) and an SSH key
   (`ssh-keygen -t ed25519` if you don't have one).
4. Admin access to the GHL sub-account.

## 1. Create the free server

1. Oracle Cloud → **Compute → Instances → Create instance**
   - Image: **Canonical Ubuntu 24.04**
   - Shape: **VM.Standard.A1.Flex** (Ampere ARM), 2 OCPU / 12 GB RAM — inside Always Free
   - Paste your public SSH key (`cat ~/.ssh/id_ed25519.pub`)
   - Public IPv4: **Yes**
2. Note the **public IP**.
3. Open web ports: instance → **Subnet → Default Security List → Add Ingress Rules**:
   source `0.0.0.0/0`, TCP, port **80**; and again for port **443**.

> "Out of capacity" for ARM? Try another availability domain, or retry later.

## 2. Fill in the settings

```bash
git clone https://github.com/ayaanadvlaunch/ghl-whatsapp-alerts.git
cd ghl-whatsapp-alerts
cp .env.example .env
```

Open `.env`:

| Setting | What to put |
|---|---|
| `PUBLIC_HOSTNAME` | Your IP with dashes + `.nip.io`, e.g. `132-145-67-89.nip.io` (free hostname, no domain needed) |
| `N8N_ENCRYPTION_KEY`, `WAHA_API_KEY`, `GHL_WEBHOOK_SECRET` | Run `openssl rand -hex 32` three times, one into each |
| `WHATSAPP_TO` | Default recipient. Person: `64211234567@c.us` (country code + number, no `+`). Group: see step 5 |
| `TZ` | Your timezone, e.g. `Pacific/Auckland` |

Keep `.env` private (it's git-ignored).

## 3. Deploy

```bash
rsync -avz ./ ubuntu@YOUR_IP:~/ghl-whatsapp-alerts/
ssh ubuntu@YOUR_IP 'cd ~/ghl-whatsapp-alerts && bash deploy.sh'
```

Installs Docker, opens the server firewall, starts Caddy (HTTPS) + n8n + WAHA. ~3 minutes.
Then open `https://YOUR-HOSTNAME.nip.io` and create your n8n login.

## 4. Link the bot WhatsApp number

```bash
bash scripts/pair-whatsapp.sh YOUR_IP
```

A QR opens. On the **bot phone**: WhatsApp → Settings → **Linked Devices → Link a device** → scan.
It expires after ~60 s; re-run if needed. Press Enter; it should show `"status": "WORKING"`.

## 5. (Optional) Alerts into a group

Make a WhatsApp group with the bot number in it, then:

```bash
bash scripts/list-groups.sh YOUR_IP
```

Put the group id (`120363...@g.us`) in `WHATSAPP_TO`, then:

```bash
scp .env ubuntu@YOUR_IP:~/ghl-whatsapp-alerts/.env
ssh ubuntu@YOUR_IP 'cd ~/ghl-whatsapp-alerts && sudo docker compose up -d'
```

> **Tip:** have each recipient save the bot number as a contact and send it a "hi" once.
> WhatsApp trusts messages from saved contacts far more.

## 6. Import the n8n workflow

1. n8n → **Workflows → Import from file →** `n8n/workflows/ghl-to-whatsapp.json`
2. **Publish / Activate** (top right)
3. Your webhook URL: `https://YOUR-HOSTNAME.nip.io/webhook/ghl-alert`

```bash
bash scripts/test-webhook.sh
```

A "TEST - Strategy Call Booked" message should arrive within seconds.

## 7. Build alerts in GHL

Every alert is a GHL workflow: **any trigger → Custom Webhook action** →
`POST https://YOUR-HOSTNAME.nip.io/webhook/ghl-alert`, header `X-GHL-Secret: <your secret>`,
JSON body, e.g.:

```json
{
  "title": "Strategy Call Booked",
  "emoji": "📅",
  "name": "{{contact.name}}",
  "phone": "{{contact.phone}}",
  "booked_for": "{{appointment.start_time}}",
  "with": "Angie"
}
```

`title`, `emoji` and `to` are special; **every other key becomes a line in the message.**
Ready-made bodies for 9 common alerts → [recipes/](recipes/README.md).
No Custom Webhook on your plan? The plain Webhook action works too (see recipes).

---

## Keeping it healthy

| Problem | Fix |
|---|---|
| Alerts stopped; n8n shows WAHA 422 "session status is not as expected" | WhatsApp dropped an old WAHA version. On the server: `cd ~/ghl-whatsapp-alerts && sudo docker compose pull waha && sudo docker compose up -d waha`. If it asks for a QR, redo step 4. **Try this first.** |
| Bot was logged out from the phone | Redo step 4. |
| GHL shows the webhook failed | Working as intended: WAHA's real result is passed back to GHL, so a failed send shows as failed. n8n → **Executions** shows why. |
| Logs | `ssh ubuntu@YOUR_IP 'cd ~/ghl-whatsapp-alerts && sudo docker compose logs -f --tail 100'` |

Every few weeks: run `scripts/test-webhook.sh`, and update WAHA now and then.

## Good to know

- WAHA uses WhatsApp Web (unofficial). Fine for internal alerts. **Never bulk-message customers
  from the bot** — that gets numbers banned.
- WAHA is never on the public internet; only n8n's webhook is, and it rejects requests without your secret.
- nip.io gone one day? Point any domain you own at the server and change `PUBLIC_HOSTNAME`.
