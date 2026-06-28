process.env.GCLOUD_PROJECT = 'shinra-city';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'shinra-city' });

const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'shinra-city',
});

async function main() {
  const email = 'admin@shinracity.com';
  const uid = '4u3QnWkNprVeKk9aKEEETj6Qd2i2';

  // Set role in Firestore bypassing rules (admin SDK)
  const db = admin.firestore();
  await db.collection('users').doc(uid).set({
    id: uid,
    email: email,
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
  console.log('Firestore document set');

  // Set custom claims
  await admin.auth().setCustomUserClaims(uid, { role: 'admin', superAdmin: true });
  console.log('Custom claims set');
  console.log('Admin account ready!');
}

main().catch(console.error).finally(() => process.exit());
