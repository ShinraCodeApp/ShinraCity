import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// Scheduled function: expire coupons every hour
export const expireCoupons = functions.pubsub
  .schedule("every 60 minutes")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    let count = 0;

    const expired = await db
      .collection("coupons")
      .where("status", "==", "available")
      .where("expiresAt", "<", now)
      .limit(500)
      .get();

    expired.docs.forEach((doc) => {
      batch.update(doc.ref, {
        status: "expired",
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
    });

    if (count > 0) await batch.commit();
    functions.logger.info(`Expired ${count} coupons`);
  });

// Trigger: after coupon redeemed, award points and update stats
export const onCouponRedeemed = functions.firestore
  .document("coupons/{couponId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== "available" || after.status !== "used") return;

    const { userId, commerceId, promotionId } = after;
    const promotionDoc = await db.collection("promotions").doc(promotionId).get();
    const promotion = promotionDoc.data();

    if (!promotion) return;

    const pointsToAward = promotion.pointsAwarded ?? 10;

    // Award points to user
    await db.runTransaction(async (t) => {
      const userRef = db.collection("users").doc(userId);
      const userDoc = await t.get(userRef);
      const user = userDoc.data();
      if (!user) return;

      const newTotal = (user.totalPoints ?? 0) + pointsToAward;
      const newAvailable = (user.availablePoints ?? 0) + pointsToAward;
      const newRedeemed = (user.totalCouponsRedeemed ?? 0) + 1;
      const savedAmount = (promotion.originalPrice ?? 0) - (promotion.discountedPrice ?? 0);

      t.update(userRef, {
        totalPoints: newTotal,
        availablePoints: newAvailable,
        totalCouponsRedeemed: newRedeemed,
        totalSavings: admin.firestore.FieldValue.increment(savedAmount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log points transaction
      t.set(db.collection("points_transactions").doc(), {
        userId,
        points: pointsToAward,
        type: "earned",
        reason: "coupon_redeemed",
        commerceId,
        promotionId,
        couponId: context.params.couponId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Update coupon with points earned
    await change.after.ref.update({ pointsEarned: pointsToAward });

    // Update commerce stats
    await db.collection("commerces").doc(commerceId).update({
      "stats.couponsRedeemed": admin.firestore.FieldValue.increment(1),
      "stats.totalRevenue": admin.firestore.FieldValue.increment(promotion.discountedPrice ?? 0),
    });

    // Check for achievements
    await checkAchievements(userId);

    // Update user level
    await checkAndUpdateLevel(userId);
  });

// Validate QR scan (callable function)
export const validateQRScan = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión");
  }

  const { qrData, commerceId, branchId } = data;
  const employeeId = context.auth.uid;

  // Verify employee belongs to commerce
  const commerceDoc = await db.collection("commerces").doc(commerceId).get();
  if (!commerceDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Comercio no encontrado");
  }

  const commerce = commerceDoc.data()!;
  if (
    commerce.ownerId !== employeeId &&
    !(commerce.authorizedEmployeeIds ?? []).includes(employeeId)
  ) {
    throw new functions.https.HttpsError("permission-denied", "No autorizado para escanear cupones");
  }

  let payload: any;
  try {
    payload = JSON.parse(qrData);
  } catch {
    throw new functions.https.HttpsError("invalid-argument", "QR inválido");
  }

  if (payload.shinra !== "1") {
    throw new functions.https.HttpsError("invalid-argument", "QR no pertenece a ShinraCity");
  }

  const couponId = payload.id;
  const couponRef = db.collection("coupons").doc(couponId);

  return await db.runTransaction(async (t) => {
    const couponDoc = await t.get(couponRef);
    if (!couponDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Cupón no encontrado");
    }

    const coupon = couponDoc.data()!;

    if (coupon.commerceId !== commerceId) {
      throw new functions.https.HttpsError("permission-denied", "Cupón no corresponde a este comercio");
    }

    if (coupon.status !== "available") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        coupon.status === "used" ? "Cupón ya utilizado" :
        coupon.status === "expired" ? "Cupón expirado" : "Cupón no disponible"
      );
    }

    const expiresAt = coupon.expiresAt.toDate();
    if (new Date() > expiresAt) {
      t.update(couponRef, { status: "expired" });
      throw new functions.https.HttpsError("failed-precondition", "Cupón expirado");
    }

    t.update(couponRef, {
      status: "used",
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
      usedByEmployeeId: employeeId,
      usedAtBranchId: branchId ?? null,
    });

    return {
      success: true,
      couponId,
      userId: coupon.userId,
      promotionTitle: coupon.promotionTitle,
      discountValue: coupon.metadata?.discountValue,
      discountType: coupon.metadata?.discountType,
    };
  });
});

async function checkAchievements(userId: string): Promise<void> {
  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data();
  if (!user) return;

  const redeemed = user.totalCouponsRedeemed ?? 0;
  const achievementsToCheck = [];

  if (redeemed === 1) achievementsToCheck.push("first_coupon");
  if (redeemed === 10) achievementsToCheck.push("ten_coupons");
  if (redeemed === 50) achievementsToCheck.push("fifty_coupons");
  if (redeemed === 100) achievementsToCheck.push("hundred_coupons");

  for (const achievementId of achievementsToCheck) {
    if (!(user.achievementIds ?? []).includes(achievementId)) {
      await db.collection("users").doc(userId).update({
        achievementIds: admin.firestore.FieldValue.arrayUnion(achievementId),
      });
      // Send achievement notification
      await sendAchievementNotification(userId, achievementId);
    }
  }
}

async function checkAndUpdateLevel(userId: string): Promise<void> {
  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data();
  if (!user) return;

  const points = user.totalPoints ?? 0;
  let newLevel = "explorer";

  if (points >= 15000) newLevel = "lifetime";
  else if (points >= 5000) newLevel = "ambassador";
  else if (points >= 2000) newLevel = "exemplary";
  else if (points >= 500) newLevel = "frequent";

  if (user.level !== newLevel) {
    await db.collection("users").doc(userId).update({ level: newLevel });
    await sendLevelUpNotification(userId, newLevel);
  }
}

async function sendAchievementNotification(userId: string, achievementId: string): Promise<void> {
  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data();
  if (!user?.fcmToken) return;

  await admin.messaging().send({
    token: user.fcmToken,
    notification: {
      title: "🏆 ¡Nuevo logro desbloqueado!",
      body: getAchievementMessage(achievementId),
    },
    data: { type: "achievement", achievementId },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "achievement.caf" } } },
  });
}

async function sendLevelUpNotification(userId: string, level: string): Promise<void> {
  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data();
  if (!user?.fcmToken) return;

  const levelNames: Record<string, string> = {
    frequent: "Cliente Frecuente",
    exemplary: "Cliente Ejemplar",
    ambassador: "Embajador",
    lifetime: "Socio Vitalicio",
  };

  await admin.messaging().send({
    token: user.fcmToken,
    notification: {
      title: "⬆️ ¡Subiste de nivel!",
      body: `Ahora eres ${levelNames[level] ?? level}. ¡Sigue así!`,
    },
    data: { type: "level_up", level },
    android: { priority: "high" },
  });
}

function getAchievementMessage(id: string): string {
  const messages: Record<string, string> = {
    first_coupon: "Usaste tu primer cupón",
    ten_coupons: "Usaste 10 cupones",
    fifty_coupons: "Usaste 50 cupones. ¡Increíble!",
    hundred_coupons: "100 cupones. ¡Eres una leyenda!",
  };
  return messages[id] ?? "Nuevo logro desbloqueado";
}
