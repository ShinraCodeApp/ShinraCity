import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

const db = admin.firestore();

interface FraudSignal {
  type: string;
  score: number;
  details: string;
}

interface FraudAssessment {
  userId: string;
  deviceId: string;
  score: number;
  signals: FraudSignal[];
  action: 'allow' | 'review' | 'block';
  timestamp: admin.firestore.Timestamp;
}

// Real-time fraud detection on coupon claim
export const detectFraudOnClaim = functions.firestore
  .document('coupons/{couponId}')
  .onCreate(async (snap) => {
    const coupon = snap.data();
    const { userId, deviceId, promotionId, commerceId } = coupon;

    const assessment = await assessFraud({ userId, deviceId, promotionId, commerceId });

    // If high fraud risk, mark coupon for review
    if (assessment.action === 'block') {
      await snap.ref.update({
        status: 'flagged',
        fraudScore: assessment.score,
        fraudSignals: assessment.signals.map((s) => s.type),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Alert admins
      await notifyFraudAlert(userId, assessment.score, assessment.signals);
    } else if (assessment.action === 'review') {
      await snap.ref.update({
        fraudScore: assessment.score,
        needsReview: true,
      });
    }

    // Store assessment regardless
    await db.collection('fraud_assessments').add({
      ...assessment,
      couponId: snap.id,
    });
  });

async function assessFraud(params: {
  userId: string;
  deviceId: string;
  promotionId: string;
  commerceId: string;
}): Promise<FraudAssessment> {
  const { userId, deviceId, promotionId, commerceId: _commerceId } = params; // eslint-disable-line @typescript-eslint/no-unused-vars
  const signals: FraudSignal[] = [];
  let totalScore = 0;

  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  // Signal 1: Device claim rate (same device > 10 claims/hour)
  const deviceClaimsHour = await db
    .collection('coupons')
    .where('deviceId', '==', deviceId)
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(oneHourAgo))
    .count()
    .get();

  if (deviceClaimsHour.data().count > 10) {
    const score = Math.min(50 + (deviceClaimsHour.data().count - 10) * 5, 80);
    signals.push({ type: 'high_device_claim_rate', score, details: `${deviceClaimsHour.data().count} claims/hr` });
    totalScore += score;
  }

  // Signal 2: Multiple accounts same device (> 3)
  const devicesAccounts = await db
    .collection('coupons')
    .where('deviceId', '==', deviceId)
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(oneDayAgo))
    .get();

  const uniqueUsers = new Set(devicesAccounts.docs.map((d) => d.data().userId));
  if (uniqueUsers.size > 3) {
    const score = Math.min(70 + (uniqueUsers.size - 3) * 10, 90);
    signals.push({ type: 'multiple_accounts_device', score, details: `${uniqueUsers.size} users` });
    totalScore += score;
  }

  // Signal 3: Rapid claiming (same user > 5 claims in 5 min)
  const rapidClaims = await db
    .collection('coupons')
    .where('userId', '==', userId)
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(fiveMinutesAgo))
    .count()
    .get();

  if (rapidClaims.data().count > 5) {
    const score = Math.min(40 + (rapidClaims.data().count - 5) * 10, 70);
    signals.push({ type: 'rapid_claiming', score, details: `${rapidClaims.data().count} claims/5min` });
    totalScore += score;
  }

  // Signal 4: Same promotion claimed multiple times by same user (should already be blocked)
  const duplicateClaims = await db
    .collection('coupons')
    .where('userId', '==', userId)
    .where('promotionId', '==', promotionId)
    .where('status', '!=', 'cancelled')
    .count()
    .get();

  if (duplicateClaims.data().count > 1) {
    signals.push({ type: 'duplicate_claim', score: 60, details: `Claim count: ${duplicateClaims.data().count}` });
    totalScore += 60;
  }

  // Signal 5: Account age < 1 hour + high claim rate
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();
  if (userData?.createdAt) {
    const accountAge = Date.now() - userData.createdAt.toMillis();
    if (accountAge < 60 * 60 * 1000 && rapidClaims.data().count > 2) {
      signals.push({ type: 'new_account_rapid_claims', score: 50, details: `Age: ${Math.floor(accountAge / 60000)}min` });
      totalScore += 50;
    }
  }

  // Signal 6: Antifraud fingerprint collision
  const today = new Date().toISOString().split('T')[0];
  const fingerprintInput = `${userId}:${deviceId}:${promotionId}:${today}`;
  const fingerprint = crypto.createHash('sha256').update(fingerprintInput).digest('hex').substring(0, 16);

  const existingFingerprint = await db
    .collection('coupons')
    .where('antifraudFingerprint', '==', fingerprint)
    .where('userId', '!=', userId)
    .count()
    .get();

  if (existingFingerprint.data().count > 0) {
    signals.push({ type: 'fingerprint_collision', score: 80, details: 'Same device+promo+day, different user' });
    totalScore += 80;
  }

  const action: 'allow' | 'review' | 'block' =
    totalScore >= 80 ? 'block' : totalScore >= 40 ? 'review' : 'allow';

  return {
    userId,
    deviceId,
    score: totalScore,
    signals,
    action,
    timestamp: admin.firestore.Timestamp.now(),
  };
}

async function notifyFraudAlert(
  userId: string,
  score: number,
  signals: FraudSignal[]
) {
  const adminsSnap = await db
    .collection('users')
    .where('role', 'in', ['admin', 'superAdmin'])
    .get();

  const tokens: string[] = [];
  adminsSnap.docs.forEach((doc) => tokens.push(...(doc.data().fcmTokens || [])));

  if (tokens.length > 0) {
    await admin.messaging().sendEachForMulticast({
      tokens: tokens.slice(0, 500),
      notification: {
        title: '🚨 Alerta de fraude',
        body: `Usuario ${userId} - Score: ${score}`,
      },
      data: {
        type: 'fraud_alert',
        userId,
        score: String(score),
        signals: signals.map((s) => s.type).join(','),
        screen: '/admin/fraud',
      },
    });
  }
}

// Block user on manual admin action
export const blockFraudUser = functions.https.onCall(
  async (data: { userId: string; reason: string }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Autenticación requerida');
    }

    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!['admin', 'superAdmin'].includes(callerDoc.data()?.role)) {
      throw new functions.https.HttpsError('permission-denied', 'Sin permisos de admin');
    }

    const { userId, reason } = data;

    await db.runTransaction(async (t) => {
      const userRef = db.collection('users').doc(userId);
      t.update(userRef, {
        isActive: false,
        isSuspended: true,
        suspensionReason: reason,
        suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
        suspendedBy: context.auth!.uid,
      });

      // Disable all active coupons
      const activeCoupons = await db
        .collection('coupons')
        .where('userId', '==', userId)
        .where('status', '==', 'available')
        .get();

      activeCoupons.docs.forEach((doc) => {
        t.update(doc.ref, { status: 'cancelled', cancelReason: 'account_suspended' });
      });

      // Log audit
      t.set(db.collection('audit_logs').doc(), {
        action: 'user_suspended',
        targetId: userId,
        performedBy: context.auth!.uid,
        reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { success: true };
  }
);

// Scheduled: flag suspicious patterns daily
export const dailyFraudScan = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayTs = admin.firestore.Timestamp.fromDate(yesterday);

    // Find users with > 20 redemptions yesterday
    const highVolume = await db
      .collection('coupons')
      .where('status', '==', 'used')
      .where('redeemedAt', '>=', yesterdayTs)
      .get();

    const userCounts: Record<string, number> = {};
    highVolume.docs.forEach((doc) => {
      const uid = doc.data().userId;
      userCounts[uid] = (userCounts[uid] || 0) + 1;
    });

    const suspicious = Object.entries(userCounts).filter(([, count]) => count > 20);

    for (const [userId] of suspicious) {
      await db.collection('fraud_flags').add({
        userId,
        type: 'high_daily_redemption',
        count: userCounts[userId],
        date: yesterday.toISOString().split('T')[0],
        reviewed: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
