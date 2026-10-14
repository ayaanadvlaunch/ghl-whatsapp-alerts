# Recipes

Each recipe = **one GHL workflow** (trigger + one webhook action) pointing at the **same** n8n URL:

```
https://YOUR-HOSTNAME.nip.io/webhook/ghl-alert
```

You never touch n8n again after setup. A new alert is just a new GHL workflow with a different body.

**How to use a recipe**

1. GHL → Automation → Workflows → Create → Start from scratch
2. Add the **trigger** listed below (with its filter)
3. Add a **Custom Webhook** action: method `POST`, the URL above, header `X-GHL-Secret` = your secret,
   body type JSON, and paste the **body**
4. Replace anything in `<angle brackets>` using the **`{}` tag picker** next to the field.
   Tag names differ slightly between GHL accounts, so picking beats typing.
5. Save → Publish → trigger it once with a test contact

Using the plain **Webhook** action instead? Put each body line in **Custom Data** as key → value
(`title` → `Strategy Call Booked`, …) plus `secret` → your secret. Name/email/phone come automatically.

Body rules (full details in [../docs/HOW-IT-WORKS.md](../docs/HOW-IT-WORKS.md)):
- `title`, `emoji`, `to` are special. **Every other key becomes a line** in the message.
- Key names become labels: `booked_for` → **Booked For**.
- Leave `to` out to use `WHATSAPP_TO` from `.env`. Add it to send this alert somewhere else.
  Several recipients: `"to": "64211111111, 64222222222, 120363...@g.us"`.

---

## 1. Call booked

**Trigger:** Customer Booked Appointment → filter *Calendar* = your strategy-call calendar

```json
{
  "title": "Strategy Call Booked",
  "emoji": "📅",
  "name": "{{contact.name}}",
  "email": "{{contact.email}}",
  "phone": "{{contact.phone}}",
  "booked_for": "{{appointment.start_time}}",
  "with": "Angie"
}
```

## 2. New lead (form submitted)

**Trigger:** Form Submitted → filter *Form* = the form you care about

```json
{
  "title": "New Lead",
  "emoji": "🟢",
  "name": "{{contact.name}}",
  "email": "{{contact.email}}",
  "phone": "{{contact.phone}}",
  "source": "{{contact.source}}",
  "<any form question>": "<pick that custom field from {}>"
}
```

## 3. Survey / quiz completed

**Trigger:** Survey Submitted → filter *Survey* = yours

```json
{
  "title": "Quiz Completed",
  "emoji": "📝",
  "name": "{{contact.name}}",
  "phone": "{{contact.phone}}",
  "score": "<pick the score field>",
  "answers": "<pick the answer fields>"
}
```

## 4. Appointment cancelled or no-show

**Trigger:** Appointment Status → filter *Status* = Cancelled (make a second workflow for No Show)

```json
{
  "title": "Call Cancelled",
  "emoji": "❌",
  "name": "{{contact.name}}",
  "phone": "{{contact.phone}}",
  "was_booked_for": "{{appointment.start_time}}"
}
```

## 5. Deal won (pipeline stage changed)

**Trigger:** Pipeline Stage Changed → filter *Pipeline* = Sales, *Stage* = Won

```json
{
  "title": "Deal Won",
  "emoji": "💰",
  "name": "{{contact.name}}",
  "deal": "{{opportunity.name}}",
  "value": "{{opportunity.monetary_value}}"
}
```

## 6. Payment received

**Trigger:** Payment Received (or Order Submitted, depending on how you sell)

```json
{
  "title": "Payment Received",
  "emoji": "💳",
  "name": "{{contact.name}}",
  "amount": "<pick Payment → Amount>",
  "product": "<pick Payment → Product name>"
}
```

## 7. Lead replied

**Trigger:** Customer Replied → filter *Channel* = SMS / Email / etc.

```json
{
  "title": "Lead Replied",
  "emoji": "💬",
  "name": "{{contact.name}}",
  "phone": "{{contact.phone}}",
  "reply": "{{message.body}}"
}
```

> Use `reply`, not `message`: `message` is a special key that replaces the whole alert.

## 8. Hot lead (tag added)

**Trigger:** Contact Tag → filter *Tag added* = `hot-lead`

```json
{
  "title": "Hot Lead",
  "emoji": "🔥",
  "name": "{{contact.name}}",
  "phone": "{{contact.phone}}",
  "to": "<the closer's WhatsApp number>"
}
```

## 9. Plain text, your own words

Any trigger. Skip the layout and write the message yourself:

```json
{
  "message": "Heads up: {{contact.first_name}} just booked for {{appointment.start_time}}. Call them before the meeting."
}
```

---

**Make your own:** pick any GHL trigger, copy the body of the closest recipe, change the `title`,
`emoji` and lines. That's it. Test it without GHL by saving the body to a file
(with real values instead of `{{tags}}`) and running `bash scripts/test-webhook.sh my-body.json`.
