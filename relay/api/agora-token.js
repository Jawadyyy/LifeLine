// LifeLine Agora token endpoint — Vercel serverless function (Node 18+).
//
// The Agora project has a primary certificate enabled, so RTC joins require a
// server-generated token. This endpoint is the only place the certificate
// secret lives; the Flutter app never holds it.
//
// Auth mirrors /api/send: the caller proves identity with a Firebase ID token,
// and may only request tokens for call channels they participate in
// (channelName = `call_<uidA>_<uidB>` with the uids sorted, so membership is
// provable from the name itself).
//
// POST /api/agora-token
//   headers: Authorization: Bearer <firebase id token>
//   body: { channelName }
//   -> { token, appId, expiresAt }

import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import pkg from 'agora-token';
const { RtcTokenBuilder, RtcRole } = pkg;

const TOKEN_TTL_SECONDS = 60 * 60; // 1 hour — outlives any reasonable call

function serviceAccountFromEnv() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  }
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

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;
  if (!appId || !appCertificate) {
    res.status(500).json({
      error: 'Relay not configured: set AGORA_APP_ID and AGORA_APP_CERTIFICATE',
    });
    return;
  }

  try {
    ensureApp();
  } catch (e) {
    res.status(500).json({ error: 'Relay not configured: ' + e.message });
    return;
  }

  const authHeader = req.headers.authorization || '';
  const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  if (!idToken) {
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }

  let decoded;
  try {
    decoded = await getAuth().verifyIdToken(idToken);
  } catch {
    res.status(401).json({ error: 'Invalid token' });
    return;
  }

  const { channelName } = req.body || {};
  if (typeof channelName !== 'string' || channelName.length === 0) {
    res.status(400).json({ error: 'channelName is required' });
    return;
  }

  // call_<uidA>_<uidB> — the requester must be one of the two participants.
  const match = /^call_([^_]+)_([^_]+)$/.exec(channelName);
  if (!match || (match[1] !== decoded.uid && match[2] !== decoded.uid)) {
    res.status(403).json({ error: 'Not a participant of this channel' });
    return;
  }

  const expiresAt = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
  // uid 0 = token not bound to a specific numeric uid; both peers join with
  // uid 0 and Agora assigns each a session uid. Channel access is what the
  // token gates, and the participant check above gates the channel.
  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    0,
    RtcRole.PUBLISHER,
    expiresAt,
    expiresAt,
  );

  res.status(200).json({ token, appId, expiresAt });
}
