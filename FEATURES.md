# LifeLine — Feature Pack (Firestore-only, free tier)

Seven features built on Auth + Cloud Firestore, no paid services. Cross-user
alerts use Firestore realtime listeners + in-app UI (no FCM yet — see Deferred).

Branch: `features/7-pack`. One commit per feature.

---

## 1. Live location tracking
Continuously-updating location share (not a single pin).

- **Collection** `live_locations/{sessionId}`: `ownerUid, lat, lng, updatedAt,
  expiresAt, active`.
- **Sender**: `LiveLocationService.startBroadcast` — geolocator foreground-service
  stream, writes every ~10s, auto-expires after 30 min, `stopBroadcast` ends it.
- **Recipient**: `LiveTrackingScreen` streams the session, moves the marker live,
  shows "last updated".
- **SOS hook**: firing SOS starts a session and threads `liveSessionId` into each
  emergency chat message → recipients tap **Follow live location** (in-app map).
- Home shows a **Sharing live location** banner with one-tap **STOP**.
- **Rules**: `live_locations` readable by any signed-in user (session id is an
  unguessable doc id), writable only by `ownerUid`.
- **Manifest**: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`.

## 2. Offline mode
- `main.dart`: Firestore `persistenceEnabled: true`, unlimited cache.
- Contacts, profile, chats readable offline (cached hospitals already cached 24h).
- Outgoing SOS/chat writes queue locally and auto-sync on reconnect; SOS uses
  bounded timeouts so offline can't stall it and reports "queued offline".
- Chat messages show a **sending** state (pending write) that flips to **sent**.

## 3. Medical ID card
- `MedicalIdCard` (presentational) + `MedicalIdScreen` (streams `users/{uid}`,
  loads oldest contact as primary). Blood type, allergies, conditions, vitals,
  emergency note, primary contact (+call). Missing fields render "Not set".
- Entry: home AppBar action + profile menu.
- Lock-screen / quick-settings tile: **deferred** to a platform-channel task.

## 4. "I'm safe" follow-up
- `SosFollowup` records alerted contacts after SOS; one-tap green **I'M SAFE**
  banner sends `type:'safe'` to the same chats. Distinct green bubble.

## 5. SOS delivery / seen receipts
- `ChatService.markDelivered`/`markSeen` advance incoming messages
  `sent → delivered → seen` (recipient listener-driven, no FCM).
- ChatProvider marks delivered on receipt; chat screen marks seen on open.
- Emergency bubble shows the sender a **Sent / Delivered / Seen** receipt.

## 6. Donation: compatibility filter + request→accept
- `BloodCompatibility` — ABO/Rh logic (O- universal donor, AB+ universal
  recipient). DonationController filter is compatibility-aware via a **Compatible**
  toggle (treats the selected group as the donor's own).
- `DonationService.acceptPost` — donor taps **I'll donate**; writes
  `acceptedBy/acceptedByName/acceptedAt/status='accepted'` (once).
- Requester notified **in-app** at the nav root via `watchAcceptedRequests`.
- **Rules**: a donor may write only the accept fields, set themselves once;
  otherwise owner-only.
- Refactor: shared logic extracted into `BloodCompatibility` + `DonationService`.
  Full split of the large donation screens (`donation_screen` 956,
  `donation_map_screen` ~1.6k, `donation_dialog_controller` ~1.3k) is **partial** —
  remaining UI extraction tracked as follow-up.

## 7. Urdu / multi-language
- `flutter_localizations` + `generate: true` + `l10n.yaml`; ARB `en` + `ur`.
- `LocaleController` persists the choice (`shared_preferences`); MaterialApp wired
  with locale + delegates. In-app switcher in profile (English / اردو).
- Home + Medical ID strings migrated as representative usage; **remaining screens
  to be migrated incrementally** against the existing ARB keys.

---

## New collections / fields
- `live_locations/{sessionId}` — new (Feature 1).
- `chats/.../messages/{id}` — new fields: `type` (`text|emergency|safe`),
  `liveSessionId`, status now `sent|delivered|seen`.
- `users/{uid}/donation_posts/{id}` — new fields: `acceptedBy`, `acceptedByName`,
  `acceptedAt`, `status` extended to include `accepted`.

## firestore.rules — MUST DEPLOY
Updated for `live_locations` and donation accept fields. Deploy:
```
firebase deploy --only firestore:rules --project lifelinev2-7cad5
```

## .env keys
`PUSH_RELAY_URL` (Feature 8 — public relay base URL, no secret). Existing:
`GEOAPIFY_KEY`, `IMGBB_KEY`, `GEMINI_KEY`.

## Manual / console actions (human)
1. **Deploy `firestore.rules`** (command above) — accept flow + live locations
   fail closed until then.
2. **Play Console — sensitive permissions**: declare background/foreground
   **location** use (Feature 1 live sharing) in the Data Safety + permissions
   declaration, with a usage video. App targets foreground-service location.
3. Firebase Sign-In SHAs / `google-services.json` (from prior publish prep) still
   required for Google Sign-In on release.
4. Medical ID lock-screen tile — needs native platform-channel work (deferred).
5. Verify offline behaviour on a real device (airplane mode → SOS queues → sends
   on reconnect).
6. **Push (Feature 8)** — see `relay/README.md`:
   a. Create a free Vercel account (no card) and deploy `relay/`.
   b. Firebase Console → Project settings → Service accounts → *Generate private
      key* → set the JSON as Vercel env vars (`FIREBASE_SERVICE_ACCOUNT` or the
      3 discrete fields). Never commit it.
   c. Google Cloud Console → enable **Firebase Cloud Messaging API (V1)**.
   d. Put the deployed relay base URL in `.env` as `PUSH_RELAY_URL` → rebuild.
   e. Test Android 13+ notification permission + a real push on a device.

## 8. FCM push notifications (no Blaze) — DONE
Cross-user push for SOS, "I'm safe", and donation accept — without Cloud
Functions or the Blaze plan.

- **Relay** (`relay/`): a free **Vercel** serverless function (`POST /api/send`)
  is the only thing holding the Firebase service-account credential. The app
  never sees it. Flow: `sender app → relay → FCM HTTP v1 → recipient device`.
  The relay verifies the caller's Firebase ID token (AuthN) and checks the
  caller may ping the recipient (AuthZ: chat participant for `emergency`/`safe`,
  donor/owner for `donation_accept`), looks up `users/{uid}.fcmTokens`, sends
  via `sendEachForMulticast`, prunes dead tokens, basic per-uid rate limit.
- **Client** (`lib/services/push_service.dart`): registers this device's FCM
  token on app-start (`arrayUnion`, multi-device + `onTokenRefresh` safe),
  removes it on logout (`arrayRemove`); foreground banner; background/terminated
  tap routing (`getInitialMessage` + `onMessageOpenedApp`). `notify(...)` calls
  the relay with the current user's ID token. Push is **best-effort** — the
  existing Firestore in-app path is unaffected if the relay is down/unset.
- **Triggers**: SOS fired (`emergency`), "I'm safe" (`safe`), donation accept
  (`donation_accept`).
- **Android**: default `lifeline_alerts` channel (created in `MainActivity`),
  monochrome notification icon, `POST_NOTIFICATIONS` (13+) requested in the
  priming flow.
- **.env**: new key `PUSH_RELAY_URL` (public relay base URL only — no secrets).
- **Setup**: deploy `relay/` to Vercel and set the service account as Vercel env
  vars — see `relay/README.md`. No `firestore.rules` change required
  (`users/{uid}.fcmTokens` is covered by the existing owner-write rule).

## Deferred
- Full string extraction for every screen (Feature 7) and full donation-screen
  refactor (Feature 6) — infrastructure is in place; remaining work is mechanical.

## Tests
`flutter test` — live location lifecycle/expiry, chat round-trip + types,
delivery/seen transitions, safe follow-up, medical-id render, blood
compatibility matrix, donation accept flow, localization en/ur.
