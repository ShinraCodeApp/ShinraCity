import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const messaging = admin.messaging();

// On new commerce registration — notify admins
export const onCommerceCreated = functions.firestore
  .document('commerces/{commerceId}')
  .onCreate(async (snap) => {
    const commerce = snap.data();
    const commerceId = snap.id;

    // Notify all admins
    const adminsSnap = await db
      .collection('users')
      .where('role', 'in', ['admin', 'superAdmin'])
      .get();

    const tokens: string[] = [];
    adminsSnap.docs.forEach((doc) => {
      const t = doc.data().fcmTokens || [];
      tokens.push(...t);
    });

    if (tokens.length > 0) {
      await messaging.sendEachForMulticast({
        tokens: tokens.slice(0, 500),
        notification: {
          title: '🏪 Nuevo comercio pendiente',
          body: `"${commerce.name}" requiere verificación`,
        },
        data: {
          type: 'new_commerce_pending',
          commerceId,
          screen: '/admin/commerces',
        },
        android: { priority: 'normal' },
      });
    }
  });

// When a commerce gets verified — notify owner and followers
export const onCommerceVerified = functions.firestore
  .document('commerces/{commerceId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const commerceId = context.params.commerceId;

    // Status changed from pending to active = just got verified
    if (before.status !== 'active' && after.status === 'active') {
      await notifyOwnerVerified(after.ownerId, commerceId, after.name);
    }

    // Status suspended
    if (before.status !== 'suspended' && after.status === 'suspended') {
      await notifyOwnerSuspended(after.ownerId, after.name, after.suspensionReason);
    }
  });

async function notifyOwnerVerified(
  ownerId: string,
  commerceId: string,
  commerceName: string
) {
  const ownerDoc = await db.collection('users').doc(ownerId).get();
  const tokens: string[] = ownerDoc.data()?.fcmTokens || [];

  if (tokens.length > 0) {
    await messaging.sendEachForMulticast({
      tokens: tokens.slice(0, 500),
      notification: {
        title: '✅ ¡Negocio verificado!',
        body: `"${commerceName}" ya está activo en ShinraCity`,
      },
      data: {
        type: 'commerce_verified',
        commerceId,
        screen: `/commerce/${commerceId}`,
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  }
}

async function notifyOwnerSuspended(
  ownerId: string,
  commerceName: string,
  reason?: string
) {
  const ownerDoc = await db.collection('users').doc(ownerId).get();
  const tokens: string[] = ownerDoc.data()?.fcmTokens || [];

  if (tokens.length > 0) {
    await messaging.sendEachForMulticast({
      tokens: tokens.slice(0, 500),
      notification: {
        title: '⚠️ Negocio suspendido',
        body: `"${commerceName}" ha sido suspendido temporalmente. ${reason || ''}`,
      },
      data: {
        type: 'commerce_suspended',
        screen: '/business/dashboard',
      },
      android: { priority: 'high' },
    });
  }
}

// Plan expiration check — runs daily
export const checkExpiredPlans = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const expired = await db
      .collection('commerces')
      .where('plan', '!=', 'free')
      .where('planExpiresAt', '<', now)
      .limit(50)
      .get();

    if (expired.empty) return;

    const batch = db.batch();
    for (const doc of expired.docs) {
      const commerce = doc.data();
      batch.update(doc.ref, {
        plan: 'free',
        planExpiresAt: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify owner
      const ownerId: string = commerce.ownerId;
      const ownerDoc = await db.collection('users').doc(ownerId).get();
      const tokens: string[] = ownerDoc.data()?.fcmTokens || [];
      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens: tokens.slice(0, 500),
          notification: {
            title: '📋 Plan expirado',
            body: `El plan de "${commerce.name}" expiró. Renovalo para mantener tus beneficios.`,
          },
          data: {
            type: 'plan_expired',
            commerceId: doc.id,
            screen: '/business/plans',
          },
        });
      }
    }

    await batch.commit();
  });

// Aggregate commerce stats — runs every hour
export const aggregateCommerceStats = functions.pubsub
  .schedule('0 * * * *')
  .onRun(async () => {
    const oneDayAgo = new Date();
    oneDayAgo.setDate(oneDayAgo.getDate() - 1);

    // Get most active commerces (had redemptions in last 24h)
    const recentCoupons = await db
      .collection('coupons')
      .where('status', '==', 'used')
      .where('redeemedAt', '>=', admin.firestore.Timestamp.fromDate(oneDayAgo))
      .get();

    // Aggregate by commerce
    const stats: Record<string, number> = {};
    recentCoupons.docs.forEach((doc) => {
      const cid = doc.data().commerceId;
      stats[cid] = (stats[cid] || 0) + 1;
    });

    // Update commerce stats
    const batch = db.batch();
    for (const [cid, count] of Object.entries(stats)) {
      batch.update(db.collection('commerces').doc(cid), {
        last24hRedemptions: count,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  });

// Update follower count when user follows/unfollows
export const onFollowChange = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    const beforeFollowing: string[] = before.followingCommerceIds || [];
    const afterFollowing: string[] = after.followingCommerceIds || [];

    // Find added followers
    const added = afterFollowing.filter((id) => !beforeFollowing.includes(id));
    const removed = beforeFollowing.filter((id) => !afterFollowing.includes(id));

    const batch = db.batch();
    for (const cid of added) {
      batch.update(db.collection('commerces').doc(cid), {
        followerCount: admin.firestore.FieldValue.increment(1),
      });
    }
    for (const cid of removed) {
      batch.update(db.collection('commerces').doc(cid), {
        followerCount: admin.firestore.FieldValue.increment(-1),
      });
    }

    if (added.length > 0 || removed.length > 0) {
      await batch.commit();
    }
  });

// Get commerce analytics for dashboard (callable)
export const getCommerceAnalytics = functions.https.onCall(
  async (data: { commerceId: string; period: 'day' | 'week' | 'month' }, context) => {
    const { commerceId, period = 'week' } = data;

    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Autenticación requerida');
    }

    const commerceDoc = await db.collection('commerces').doc(commerceId).get();
    if (!commerceDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Comercio no encontrado');
    }

    const commerce = commerceDoc.data()!;
    if (commerce.ownerId !== context.auth.uid) {
      // Check if user is admin
      const userDoc = await db.collection('users').doc(context.auth.uid).get();
      const role = userDoc.data()?.role;
      if (!['admin', 'superAdmin'].includes(role)) {
        throw new functions.https.HttpsError('permission-denied', 'Sin permisos');
      }
    }

    const periodDays = { day: 1, week: 7, month: 30 }[period];
    const since = new Date();
    since.setDate(since.getDate() - periodDays);
    const sinceTs = admin.firestore.Timestamp.fromDate(since);

    // Coupons
    const coupons = await db
      .collection('coupons')
      .where('commerceId', '==', commerceId)
      .where('createdAt', '>=', sinceTs)
      .get();

    const redeemed = coupons.docs.filter((d) => d.data().status === 'used').length;
    const claimed = coupons.docs.length;

    // Points given
    const pointsTx = await db
      .collection('points_transactions')
      .where('commerceId', '==', commerceId)
      .where('createdAt', '>=', sinceTs)
      .get();

    const totalPoints = pointsTx.docs.reduce(
      (sum, doc) => sum + (doc.data().points || 0), 0
    );

    // Active promotions
    const activePromos = await db
      .collection('promotions')
      .where('commerceId', '==', commerceId)
      .where('status', '==', 'active')
      .get();

    return {
      period,
      claimed,
      redeemed,
      conversionRate: claimed > 0 ? Math.round((redeemed / claimed) * 100) : 0,
      totalPointsGiven: totalPoints,
      activePromotions: activePromos.size,
      followerCount: commerce.followerCount || 0,
      totalRedemptions: commerce.totalRedemptions || 0,
    };
  }
);
