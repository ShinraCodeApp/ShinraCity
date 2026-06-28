import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const messaging = admin.messaging();

// Geohash bounds for prefix queries (precision 5 ≈ 4.9km cells)
const GEOHASH_CHARS = '0123456789bcdefghjkmnpqrstuvwxyz';

function encodeGeohash(lat: number, lon: number, precision = 7): string {
  let minLat = -90, maxLat = 90;
  let minLon = -180, maxLon = 180;
  let hash = '';
  let isEven = true;
  let bits = 0;
  let ch = 0;

  while (hash.length < precision) {
    if (isEven) {
      const mid = (minLon + maxLon) / 2;
      if (lon > mid) { ch = (ch << 1) + 1; minLon = mid; }
      else { ch <<= 1; maxLon = mid; }
    } else {
      const mid = (minLat + maxLat) / 2;
      if (lat > mid) { ch = (ch << 1) + 1; minLat = mid; }
      else { ch <<= 1; maxLat = mid; }
    }
    isEven = !isEven;
    if (++bits === 5) {
      hash += GEOHASH_CHARS[ch];
      bits = 0;
      ch = 0;
    }
  }
  return hash;
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Called when user updates their location — check geofences
export const checkGeofences = functions.https.onCall(
  async (
    data: { userId: string; lat: number; lon: number },
    context
  ) => {
    if (!context.auth || context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError('unauthenticated', 'Autenticación requerida');
    }

    const { userId, lat, lon } = data;

    // Rate limit: max 1 check per 2 minutes per user
    const lastCheckDoc = await db
      .collection('geofence_checks')
      .doc(userId)
      .get();

    if (lastCheckDoc.exists) {
      const lastCheck = lastCheckDoc.data()!.lastCheckedAt?.toMillis() || 0;
      if (Date.now() - lastCheck < 2 * 60 * 1000) {
        return { notified: 0 };
      }
    }

    await db.collection('geofence_checks').doc(userId).set({
      lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Find commerces within 200m using geohash prefix
    const geohash = encodeGeohash(lat, lon, 7);
    const prefix = geohash.substring(0, 5);

    const commercesSnap = await db
      .collection('commerces')
      .where('status', '==', 'active')
      .where('hasActivePromotion', '==', true)
      .where('geohash', '>=', prefix)
      .where('geohash', '<', prefix + '~')
      .limit(10)
      .get();

    const nearby = commercesSnap.docs.filter((doc) => {
      const data = doc.data();
      const gp = data.location as admin.firestore.GeoPoint;
      return haversineKm(lat, lon, gp.latitude, gp.longitude) <= 0.2; // 200m
    });

    if (nearby.length === 0) return { notified: 0 };

    // Get user FCM tokens + already-notified set
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmTokens: string[] = userDoc.data()?.fcmTokens || [];
    if (fcmTokens.length === 0) return { notified: 0 };

    // Check 24h notification cooldown per user+commerce
    const today = new Date().toISOString().split('T')[0];
    const notifiedKey = `geofence_notified_${userId}_${today}`;
    const notifiedRef = db.collection('notification_cooldowns').doc(notifiedKey);
    const notifiedDoc = await notifiedRef.get();
    const alreadyNotified: string[] = notifiedDoc.data()?.commerceIds || [];

    let notifiedCount = 0;
    for (const commerceDoc of nearby) {
      const cid = commerceDoc.id;
      if (alreadyNotified.includes(cid)) continue;

      const commerce = commerceDoc.data();

      await messaging.sendEachForMulticast({
        tokens: fcmTokens.slice(0, 500),
        notification: {
          title: `🗺️ ${commerce.name} está cerca`,
          body: `${commerce.activePromotionsCount} promoción(es) activa(s) a solo 200m de distancia`,
        },
        data: {
          type: 'geofence_enter',
          commerceId: cid,
          commerceName: commerce.name,
          screen: `/commerce/${cid}`,
        },
        android: {
          priority: 'normal',
          notification: {
            channelId: 'shinra_city_promos',
            icon: '@drawable/ic_notification',
          },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      });

      alreadyNotified.push(cid);
      notifiedCount++;

      // Max 3 geofence notifications per day
      if (notifiedCount >= 3) break;
    }

    if (notifiedCount > 0) {
      await notifiedRef.set({ commerceIds: alreadyNotified });
    }

    return { notified: notifiedCount };
  }
);

// Notify users near a new active promotion
export const notifyNearbyUsersForPromotion = functions.firestore
  .document('promotions/{promotionId}')
  .onCreate(async (snap) => {
    const promotion = snap.data();
    if (promotion.status !== 'active') return;

    const commerceDoc = await db
      .collection('commerces')
      .doc(promotion.commerceId)
      .get();

    if (!commerceDoc.exists) return;

    const commerce = commerceDoc.data()!;
    const geoPoint = commerce.location as admin.firestore.GeoPoint;

    if (!geoPoint) return;

    const geohash = encodeGeohash(geoPoint.latitude, geoPoint.longitude, 7);
    const prefix = geohash.substring(0, 5);

    // Find users who have location near this commerce
    const usersSnap = await db
      .collection('users')
      .where('isActive', '==', true)
      .where('locationGeohash', '>=', prefix)
      .where('locationGeohash', '<', prefix + '~')
      .limit(200)
      .get();

    if (usersSnap.empty) return;

    const tokens: string[] = [];
    usersSnap.docs.forEach((doc) => {
      const data = doc.data();
      const userGp = data.location as admin.firestore.GeoPoint;
      if (!userGp) return;
      const distKm = haversineKm(
        geoPoint.latitude, geoPoint.longitude,
        userGp.latitude, userGp.longitude
      );
      if (distKm <= 1.0) { // 1km radius for new promotion alerts
        tokens.push(...(data.fcmTokens || []));
      }
    });

    if (tokens.length === 0) return;

    // Batch into chunks of 500
    const chunks: string[][] = [];
    for (let i = 0; i < tokens.length; i += 500) {
      chunks.push(tokens.slice(i, i + 500));
    }

    const discountText = promotion.discountType === 'percentage'
      ? `${promotion.discountValue}% OFF`
      : promotion.discountDescription || 'Oferta especial';

    for (const chunk of chunks) {
      await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: `🎉 Nueva promo en ${commerce.name}`,
          body: `${promotion.title} — ${discountText}`,
        },
        data: {
          type: 'new_promotion_nearby',
          promotionId: snap.id,
          commerceId: promotion.commerceId,
          screen: `/commerce/${promotion.commerceId}`,
        },
        android: {
          priority: 'normal',
          notification: { channelId: 'shinra_city_promos' },
        },
        apns: {
          payload: { aps: { sound: 'default' } },
        },
      });
    }
  });

// Update user's location geohash when they update their location
export const onUserLocationUpdate = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    const beforeLoc = before.location as admin.firestore.GeoPoint | undefined;
    const afterLoc = after.location as admin.firestore.GeoPoint | undefined;

    if (!afterLoc) return;
    if (
      beforeLoc?.latitude === afterLoc.latitude &&
      beforeLoc?.longitude === afterLoc.longitude
    ) return;

    const geohash = encodeGeohash(afterLoc.latitude, afterLoc.longitude, 7);
    await change.after.ref.update({ locationGeohash: geohash });
  });
