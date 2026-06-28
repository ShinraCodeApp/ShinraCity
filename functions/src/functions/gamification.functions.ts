import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const messaging = admin.messaging();

async function saveToInbox(
  userId: string,
  title: string,
  body: string,
  type: string,
  payload: Record<string, string> = {}
): Promise<void> {
  await db.collection('users').doc(userId).collection('notifications').add({
    title,
    body,
    type,
    payload,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}


function calculateLevel(totalPoints: number): string {
  if (totalPoints >= 15000) return 'lifetime';
  if (totalPoints >= 5000) return 'ambassador';
  if (totalPoints >= 2000) return 'exemplary';
  if (totalPoints >= 500) return 'frequent';
  return 'explorer';
}

const ACHIEVEMENT_DEFINITIONS: Record<string, {
  title: string;
  description: string;
  pointsReward: number;
  condition: { type: string; value: number };
}> = {
  first_coupon: {
    title: 'Primer Cupón',
    description: 'Usaste tu primer cupón en ShinraCity',
    pointsReward: 50,
    condition: { type: 'coupons_redeemed', value: 1 },
  },
  ten_coupons: {
    title: 'Cliente Activo',
    description: 'Canjeaste 10 cupones',
    pointsReward: 100,
    condition: { type: 'coupons_redeemed', value: 10 },
  },
  fifty_coupons: {
    title: 'Experto Cazaofertas',
    description: 'Canjeaste 50 cupones',
    pointsReward: 250,
    condition: { type: 'coupons_redeemed', value: 50 },
  },
  hundred_coupons: {
    title: 'Leyenda del Ahorro',
    description: 'Canjeaste 100 cupones',
    pointsReward: 500,
    condition: { type: 'coupons_redeemed', value: 100 },
  },
  first_review: {
    title: 'Crítico',
    description: 'Escribiste tu primera reseña',
    pointsReward: 30,
    condition: { type: 'reviews_written', value: 1 },
  },
  explorer_badge: {
    title: 'Explorador',
    description: 'Visitaste 10 comercios diferentes',
    pointsReward: 100,
    condition: { type: 'commerces_visited', value: 10 },
  },
  referral_pro: {
    title: 'Embajador',
    description: 'Referiste a 5 amigos',
    pointsReward: 500,
    condition: { type: 'referrals', value: 5 },
  },
  level_frequent: {
    title: 'Frecuente',
    description: 'Alcanzaste el nivel Frecuente',
    pointsReward: 0,
    condition: { type: 'level', value: 500 },
  },
  level_exemplary: {
    title: 'Cliente Ejemplar',
    description: 'Alcanzaste el nivel Ejemplar',
    pointsReward: 100,
    condition: { type: 'level', value: 2000 },
  },
  level_ambassador: {
    title: 'Embajador ShinraCity',
    description: 'Alcanzaste el nivel Embajador',
    pointsReward: 300,
    condition: { type: 'level', value: 5000 },
  },
  level_lifetime: {
    title: 'Lifetime Partner',
    description: 'Alcanzaste el nivel máximo: Lifetime Partner',
    pointsReward: 1000,
    condition: { type: 'level', value: 15000 },
  },
};

export const onCouponRedeemedGamification = functions.firestore
  .document('coupons/{couponId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== 'used' && after.status === 'used') {
      const userId = after.userId as string;
      const couponId = change.after.id;

      await awardPoints({
        userId,
        points: 10,
        reason: 'Cupón canjeado',
        couponId,
        commerceId: after.commerceId,
        promotionId: after.promotionId,
      });

      await checkCouponAchievements(userId);
      await updateCommerceRedemptionStats(after.commerceId, after.promotionId);
    }
  });

async function awardPoints(params: {
  userId: string;
  points: number;
  reason: string;
  couponId?: string;
  commerceId?: string;
  promotionId?: string;
}) {
  await db.runTransaction(async (t) => {
    const userRef = db.collection('users').doc(params.userId);
    const userDoc = await t.get(userRef);
    const data = userDoc.data()!;

    const newTotal = (data.totalPoints || 0) + params.points;
    const newAvailable = (data.availablePoints || 0) + params.points;
    const oldLevel = data.level || 'explorer';
    const newLevel = calculateLevel(newTotal);
    const leveledUp = newLevel !== oldLevel;

    t.update(userRef, {
      totalPoints: newTotal,
      availablePoints: newAvailable,
      level: newLevel,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    t.set(db.collection('points_transactions').doc(), {
      userId: params.userId,
      points: params.points,
      type: 'earned',
      reason: params.reason,
      couponId: params.couponId || null,
      commerceId: params.commerceId || null,
      promotionId: params.promotionId || null,
      balanceAfter: newAvailable,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (leveledUp) {
      await sendLevelUpNotification(params.userId, newLevel, data.fcmTokens || []);
      await checkLevelAchievements(params.userId, newTotal);
    }
  });
}

async function checkCouponAchievements(userId: string) {
  const userDoc = await db.collection('users').doc(userId).get();
  const data = userDoc.data()!;
  const redeemedCount = data.totalCouponsRedeemed || 0;
  const achievementIds = data.achievementIds || [];

  const milestones: Record<number, string> = {
    1: 'first_coupon',
    10: 'ten_coupons',
    50: 'fifty_coupons',
    100: 'hundred_coupons',
  };

  for (const [threshold, achievementId] of Object.entries(milestones)) {
    if (redeemedCount >= Number(threshold) && !achievementIds.includes(achievementId)) {
      await unlockAchievement(userId, achievementId, data.fcmTokens || []);
    }
  }
}

async function checkLevelAchievements(userId: string, totalPoints: number) {
  const userDoc = await db.collection('users').doc(userId).get();
  const achievementIds = userDoc.data()?.achievementIds || [];

  const levelAchievements: Record<number, string> = {
    500: 'level_frequent',
    2000: 'level_exemplary',
    5000: 'level_ambassador',
    15000: 'level_lifetime',
  };

  for (const [threshold, achievementId] of Object.entries(levelAchievements)) {
    if (totalPoints >= Number(threshold) && !achievementIds.includes(achievementId)) {
      const tokens = userDoc.data()?.fcmTokens || [];
      await unlockAchievement(userId, achievementId, tokens);
    }
  }
}

async function unlockAchievement(
  userId: string,
  achievementId: string,
  fcmTokens: string[]
) {
  const definition = ACHIEVEMENT_DEFINITIONS[achievementId];
  if (!definition) return;

  await db.collection('users').doc(userId).update({
    achievementIds: admin.firestore.FieldValue.arrayUnion(achievementId),
  });

  // Award achievement bonus points if applicable
  if (definition.pointsReward > 0) {
    await awardPoints({
      userId,
      points: definition.pointsReward,
      reason: `Logro desbloqueado: ${definition.title}`,
    });
  }

  const achTitle = '🏆 ¡Logro desbloqueado!';
  const achBody = definition.title;
  if (fcmTokens.length > 0) {
    await messaging.sendEachForMulticast({
      tokens: fcmTokens.slice(0, 500),
      notification: { title: achTitle, body: achBody },
      data: { type: 'achievement_unlocked', achievementId, title: definition.title },
      android: { priority: 'normal' },
      apns: { payload: { aps: { badge: 1 } } },
    });
  }
  await saveToInbox(userId, achTitle, achBody, 'achievement_unlocked', { achievementId });
}

async function sendLevelUpNotification(
  userId: string,
  newLevel: string,
  fcmTokens: string[]
) {
  const levelNames: Record<string, string> = {
    frequent: 'Frecuente',
    exemplary: 'Ejemplar',
    ambassador: 'Embajador',
    lifetime: 'Lifetime Partner',
  };

  const lvlTitle = '⬆️ ¡Subiste de nivel!';
  const lvlBody = `Ahora sos ${levelNames[newLevel] || newLevel} en ShinraCity`;
  if (fcmTokens.length > 0) {
    await messaging.sendEachForMulticast({
      tokens: fcmTokens.slice(0, 500),
      notification: { title: lvlTitle, body: lvlBody },
      data: { type: 'level_up', newLevel, screen: '/rewards' },
      android: { priority: 'high' },
      apns: { payload: { aps: { badge: 1, sound: 'default' } } },
    });
  }
  await saveToInbox(userId, lvlTitle, lvlBody, 'level_up', { newLevel });
}

async function updateCommerceRedemptionStats(
  commerceId: string,
  promotionId: string
) {
  const batch = db.batch();

  batch.update(db.collection('commerces').doc(commerceId), {
    totalRedemptions: admin.firestore.FieldValue.increment(1),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.update(db.collection('promotions').doc(promotionId), {
    claimCount: admin.firestore.FieldValue.increment(1),
  });

  await batch.commit();
}

export const checkAchievementsOnAction = functions.https.onCall(
  async (data: { userId: string; actionType: string; value: number }) => {
    const { userId, actionType, value } = data;

    if (!userId || !actionType) {
      throw new functions.https.HttpsError('invalid-argument', 'Parámetros requeridos faltantes');
    }

    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Usuario no encontrado');
    }

    const userData = userDoc.data()!;
    const achievementIds: string[] = userData.achievementIds || [];
    const fcmTokens: string[] = userData.fcmTokens || [];
    const unlocked: string[] = [];

    for (const [id, def] of Object.entries(ACHIEVEMENT_DEFINITIONS)) {
      if (achievementIds.includes(id)) continue;
      if (def.condition.type === actionType && value >= def.condition.value) {
        await unlockAchievement(userId, id, fcmTokens);
        unlocked.push(id);
      }
    }

    return { unlocked };
  }
);

// Daily leaderboard snapshot (keeps last 30 days)
export const snapshotLeaderboard = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async () => {
    const top100 = await db
      .collection('users')
      .where('isActive', '==', true)
      .orderBy('totalPoints', 'desc')
      .limit(100)
      .get();

    const today = new Date().toISOString().split('T')[0];
    const batch = db.batch();
    const snapshotRef = db.collection('leaderboard_snapshots').doc(today);

    batch.set(snapshotRef, {
      date: today,
      entries: top100.docs.map((doc, i) => ({
        rank: i + 1,
        userId: doc.id,
        displayName: doc.data().displayName || 'Anónimo',
        totalPoints: doc.data().totalPoints || 0,
        level: doc.data().level || 'explorer',
      })),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Purge snapshots older than 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const cutoff = thirtyDaysAgo.toISOString().split('T')[0];

    const old = await db
      .collection('leaderboard_snapshots')
      .where('date', '<', cutoff)
      .get();

    old.docs.forEach((doc) => batch.delete(doc.ref));

    await batch.commit();
  });
