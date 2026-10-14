# How it works

Read this once and you can build, change and fix any alert yourself.

```
 GHL                         your free server                               WhatsApp
┌──────────────┐  HTTPS   ┌───────┐   ┌────────────────────────────┐   ┌──────┐
│ trigger      │ ───────▶ │ Caddy │ ─▶│ n8n workflow               │ ─▶│ WAHA │ ─▶ 📱 owner / group
│ + webhook    │  POST    └───────┘   │ check → format → send → reply│   └──────┘
└──────────────┘                      └────────────────────────────┘
```

## The four pieces

| Piece | What it is | Its job here |
|---|---|---|
| **GHL workflow** | Trigger + "Webhook" action | Decides *when* to alert, and *what data* to send. All your day-to-day changes happen here. |
| **Caddy** | Web server | Gives the server a free HTTPS certificate so GHL can call it securely. You never touch it. |
| **n8n** | Visual automation tool (like Zapier, self-hosted, free) | Receives the webhook, checks the secret, turns the data into a WhatsApp message, hands it to WAHA. |
| **WAHA** | "WhatsApp HTTP API" | A WhatsApp Web session for the bot number that you control with simple web requests. Sends the message. |

**Why no WhatsApp inside GHL?** GHL's own WhatsApp needs the official Business API (Meta approval,
templates, per-message fees) and connects a number *to GHL*. Here GHL only shouts "this happened" at a
URL. The sending is done by a separate bot number on your own server, so nobody's WhatsApp is
connected to GHL and there are no per-message costs.

## What a webhook is

A webhook is GHL sending a small parcel of data to a URL the moment something happens. The parcel
looks like this:

```json
{ "title": "Strategy Call Booked", "name": "Jane Doe", "booked_for": "Thu 10am" }
```

GHL fills in the `{{merge tags}}` with the real contact's details before sending.

## The n8n workflow, node by node

Open it in n8n and click each node while reading this.

1. **GHL Webhook** — the URL that listens (`/webhook/ghl-alert`). Everything starts here.
2. **Validate secret** — compares the secret GHL sent with `GHL_WEBHOOK_SECRET`. Wrong or missing →
   stops. This is what stops strangers from messaging through your bot.
3. **Format message** — builds the WhatsApp text:
   - `title` + `emoji` → the bold heading
   - every other key → a bold label with the value under it (`booked_for` → **Booked For**)
   - blank values are skipped
   - `message` → used as-is instead
   - `to` (or `WHATSAPP_TO`) → who receives it; commas = several people, one message each
4. **WAHA sendText** — calls WAHA's `/api/sendText` with the text and the recipient.
5. **Respond** — answers GHL with WAHA's real result. If WhatsApp failed, GHL sees a failure
   (not a fake "OK"), so you can spot it in GHL's workflow history.

Because the formatting is generic, **one n8n workflow serves every alert**. New alert = new GHL
workflow, nothing in n8n changes.

## Recipient formats

| You want | Put in `to` / `WHATSAPP_TO` |
|---|---|
| One person | `64211234567@c.us` or just `+64 21 123 4567` (converted automatically) |
| A WhatsApp group | `120363xxxxxxxxxxxx@g.us` — get it from `scripts/list-groups.sh` (the bot must be in the group) |
| Several | comma-separated: `64211111111, 120363xxxxxxxxxxxx@g.us` |

## Exercises (10 minutes each)

1. **Change the look.** In n8n open *Format message*, change the default emoji `🔔` to something
   else, publish, run `scripts/test-webhook.sh`. You just edited live code.
2. **New alert without n8n.** Build recipe 2 (new lead) in GHL. Submit your own form.
3. **Route by type.** Copy recipe 8 and send hot leads straight to a different person with `to`.
4. **Read an execution.** n8n → *Executions* → open the last one. Click each node to see the data
   going in and out. This is how you debug everything.

## Going further (n8n can do much more than forward)

Add nodes between *Format message* and *WAHA sendText*:

- **IF node** — only alert when e.g. revenue > X, otherwise stop
- **HTTP Request** — look something up first (GHL API, a spreadsheet) and add it to the message
- **Schedule Trigger** — instead of a webhook, run every morning and send a daily summary
- **WAHA can do more:** send images (`/api/sendImage`), files (`/api/sendFile`), create groups.
  Full list at `http://localhost:3000/` on the server (open an SSH tunnel:
  `ssh -L 3000:127.0.0.1:3000 ubuntu@YOUR_IP`, then browse to it).

## Ground rules

- The bot is for **internal alerts**: owners, staff, team groups. Don't use it to cold-message or
  bulk-message customers. WhatsApp bans numbers that do that, and WAHA is unofficial.
- Keep `.env` private. Anyone with `GHL_WEBHOOK_SECRET` can message through your bot.
- When alerts stop, the fix is almost always: update WAHA, then re-scan the QR if asked
  (see "Keeping it healthy" in the main README).
