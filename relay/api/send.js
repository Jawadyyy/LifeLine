// LifeLine push relay — Vercel serverless function (Node 18+, free tier).
//
// Flow: sender app -> THIS relay -> FCM HTTP v1 -> recipient device.
// The relay is the ONLY place the Firebase service-account credential lives;
// the Flutter app never holds it. The app authenticates each call with the
// caller's Firebase ID token (Authorization: Bearer <token>).
//
// POST /api/send
//   body: { recipientUid, kind, chatId?, payload }
//   kind: 'emergency' | 'safe' | 'donation_accept'
//   -> { sent, failed }

import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

// ---- Admin SDK init (once per warm instance) -------------------------------

function serviceAccountFromEnv() {
  // Preferred: full JSON blob in FIREBASE_SERVICE_ACCOUNT.
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  }
  // Or the three discrete fields (private key may carry literal "\n").
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n');
  if (projectId && clientEmail && privateKey) {
    return { projectId, clientEmail, privateKey };
  }
  throw new Error(
    'Missing service account: set FIREBASE_SERVICE_ACCOUNT, or ' +
      'FIREBASE_PROJECT_ID + FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY.',
  );
}

function ensureApp() {
  if (getApps().length === 0) {
    initializeApp({ credential: cert(serviceAccountFromEnv()) });
  }
}

// ---- Basic per-uid rate limit (in-memory; best-effort across warm instance) -

const RATE_MAX = 20; // max calls
const RATE_WINDOW_MS = 60_000; // per minute
const _hits = new Map(); // uid -> number[] (timestamps)

function rateLimited(uid) {
  const now = Date.now();
  const arr = (_hits.get(uid) || []).filter((t) => now - t < RATE_WINDOW_MS);
  arr.push(now);
  _hits.set(uid, arr);
  return arr.length > RATE_MAX;
}

// ---- AuthZ -----------------------------------------------------------------

function sortedChatId(a, b) {
  return [a, b].sort().join('_');
}

async function authorize({ db, callerUid, recipientUid, kind, chatId, payload }) {
  if (kind === 'emergency' || kind === 'safe') {
    // Membership is provable from the deterministic chat id alone.
    const expected = sortedChatId(callerUid, recipientUid);
    if (chatId && chatId !== expected) return false;
    return true; // caller is, by construction, a participant of expected
  }
  if (kind === 'incoming_call') {
    // Direct user-to-user ring. The payload's callerUid must be the verified
    // caller so the recipient's app trusts the routing data it receives.
    return !payload || !payload.callerUid || payload.callerUid === callerUid;
  }
  if (kind === 'donation_accept') {
    // recipientUid is the post owner; caller must be the donor who accepted
    // one of the owner's posts (or the owner themselves).
    if (callerUid === recipientUid) return true;
    const snap = await db
      .collection('users')
      .doc(recipientUid)
      .collection('donation_posts')
      .where('acceptedBy', '==', callerUid)
      .limit(1)
      .get();
    return !snap.empty;
  }
  return false;
}

// ---- Notification copy per kind --------------------------------------------

function buildNotification(kind, payload) {
  const name = (payload && payload.senderName) || 'Someone';
  switch (kind) {
    case 'emergency':
      return {
        title: '🚨 Emergency alert from ' + name,
        body: 'Tap to view their location and respond.',
      };
    case 'safe':
      return {
        title: '✅ ' + name + ' is safe',
        body: 'The earlier emergency is resolved.',
      };
    case 'donation_accept':
      return {
        title: '🩸 Donation request accepted',
        body: name + ' offered to donate blood.',
      };
    case 'incoming_call':
      return {
        title: '📞 Incoming call',
        body: ((payload && payload.callerName) || 'Someone') + ' is calling you…',
      };
    default:
      return { title: 'LifeLine', body: 'You have a new notification.' };
  }
}

// data payload values MUST be strings for FCM.
function buildData(kind, chatId, payload) {
  const p = payload || {};
  const data = { type: kind };
  if (chatId) data.chatId = String(chatId);
  if (p.sessionId) data.sessionId = String(p.sessionId);
  if (p.senderUid) data.senderUid = String(p.senderUid);
  if (p.senderName) data.senderName = String(p.senderName);
  if (p.route) data.route = String(p.route);
  // incoming_call routing (PushService.routeFor reads these).
  if (p.callId) data.callId = String(p.callId);
  if (p.channelName) data.channelName = String(p.channelName);
  if (p.callerUid) data.callerUid = String(p.callerUid);
  if (p.callerName) data.callerName = String(p.callerName);
  return data;
}

// ---- Handler ---------------------------------------------------------------

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    ensureApp();
  } catch (e) {
    res.status(500).json({ error: 'Relay not configured: ' + e.message });
    return;
  }

  // 1. AuthN — verify the Firebase ID token.
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }

  let callerUid;
  try {
    const decoded = await getAuth().verifyIdToken(token);
    callerUid = decoded.uid;
  } catch (_) {
    res.status(401).json({ error: 'Invalid token' });
    return;
  }

  if (rateLimited(callerUid)) {
    res.status(429).json({ error: 'Rate limit exceeded' });
    return;
  }

  // Parse body (Vercel provides a parsed object for JSON requests).
  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  const { recipientUid, kind, chatId, payload } = body;

  if (!recipientUid || !kind) {
    res.status(400).json({ error: 'recipientUid and kind are required' });
    return;
  }

  const db = getFirestore();

  // 2. AuthZ — is the caller allowed to ping this recipient for this kind?
  const allowed = await authorize({ db, callerUid, recipientUid, kind, chatId, payload });
  if (!allowed) {
    res.status(403).json({ error: 'Not allowed to notify this recipient' });
    return;
  }

  // 3. Look up the recipient's device tokens.
  const userSnap = await db.collection('users').doc(recipientUid).get();
  const tokens = (userSnap.exists && userSnap.data().fcmTokens) || [];
  if (!Array.isArray(tokens) || tokens.length === 0) {
    res.status(200).json({ sent: 0, failed: 0 });
    return;
  }

  // 4. Send.
  const message = {
    notification: buildNotification(kind, payload),
    data: buildData(kind, chatId, payload),
    android: {
      priority: kind === 'emergency' || kind === 'incoming_call' ? 'high' : 'normal',
      // A ring is worthless once the caller gives up (30 s ring timeout).
      ...(kind === 'incoming_call' ? { ttl: 45_000 } : {}),
      notification: { channelId: 'lifeline_alerts' },
    },
    tokens,
  };

  const resp = await getMessaging().sendEachForMulticast(message);

  // 5. Prune dead tokens.
  const stale = [];
  resp.responses.forEach((r, i) => {
    if (
      !r.success &&
      r.error &&
      r.error.code === 'messaging/registration-token-not-registered'
    ) {
      stale.push(tokens[i]);
    }
  });
  if (stale.length > 0) {
    await db
      .collection('users')
      .doc(recipientUid)
      .update({ fcmTokens: FieldValue.arrayRemove(...stale) })
      .catch(() => {});
  }

  // 6. Report.
  res.status(200).json({ sent: resp.successCount, failed: resp.failureCount });
}
