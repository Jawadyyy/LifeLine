# LifeLine Push Relay

Free serverless relay that sends FCM push notifications for LifeLine.

**Why it exists:** FCM HTTP v1 needs a Firebase *service-account* credential to
send. That secret must stay server-side — it can never ship in the app. This
relay holds it and exposes a single authenticated endpoint the app calls at
send-time. No Cloud Functions, no Blaze, no billing card required.

```
sender app ──(Firebase ID token)──▶ relay ──(service account)──▶ FCM ──▶ device
```

This directory is a **separate deployable**. It is NOT bundled into the Flutter
build. Deploy it once to Vercel; the app only ever knows the public relay URL.

## Endpoint

`POST /api/send`

```jsonc
// headers
Authorization: Bearer <Firebase ID token of the caller>
Content-Type: application/json

// body
{
  "recipientUid": "<uid to notify>",
  "kind": "emergency" | "safe" | "donation_accept",
  "chatId": "<sorted(callerUid,recipientUid)>",   // required for emergency/safe
  "payload": {
    "senderName": "Ali",
    "senderUid": "<callerUid>",
    "sessionId": "<live location session id>",     // optional
    "route": "chat"                                 // optional deep-link hint
  }
}

// 200 response
{ "sent": 1, "failed": 0 }
```

### What it does
1. **AuthN** — verifies the `Authorization: Bearer` Firebase ID token
   (`admin.auth().verifyIdToken`). Invalid → `401`.
2. **AuthZ** —
   - `emergency` / `safe`: the caller must be a participant of `chatId`
     (`chatId == sorted(callerUid, recipientUid).join('_')`).
   - `donation_accept`: the caller must be the post owner, or a donor who
     accepted one of `recipientUid`'s donation posts.
   - otherwise → `403`.
3. Reads `users/{recipientUid}.fcmTokens` (array) via admin Firestore.
4. Sends with `sendEachForMulticast` (notification + data payload).
5. Prunes tokens that come back `registration-token-not-registered`.
6. Basic in-memory per-uid rate limit (20/min).

## Deploy (Vercel — free, no card)

1. Create a free Vercel account: <https://vercel.com/signup>.
2. Install the CLI and deploy from this directory:
   ```bash
   cd relay
   npm install
   npm i -g vercel
   vercel            # first run links/creates the project
   vercel --prod     # production deploy → prints your relay URL
   ```
   (Or push this folder to a Git repo and import it in the Vercel dashboard with
   **Root Directory = `relay`**.)
3. The deployed endpoint is `https://<your-project>.vercel.app/api/send`.
   Put `https://<your-project>.vercel.app` (no `/api/send`) — see note below — in
   the Flutter app's `.env` as `PUSH_RELAY_URL`. The app appends `/api/send`.

## Required environment variables (set in Vercel, NEVER commit)

Vercel → Project → Settings → Environment Variables. Provide **either** the full
JSON blob **or** the three discrete fields:

| Variable | Notes |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | Entire service-account JSON, single line. Easiest. |
| — or — | |
| `FIREBASE_PROJECT_ID` | e.g. `lifelinev2-7cad5` |
| `FIREBASE_CLIENT_EMAIL` | from the service-account JSON |
| `FIREBASE_PRIVATE_KEY` | from the JSON; keep the literal `\n` escapes |

### Getting the service account
Firebase Console → Project settings → **Service accounts** → *Generate new
private key*. This downloads a JSON file. Paste its contents into
`FIREBASE_SERVICE_ACCOUNT` (or split into the three fields). **Do not commit it.**

### Enable the API
Google Cloud Console (same project) → enable **Firebase Cloud Messaging API
(V1)**.

## Local test
```bash
vercel dev
curl -X POST http://localhost:3000/api/send \
  -H "Authorization: Bearer <a real Firebase ID token>" \
  -H "Content-Type: application/json" \
  -d '{"recipientUid":"<uid>","kind":"emergency","chatId":"<sorted ids>","payload":{"senderName":"Test"}}'
```
