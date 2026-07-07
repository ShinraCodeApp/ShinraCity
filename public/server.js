const express = require('express');
const path    = require('path');
const admin   = require('firebase-admin');

const app = express();
app.use(express.json());
app.use(express.static(__dirname));

// Initialize Firebase Admin SDK
try {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var not set');
  const serviceAccount = JSON.parse(raw);
  // Railway can escape newlines in private_key — normalize them
  if (serviceAccount.private_key) {
    serviceAccount.private_key = serviceAccount.private_key.replace(/\\n/g, '\n');
  }
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'shinra-city',
  });
  console.log('Firebase Admin initialized OK');
} catch (e) {
  console.error('Firebase Admin init FAILED:', e.message);
}

async function verifyAdmin(req, res, next) {
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

// Change another user's password
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

// Delete user from Firebase Auth
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
