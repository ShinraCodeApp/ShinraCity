const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

// Uses Application Default Credentials (firebase CLI login)
initializeApp({ projectId: 'shinra-city' });

const auth = getAuth();
const db = getFirestore();

async function createAdmin() {
  const email = 'admin@shinracity.com';
  const password = 'Adminshinra132';

  // Create auth user
  let user;
  try {
    user = await auth.createUser({ email, password, displayName: 'Admin ShinraCity', emailVerified: true });
    console.log('Auth user created:', user.uid);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      user = await auth.getUserByEmail(email);
      console.log('Auth user already exists:', user.uid);
    } else {
      throw e;
    }
  }

  // Set custom claims
  await auth.setCustomUserClaims(user.uid, { role: 'admin', superAdmin: true });
  console.log('Custom claims set');

  // Create Firestore document
  await db.collection('users').doc(user.uid).set({
    id: user.uid,
    email,
    displayName: 'Admin ShinraCity',
    role: 'admin',
    level: 'lifetime',
    totalPoints: 0,
    availablePoints: 0,
    totalCouponsRedeemed: 0,
    totalSavings: 0,
    favoriteCommerceIds: [],
    followingCategories: [],
    followingCommerceIds: [],
    badgeIds: [],
    achievementIds: [],
    isActive: true,
    isVerified: true,
    notificationsEnabled: true,
    locationEnabled: true,
    authProvider: 'email',
    createdAt: new Date(),
  }, { merge: true });

  console.log('Firestore document created');
  console.log('Done! Admin account ready: admin@shinracity.com');
}

createAdmin().catch(console.error).finally(() => process.exit());
