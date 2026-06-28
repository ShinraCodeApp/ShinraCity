import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

// AI-powered promotion recommendations
export const getPersonalizedRecommendations = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión");
  }

  const { userId, limit = 10 } = data;

  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data();
  if (!user) return { promotions: [] };

  // Get user behavior signals
  const [couponsHistory, favorites, following] = await Promise.all([
    db.collection("coupons")
      .where("userId", "==", userId)
      .orderBy("issuedAt", "desc")
      .limit(20)
      .get(),
    user.favoriteCommerceIds ?? [],
    user.followingCategories ?? [],
  ]);

  // Build interest profile
  const commerceCounts: Record<string, number> = {};

  couponsHistory.docs.forEach((doc) => {
    const coupon = doc.data();
    commerceCounts[coupon.commerceId] = (commerceCounts[coupon.commerceId] ?? 0) + 1;
  });

  // Score-based recommendation
  const promotions = await db
    .collection("promotions")
    .where("status", "==", "active")
    .limit(100)
    .get();

  const scored = promotions.docs.map((doc) => {
    const promo = doc.data();
    let score = 0;

    // Category interest boost
    if (following.includes(promo.category)) score += 30;

    // Commerce loyalty boost
    if (favorites.includes(promo.commerceId)) score += 50;
    if (commerceCounts[promo.commerceId]) score += commerceCounts[promo.commerceId] * 10;

    // Plan boost (premium shown first)
    const planBoosts: Record<string, number> = { enterprise: 40, premium: 30, basic: 10 };
    score += planBoosts[promo.commercePlan] ?? 0;

    // Recency boost
    const createdAt = promo.createdAt?.toDate?.() ?? new Date(0);
    const hoursOld = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);
    if (hoursOld < 24) score += 20;

    // Available slots urgency
    if (promo.totalSlots && promo.usedSlots) {
      const remaining = promo.totalSlots - promo.usedSlots;
      if (remaining < 10) score += 15;
    }

    // User level access
    if (promo.isVip && user.level !== "lifetime" && user.level !== "ambassador") score -= 100;

    return { id: doc.id, score, ...promo };
  });

  scored.sort((a, b) => b.score - a.score);

  return {
    promotions: scored.slice(0, limit).map((p) => {
      const promo = p as any; // eslint-disable-line @typescript-eslint/no-explicit-any
      return {
        id: promo.id,
        title: promo.title,
        commerceId: promo.commerceId,
        commerceName: promo.commerceName,
        discountValue: promo.discountValue,
        discountType: promo.discountType,
        score: promo.score,
      };
    }),
  };
});

// Fraud detection
export const detectFraud = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "No autorizado");
  }

  const { userId, deviceId, action, promotionId } = data;

  const signals: string[] = [];
  let fraudScore = 0;

  // Check 1: Multiple claims from same device
  const deviceClaims = await db
    .collection("coupons")
    .where("metadata.deviceId", "==", deviceId)
    .where("createdAt", ">", admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 60 * 60 * 1000)
    ))
    .count()
    .get();

  if (deviceClaims.data().count > 10) {
    fraudScore += 50;
    signals.push("high_device_claim_rate");
  }

  // Check 2: Multiple accounts from same device
  const deviceAccounts = await db
    .collection("audit_logs")
    .where("deviceId", "==", deviceId)
    .where("action", "==", "login")
    .where("createdAt", ">", admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000)
    ))
    .get();

  const uniqueUsers = new Set(deviceAccounts.docs.map((d) => d.data().userId));
  if (uniqueUsers.size > 3) {
    fraudScore += 70;
    signals.push("multiple_accounts_same_device");
  }

  // Check 3: Rapid sequential claims
  const recentClaims = await db
    .collection("coupons")
    .where("userId", "==", userId)
    .where("createdAt", ">", admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 5 * 60 * 1000) // 5 minutes
    ))
    .count()
    .get();

  if (recentClaims.data().count > 5) {
    fraudScore += 40;
    signals.push("rapid_claiming");
  }

  const isFraud = fraudScore >= 60;

  if (isFraud) {
    await db.collection("fraud_alerts").add({
      userId,
      deviceId,
      action,
      promotionId,
      fraudScore,
      signals,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      resolved: false,
    });
  }

  return { isFraud, fraudScore, signals };
});

// Generate commerce analytics summary
export const generateCommerceAnalytics = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const commerces = await db
      .collection("commerces")
      .where("status", "==", "active")
      .get();

    for (const commerce of commerces.docs) {
      const commerceId = commerce.id;
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      const [coupons, views] = await Promise.all([
        db.collection("coupons")
          .where("commerceId", "==", commerceId)
          .where("status", "==", "used")
          .where("usedAt", ">", admin.firestore.Timestamp.fromDate(yesterday))
          .count()
          .get(),
        db.collection("analytics_events")
          .where("commerceId", "==", commerceId)
          .where("type", "==", "commerce_view")
          .where("createdAt", ">", admin.firestore.Timestamp.fromDate(yesterday))
          .count()
          .get(),
      ]);

      await db.collection("commerces").doc(commerceId).update({
        "stats.dailyCouponsRedeemed": coupons.data().count,
        "stats.dailyViews": views.data().count,
        "stats.lastUpdated": admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    functions.logger.info(`Analytics updated for ${commerces.size} commerces`);
  });

// Suggest campaign improvements for commerce
export const getCampaignSuggestions = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "No autorizado");
  }

  const { commerceId } = data;

  const [promotions, coupons, commerce] = await Promise.all([
    db.collection("promotions").where("commerceId", "==", commerceId).get(),
    db.collection("coupons").where("commerceId", "==", commerceId).where("status", "==", "used").get(),
    db.collection("commerces").doc(commerceId).get(),
  ]);

  const suggestions: string[] = [];
  const commerceData = commerce.data();

  // Analyze patterns
  const conversionRate = promotions.size > 0
    ? (coupons.size / (promotions.size * 100)) * 100
    : 0;

  if (conversionRate < 5) {
    suggestions.push("Considera aumentar el descuento para mejorar la conversión");
  }

  if (!commerceData?.logoUrl) {
    suggestions.push("Agrega un logo para aumentar visibilidad");
  }

  if ((commerceData?.galleryUrls ?? []).length < 3) {
    suggestions.push("Agrega más fotos para atraer clientes");
  }

  if ((promotions.docs.filter((p) => p.data().type === "followers")).length === 0) {
    suggestions.push("Crea una promoción exclusiva para seguidores para fidelizar clientes");
  }

  const hour = new Date().getHours();
  if (hour >= 11 && hour <= 13) {
    suggestions.push("Las 11:00-13:00 son horas pico. Considera activar una promoción especial de mediodía");
  }

  return { suggestions, conversionRate: conversionRate.toFixed(1) };
});
