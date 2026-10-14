# GHL booking → WhatsApp alert

Get a WhatsApp message the moment someone books a call in GoHighLevel — **without connecting
anyone's WhatsApp to GHL.**

```
Contact books on the GHL calendar
        │
        ▼
GHL workflow  ──(webhook)──▶  n8n  ──▶  WAHA  ──▶  WhatsApp message to the owner (or a group)
```

- **GHL** only fires a webhook. Nothing WhatsApp-related is set up inside GHL.
- **n8n** receives the webhook and formats the message.
- **WAHA** is a free, self-hosted WhatsApp Web API. It is linked to a separate "bot"
  WhatsApp number (like WhatsApp Web on a laptop) and sends the alert from that number.
- The owner just receives a normal WhatsApp message. Their own WhatsApp is never touched.

Example alert:

```
📅 Strategy Call Booked

Name
Jane Doe

Email
jane@example.com

Phone
+64 21 123 4567

Booked For
Thursday 16 Oct, 10:00 AM

With
Angie
```

Cost: **$0**. Everything runs on an Oracle Cloud "Always Free" server. About 45 minutes to set up.

---

## What you need

1. **A spare phone number for the bot.** A cheap prepaid SIM is the most reliable option.
   It needs to receive the WhatsApp verification code once. Install WhatsApp (or WhatsApp Business)
   on any phone with that number. **Do not use the owner's own number.**
2. **An Oracle Cloud free account** (https://www.oracle.com/cloud/free/). It asks for a card but
   the Always Free server is not charged. Any Linux server with Docker works if you already have one.
3. **A computer with a terminal** (Mac or Linux; on Windows use WSL) and an SSH key
   (`ssh-keygen -t ed25519` if you don't have one).
4. Admin access to the GHL sub-account.

---

## 1. Create the free server

1. Oracle Cloud → **Compute → Instances → Create instance**
   - Image: **Canonical Ubuntu 24.04**
   - Shape: **VM.Standard.A1.Flex** (Ampere ARM), 2 OCPU / 12 GB RAM — inside Always Free
   - Paste your public SSH key (`cat ~/.ssh/id_ed25519.pub`)
   - Assign a public IPv4: **Yes**
2. Note the **public IP** once it's running.
3. Open web ports: instance → **Subnet → Default Security List → Add Ingress Rules**
   - Source `0.0.0.0/0`, TCP, destination port **80**
   - Source `0.0.0.0/0`, TCP, destination port **443**

> If Oracle says "out of capacity" for ARM, try another availability domain or retry later.

## 2. Fill in the settings

On your computer, in this folder:

```bash
cp .env.example .env
```

Open `.env` and set:

| Setting | What to put |
|---|---|
| `PUBLIC_HOSTNAME` | Your IP with dashes + `.nip.io`, e.g. `132-145-67-89.nip.io` (free hostname, no domain needed) |
| `N8N_ENCRYPTION_KEY`, `WAHA_API_KEY`, `GHL_WEBHOOK_SECRET` | Run `openssl rand -hex 32` three times and paste one into each |
| `WHATSAPP_TO` | Who gets the alert. A person: `64211234567@c.us` (country code + number, no `+`). A group: see step 5 |
| `TZ` | Your timezone, e.g. `Pacific/Auckland` |

Keep `.env` private. It is git-ignored.

## 3. Deploy

```bash
rsync -avz ./ ubuntu@YOUR_IP:~/ghl-booking-whatsapp-alert/
ssh ubuntu@YOUR_IP 'cd ~/ghl-booking-whatsapp-alert && bash deploy.sh'
```

`deploy.sh` installs Docker, opens the server firewall and starts three containers
(Caddy for HTTPS, n8n, WAHA). First run takes ~3 minutes.

Then open `https://YOUR-HOSTNAME.nip.io` and create your n8n login.

## 4. Link the bot WhatsApp number

```bash
bash scripts/pair-whatsapp.sh YOUR_IP
```

A QR code opens. On the **bot phone**: WhatsApp → Settings → **Linked Devices → Link a device** →
scan it. The QR expires after ~60 seconds; just run the script again if it does.
Press Enter when done; it should say `"status": "WORKING"`.

## 5. (Optional) Send to a group instead of one person

Create a WhatsApp group with the owner + the bot number, then:

```bash
bash scripts/list-groups.sh YOUR_IP
```

Copy the group id (`120363...@g.us`) into `WHATSAPP_TO` in `.env`, then push it and restart:

```bash
scp .env ubuntu@YOUR_IP:~/ghl-booking-whatsapp-alert/.env
ssh ubuntu@YOUR_IP 'cd ~/ghl-booking-whatsapp-alert && sudo docker compose up -d'
```

> **Tip:** have the owner save the bot number as a contact and send it one "hi" first.
> WhatsApp trusts messages from a saved contact far more than from a stranger.

## 6. Import the n8n workflow

1. In n8n: **Workflows → Import from file →** `n8n/workflows/booking-to-whatsapp.json`
2. Click **Publish / Activate** (top right).
3. Your webhook URL is: `https://YOUR-HOSTNAME.nip.io/webhook/ghl-booking`

Test it end to end:

```bash
bash scripts/test-webhook.sh
```

A "TEST - Strategy Call Booked" message should arrive within a couple of seconds.

## 7. Wire it into GHL

**Automation → Workflows → Create workflow → Start from scratch**

**Trigger:** *Customer Booked Appointment* (sometimes called *Appointment Status*)
→ add filter **Calendar is** the strategy-call calendar (e.g. Angie's).

**Action — pick ONE:**

### Option A: "Custom Webhook" action (cleanest)
- Method: `POST`
- URL: `https://YOUR-HOSTNAME.nip.io/webhook/ghl-booking`
- Header: `X-GHL-Secret` = your `GHL_WEBHOOK_SECRET`
- Body type: JSON
  ```json
  {
    "title": "Strategy Call Booked",
    "name": "{{contact.name}}",
    "email": "{{contact.email}}",
    "phone": "{{contact.phone}}",
    "booked": "{{appointment.start_time}}",
    "with": "Angie",
    "calendar": "{{calendar.name}}"
  }
  ```

### Option B: plain "Webhook" action (if Custom Webhook isn't available on your plan)
- URL: `https://YOUR-HOSTNAME.nip.io/webhook/ghl-booking`
- Method: `POST`
- **Custom Data** (key → value):
  - `secret` → your `GHL_WEBHOOK_SECRET`
  - `booked` → `{{appointment.start_time}}`
  - `with` → `Angie`
  - `title` → `Strategy Call Booked`

  GHL sends the contact's name, email and phone automatically.

> Merge-tag names vary slightly between GHL accounts. Use the **tag picker** (`{}` icon) in the
> field to insert the appointment date/time rather than typing it. `{{appointment.only_start_date}}`
> and `{{appointment.only_start_time}}` also work if you want them separately.

**Save → Publish.** Book a test appointment on the calendar and the alert should land on WhatsApp.

Want more fields? Add any of `name, email, phone, booked, with, calendar, notes` to the body.
Blank ones are skipped. To send completely custom text, send `{"message": "your text"}` instead.

---

## Keeping it healthy

| Problem | Fix |
|---|---|
| Alerts stopped, n8n shows WAHA 422 "session status is not as expected" | WhatsApp dropped an old WAHA version. On the server: `cd ~/ghl-booking-whatsapp-alert && sudo docker compose pull waha && sudo docker compose up -d waha`. If it then asks for a QR, re-run step 4. **Try this first, before anything else.** |
| Bot was logged out from the phone | Re-run step 4. |
| GHL shows the webhook failed | Good — that's on purpose. The workflow passes WAHA's real status back to GHL, so a failed send shows up as a failure in GHL's execution log instead of a fake "success". Check n8n **Executions** for the reason. |
| Want to see logs | `ssh ubuntu@YOUR_IP 'cd ~/ghl-booking-whatsapp-alert && sudo docker compose logs -f --tail 100'` |

Check on it every few weeks: run `scripts/test-webhook.sh` and update the WAHA image now and then.
Sessions that sit idle for a long time can drop.

## Good to know

- WAHA uses WhatsApp Web, which is unofficial. It's fine for a few internal alerts a day.
  **Don't use the bot number to mass-message customers** — that's how numbers get banned.
- WAHA is never exposed to the internet; only n8n's webhook is public, and it rejects any
  request without your secret.
- If nip.io ever stops working, point any domain you own at the server IP and change
  `PUBLIC_HOSTNAME`.
