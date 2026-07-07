const express = require('express');
const path    = require('path');
const admin   = require('firebase-admin');

const app = express();
app.use(express.json());
app.use(express.static(__dirname));

// Initialize Firebase Admin SDK using individual env vars (more reliable on Railway)
function initFirebase() {
  // Option A: individual env vars (preferred)
  const clientEmail  = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey   = process.env.FIREBASE_PRIVATE_KEY;

  if (clientEmail && privateKey) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId:   'shinra-city',
        clientEmail,
        privateKey:  privateKey.replace(/\\n/g, '\n'),
      }),
    });
    console.log('Firebase Admin initialized via individual env vars');
    return;
  }

  // Option B: full JSON blob fallback
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (raw) {
    const sa = JSON.parse(raw);
    if (sa.private_key) sa.private_key = sa.private_key.replace(/\\n/g, '\n');
    admin.initializeApp({ credential: admin.credential.cert(sa), projectId: 'shinra-city' });
    console.log('Firebase Admin initialized via service account JSON');
    return;
  }

  throw new Error('No Firebase credentials found. Set FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY');
}

try {
  initFirebase();
} catch (e) {
  console.error('Firebase Admin init FAILED:', e.message);
}

async function verifyAdmin(req, res, next) {
  if (!admin.apps.length)
    return res.status(503).json({ error: 'Servidor no configurado. Contactá al desarrollador.' });
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Sin token' });
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const snap    = await admin.firestore().collection('users').doc(decoded.uid).get();
    const role    = snap.data()?.role || '';
    if (role !== 'admin' && role !== 'superAdmin')
      return res.status(403).json({ error: 'No autorizado' });
    req.adminUid = decoded.uid;
    next();
  } catch (e) {
    res.status(401).json({ error: e.message });
  }
}

app.post('/api/update-password', verifyAdmin, async (req, res) => {
  const { uid, password } = req.body;
  if (!uid || !password || password.length < 6)
    return res.status(400).json({ error: 'UID y contraseña de mínimo 6 caracteres requeridos' });
  try {
    await admin.auth().updateUser(uid, { password });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/delete-user', verifyAdmin, async (req, res) => {
  const { uid } = req.body;
  if (!uid) return res.status(400).json({ error: 'UID requerido' });
  try {
    await admin.auth().deleteUser(uid);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('*', (_req, res) => res.sendFile(path.join(__dirname, 'index.html')));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`ShinraCity Admin running on port ${PORT}`));
