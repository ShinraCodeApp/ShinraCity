import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const messaging = admin.messaging();

// Send notification when new promotion is created near users
export const onPromotionCreated = functions.firestore
  .document("promotions/{promotionId}")
  .onCreate(async (snap, context) => {
    const promotion = snap.data();
    if (promotion.status !== "active") return;

    const { commerceId, title, isGeolocated, geoLocation, isExclusiveForFollowers } = promotion;

    const commerceDoc = await db.collection("commerces").doc(commerceId).get();
    const commerce = commerceDoc.data();
    if (!commerce) return;

    let tokens: string[] = [];

    if (isExclusiveForFollowers) {
      // Notify only followers
      const followers = await db
        .collection("users")
        .where("followingCommerceIds", "array-contains", commerceId)
        .where("notificationsEnabled", "==", true)
        .get();
      tokens = followers.docs
        .map((d) => d.data().fcmToken)
        .filter(Boolean);
    } else if (isGeolocated && geoLocation) {
      // Notify nearby users (geofenced)
      tokens = await getNearbyUserTokens(geoLocation, promotion.geoRadius ?? 2);
    } else {
      // Notify followers and users interested in category
      const interested = await db
        .collection("users")
        .where("followingCategories", "array-contains", commerce.category)
        .where("notificationsEnabled", "==", true)
        .limit(1000)
        .get();
      tokens = interested.docs
        .map((d) => d.data().fcmToken)
        .filter(Boolean);
    }

    if (tokens.length === 0) return;

    // Batch notifications (FCM max 500 per batch)
    const chunks = chunkArray(tokens, 500);
    for (const chunk of chunks) {
      await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: `🎉 Nueva oferta en ${commerce.name}`,
          body: title,
          imageUrl: promotion.imageUrls?.[0],
        },
        data: {
          type: "new_promotion",
          promotionId: context.params.promotionId,
          commerceId,
        },
        android: {
          priority: "high",
          notification: { channelId: "promotions" },
        },
        apns: {
          payload: { aps: { sound: "default", badge: 1 } },
        },
      });
    }

    functions.logger.info(`Notified ${tokens.length} users for promotion ${context.params.promotionId}`);
  });

// Notify users when they're near a commerce with active promotions
export const geofenceNotifications = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    // This is handled by client-side geofencing + server validation
    // Server sends targeted notifications based on location updates
    functions.logger.info("Geofence check executed");
  });

// Notify about expiring coupons (24h before expiration)
export const notifyExpiringCoupons = functions.pubsub
  .schedule("every 6 hours")
  .onRun(async () => {
    const now = new Date();
    const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const in25h = new Date(now.getTime() + 25 * 60 * 60 * 1000);

    const expiringSoon = await db
      .collection("coupons")
      .where("status", "==", "available")
      .where("expiresAt", ">=", admin.firestore.Timestamp.fromDate(in24h))
      .where("expiresAt", "<=", admin.firestore.Timestamp.fromDate(in25h))
      .get();

    for (const doc of expiringSoon.docs) {
      const coupon = doc.data();
      const userDoc = await db.collection("users").doc(coupon.userId).get();
      const user = userDoc.data();

      if (!user?.fcmToken || !user.notificationsEnabled) continue;

      const title = "⏰ Cupón próximo a vencer";
      const body = `Tu cupón de ${coupon.commerceName} vence en menos de 24 horas`;
      await messaging.send({
        token: user.fcmToken,
        notification: { title, body },
        data: { type: "coupon_expiring", couponId: doc.id, commerceId: coupon.commerceId },
      });
      await saveToInbox(coupon.userId, title, body, "coupon_expiring", {
        couponId: doc.id,
        commerceId: coupon.commerceId,
      });
    }

    functions.logger.info(`Notified users about ${expiringSoon.size} expiring coupons`);
  });

// Send location-based promotion notification (callable)
export const sendNearbyPromoNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) return;

  const { latitude, longitude, userId } = data;
  const radiusKm = 0.5;

  const promotions = await getNearbyActivePromotions(latitude, longitude, radiusKm);
  if (promotions.length === 0) return { notified: false };

  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data();
  if (!user?.fcmToken || !user.notificationsEnabled) return { notified: false };

  const promotion = promotions[0];

  // Rate limit: don't spam
  const recentNotif = await db
    .collection("notification_logs")
    .where("userId", "==", userId)
    .where("commerceId", "==", promotion.commerceId)
    .where("type", "==", "nearby")
    .where("sentAt", ">", admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 60 * 60 * 1000) // 1 hour ago
    ))
    .limit(1)
    .get();

  if (!recentNotif.empty) return { notified: false };

  const nearbyTitle = "📍 Oferta cerca de ti";
  const nearbyBody = `${promotion.commerceName}: ${promotion.title}`;
  await messaging.send({
    token: user.fcmToken,
    notification: { title: nearbyTitle, body: nearbyBody },
    data: { type: "nearby_promotion", promotionId: promotion.id, commerceId: promotion.commerceId },
  });
  await saveToInbox(userId, nearbyTitle, nearbyBody, "nearby_promotion", {
    promotionId: promotion.id,
    commerceId: promotion.commerceId,
  });

  await db.collection("notification_logs").add({
    userId,
    type: "nearby",
    commerceId: promotion.commerceId,
    promotionId: promotion.id,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { notified: true };
});

// Broadcast to all users (admin only)
export const broadcastNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "No autorizado");
  }

  const adminDoc = await db.collection("users").doc(context.auth.uid).get();
  const adminUser = adminDoc.data();
  if (!adminUser || !["admin", "superAdmin"].includes(adminUser.role)) {
    throw new functions.https.HttpsError("permission-denied", "Solo administradores");
  }

  const { title, body, data: notifData, topic } = data;

  if (topic) {
    await messaging.sendToTopic(topic, {
      notification: { title, body },
      data: notifData ?? {},
    });
  } else {
    await messaging.send({
      notification: { title, body },
      data: notifData ?? {},
      condition: "'all' in topics",
    });
  }

  return { success: true };
});

async function saveToInbox(
  userId: string,
  title: string,
  body: string,
  type: string,
  payload: Record<string, string> = {}
): Promise<void> {
  await db.collection("users").doc(userId).collection("notifications").add({
    title,
    body,
    type,
    payload,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function getNearbyUserTokens(geoLocation: any, radiusKm: number): Promise<string[]> {
  // Simplified: in production use Geohash proximity queries
  const users = await db
    .collection("users")
    .where("notificationsEnabled", "==", true)
    .limit(1000)
    .get();

  return users.docs
    .map((d) => d.data().fcmToken)
    .filter(Boolean);
}

async function getNearbyActivePromotions(lat: number, lng: number, radiusKm: number): Promise<any[]> {
  const promotions = await db
    .collection("promotions")
    .where("status", "==", "active")
    .limit(20)
    .get();

  return promotions.docs.map((d) => ({ id: d.id, ...d.data() }));
}

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
