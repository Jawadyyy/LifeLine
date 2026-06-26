# LifeLine — Roadmap & Coding Tasks

Executable spec for Claude Code. Do tasks top-down. After each task: `flutter analyze` stays clean.
Lines in _italics_ are manual inputs the human supplies (values/console actions) — agent stops and asks if missing.

---

## ✅ DONE (publish prep)
- T1 package id → `com.lifeline.app`
- T2 release signing → upload keystore + `key.properties` (gitignored), AAB signs
- T3 `.env` → keys moved out of source, wired via dotenv
- T4 Firestore rules → written + deployed to `lifelinev2-7cad5`

## ✅ DONE (features / improvements)
- B2 SOS → in-app chat: `ChatMessage`/`ChatService` carry `type` ('text'/'emergency'); `getEmergencyContactsDetailed` returns uid; `home_controller.sendEmergencyMessage` writes location alert into each contact's Firestore chat; legacy no-uid contacts skipped+reported; recipient sees red pinned `_EmergencyBubble` w/ "Open in Maps". All WhatsApp/SMS SOS code removed.
- B3 Gemini chatbot: `GeminiService` (medical system prompt + disclaimer), `ChatHomeScreen` real chat. _Needs `GEMINI_KEY` in `.env`._
- I1 direct dial 1122 (home card + bottom-sheet tile)
- I2 cancellable 5s countdown before SOS fires
- I3 Crashlytics + Analytics (init in `main.dart`)
- I4 `as dynamic` reflection → typed `MapScreenView`/`ContactsScreenView` interfaces; zero reflection left
- I5 first-run permission priming screen
- Manifest: `tel:`/`https` query intents added (Android 11+), dead WhatsApp query removed

- Code state: `flutter analyze` 0 issues · `flutter test` passes · `flutter build appbundle --release` → 30.9MB AAB ✅

> Note: `wa.me` still used in the **donation** feature (`contactViaWhatsApp`) to reach a blood donor — intentional, separate from SOS. Leave it.

---

# 🔴 BLOCKERS — fix before release

## B1 — Google Sign-In broken
Cause: package changed to `com.lifeline.app`, but the signing keys' SHA-1 fingerprints are not
registered in Firebase for that package. Sign-In silently fails.

Code looks fine (`lib/services/auth_service.dart` uses `GoogleSignIn().signIn()` v6 API). This is a
**console config fix**, not code — unless steps below still fail, then revisit code.

- _Human: Firebase Console → project `lifelinev2-7cad5` → Project settings → app `com.lifeline.app` → **Add fingerprint**, add ALL of these:_
  - **Debug** (for `flutter run` testing) SHA-1: `9A:26:20:66:0D:0B:5A:5C:40:63:0E:E7:1B:40:46:13:95:1A:E4:2E`
  - **Debug** SHA-256: `CE:12:69:23:E0:6C:12:D9:50:6B:9A:6E:65:C4:E5:80:F1:1A:28:87:DE:D6:69:32:F1:49:05:0A:4A:52:26:46`
  - **Upload** SHA-1: `BB:F1:BD:3B:7A:3D:D7:7D:9B:C8:19:98:FE:34:BC:00:6F:A2:1D:3E`
  - **Upload** SHA-256: `9E:8D:DB:8E:3C:F7:07:E7:0E:8A:D1:1E:BB:26:6D:7C:2D:76:0C:EC:38:8A:56:7D:2D:F6:0E:61:EC:17:25:91`
  - **(After 1st Play upload)** Play App Signing SHA-1 from Play Console → Setup → App signing
- _Human: re-download `google-services.json` after adding fingerprints → replace `android/app/google-services.json`._
- _Human: enable Google as a sign-in provider: Firebase → Authentication → Sign-in method → Google → Enabled._
- Verify: `flutter run` (debug) → tap Google Sign-In → completes. **Done when** sign-in returns a user.

## ✅ B2 — SOS via in-app chat (DONE — spec kept for reference)
Old logic in `lib/views/main/home/controller/home_controller.dart` (`sendEmergencyMessage`) still opens
WhatsApp via `wa.me` deep links (`url_launcher`). Requirement: emergency location goes into the **in-app
chat** (the Firestore chat from T5), NOT WhatsApp/SMS.

- Rewrite `sendEmergencyMessage(emergencyType)`:
  - Get current GPS via `LocationHandler.getCurrentPosition()`
  - Build emergency text: type + username + Google Maps link `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>` + timestamp + user's custom `emergency_text`
  - For each saved emergency contact, resolve `chatId = sorted(currentUid, contactUid)` and **write the emergency message into that Firestore chat** (`ChatService.send`), so it appears in-app for the recipient
  - Mark the message as an emergency (add field `type: 'emergency'` on the message doc so the chat UI can render it red/pinned)
- Remove all WhatsApp/`wa.me`/`launch()` SOS code; drop `url_launcher` import here if now unused
- Recipient side: in `chat_screen.dart` / `chat_widgets.dart`, render `type == 'emergency'` messages distinctly (red bubble + tappable map link)
- Edge cases: contact has no `uid` yet (legacy) → skip + collect; no location permission → show error; no contacts → prompt to add
- **Done when** firing SOS posts the location message into each emergency contact's chat thread, visible in-app realtime; no WhatsApp/SMS path remains.

## ✅ B3 — Chatbot (DONE — built real Gemini chat; spec kept for reference)
`lib/views/chatbot/screens/chat_home_screen.dart` is a "Coming Soon" stub, reachable via the brain FAB on
home (`home_screen.dart`). Don't ship a dead screen.

Pick ONE:
- **Hide:** remove the FAB from `home_screen.dart` + the import; leave the stub file unused
- **Build (preferred, dep already present):** implement real Gemini chat with `google_generative_ai`
  - Key from `.env` (`GEMINI_KEY`); add to `.env.example` + `.env` + read via `dotenv.env['GEMINI_KEY']`
  - System prompt: medical assistant; **must include a "not a substitute for professional medical advice / call emergency services" disclaimer** in UI
  - Message list + input + loading state; reuse `chat_widgets.dart` styling
- **Done when** the brain FAB leads to a working feature or is gone (no "Coming Soon").

---

# ✅ HIGH-PRIORITY IMPROVEMENTS (I1–I5 ALL DONE — specs kept for reference)

## I1 — One-tap direct dial
Separate from chat SOS: a button that calls emergency services directly.
- Add a "Call Ambulance / 1122" button (configurable number; default `1122` for PK) using `url_launcher` `tel:`
- Place on home + emergency bottom sheet
- **Done when** one tap opens the dialer with the number prefilled

## I2 — Countdown / cancellable SOS
- When SOS fired, show a 5s countdown overlay with **Cancel**; only send after countdown
- Prevents accidental triggers
- **Done when** SOS can be aborted within the window

## I3 — Crashlytics
- Add `firebase_crashlytics`, init in `main.dart`, route Flutter errors to it
- (gradle already pulls `firebase-analytics`; analytics currently unused — wire basic events too)
- **Done when** a forced test crash appears in Firebase console

## I4 — Refactor the `dynamic` state hack
Controllers use `(state as dynamic).getField/setField` string reflection (home, map, profile). Fragile.
- Migrate to `provider` (already a dep) or `ChangeNotifier` controllers exposing typed state
- Start with `home_controller` + `map_screen_controller`
- **Done when** no `as dynamic` field access remains; analyze clean; screens behave identically

## I5 — Permission priming screen
- Before OS prompts for location/contacts, show a short rationale screen explaining why
- Reduces denials (and Play flags sensitive perms)
- **Done when** first-run flow explains perms before requesting

---

# 🟢 FEATURE IDEAS (backlog, post-launch)

- **F1 Live location share** — tracking link that updates over time, not a one-time pin (background location + foreground service; needs Play sensitive-perm declaration)
- **F2 Medical ID card** — blood group + allergies + emergency contact viewable on lock screen / quick-access without unlock
- **F3 Urdu + multi-language** — `flutter_localizations` + ARB files; target PK (1122, Urdu)
- **F4 Offline mode** — cache hospitals (already cached 24h) + contacts; re-enable Firestore offline persistence (currently `persistenceEnabled: false` in `main.dart`); emergencies happen on bad signal
- **F5 "I'm safe" follow-up** — after SOS, one-tap "I'm safe now" message to the same chats
- **F6 Donation upgrades** — blood-group filter, in-app request→accept flow, push notifications (FCM) when a nearby match posts

---

# 📋 MANUAL CONSOLE ITEMS (can't automate, before/after upload)
1. Add SHA fingerprints in Firebase (see B1) + re-download `google-services.json`
2. After 1st Play upload: add Play App Signing SHA-1 to Firebase (else Sign-In breaks for Play installs)
3. Restrict API keys (Geoapify + Firebase) to `com.lifeline.app` + SHA; consider rotating (keys are in git history + ship in APK)
4. Privacy policy URL + Play Data Safety form (location, contacts, health data) — Play blocks submission without
5. Store listing: 512×512 icon, 1024×500 feature graphic, ≥2 screenshots, descriptions, content rating

---

# Final gate
- [x] `flutter analyze` clean · `flutter test` passes
- [x] SOS posts location into in-app chat (B2)
- [x] Chatbot finished (B3) — needs `GEMINI_KEY` value
- [x] `flutter build appbundle --release` succeeds (30.9MB)
- [ ] **B1: Google Sign-In works on real device** (add debug SHA in Firebase + enable provider)
- [ ] `GEMINI_KEY` filled in `.env`
- [ ] Manual console items (privacy policy, Data Safety, key restrict, Play signing SHA)
