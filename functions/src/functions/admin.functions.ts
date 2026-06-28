import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

const requireAdmin = async (uid: string): Promise<void> => {
  const userDoc = await db.collection("users").doc(uid).get();
  const user = userDoc.data();
  if (!user || !["admin", "superAdmin"].includes(user.role)) {
    throw new functions.https.HttpsError("permission-denied", "Solo administradores");
  }
};

// Verify a commerce
export const verifyCommerce = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "No autorizado");
  await requireAdmin(context.auth.uid);

  const { commerceId, verified } = data;

  await db.collection("commerces").doc(commerceId).update({
    isVerified: verified,
    status: verified ? "active" : "pending",
    verifiedAt: verified ? admin.firestore.FieldValue.serverTimestamp() : null,
    verifiedBy: context.auth.uid,
  });

  if (verified) {
    const commerce = await db.collection("commerces").doc(commerceId).get();
    const ownerId = commerce.data()?.ownerId;

    if (ownerId) {
      const userDoc = await db.collection("users").doc(ownerId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "✅ Comercio Verificado",
            body: `${commerce.data()?.name} ha sido verificado. ¡Ya puedes publicar promociones!`,
          },
          data: { type: "commerce_verified", commerceId },
        });
      }
    }
  }

  return { success: true };
});

// Suspend commerce or user
export const suspendEntity = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "No autorizado");
  await requireAdmin(context.auth.uid);

  const { entityType, entityId, reason, duration } = data;

  const collection = entityType === "commerce" ? "commerces" : "users";
  const suspendedUntil = duration
    ? new Date(Date.now() + duration * 24 * 60 * 60 * 1000)
    : null;

  await db.collection(collection).doc(entityId).update({
    status: "suspended",
    isActive: false,
    "suspension.reason": reason,
    "suspension.by": context.auth.uid,
    "suspension.at": admin.firestore.FieldValue.serverTimestamp(),
    "suspension.until": suspendedUntil
      ? admin.firestore.Timestamp.fromDate(suspendedUntil)
      : null,
  });

  await db.collection("audit_logs").add({
    action: "suspend",
    entityType,
    entityId,
    performedBy: context.auth.uid,
    reason,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// Get platform stats
export const getPlatformStats = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "No autorizado");
  await requireAdmin(context.auth.uid);

  const [users, commerces, promotions, coupons] = await Promise.all([
    db.collection("users").count().get(),
    db.collection("commerces").where("status", "==", "active").count().get(),
    db.collection("promotions").where("status", "==", "active").count().get(),
    db.collection("coupons").where("status", "==", "used").count().get(),
  ]);

  const last30Days = new Date();
  last30Days.setDate(last30Days.getDate() - 30);

  const [newUsers, newComerces] = await Promise.all([
    db.collection("users")
      .where("createdAt", ">", admin.firestore.Timestamp.fromDate(last30Days))
      .count()
      .get(),
    db.collection("commerces")
      .where("createdAt", ">", admin.firestore.Timestamp.fromDate(last30Days))
      .count()
      .get(),
  ]);

  return {
    totalUsers: users.data().count,
    activeCommerces: commerces.data().count,
    activePromotions: promotions.data().count,
    totalCouponsRedeemed: coupons.data().count,
    newUsersLast30Days: newUsers.data().count,
    newCommercesLast30Days: newComerces.data().count,
  };
});

// Moderate content (flagged images/descriptions)
export const moderateContent = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "No autorizado");
  await requireAdmin(context.auth.uid);

  const { contentId, contentType, action, reason } = data;

  const collections: Record<string, string> = {
    promotion: "promotions",
    commerce: "commerces",
    review: "reviews",
  };

  const collection = collections[contentType];
  if (!collection) {
    throw new functions.https.HttpsError("invalid-argument", "Tipo de contenido inválido");
  }

  const updateData: Record<string, any> = {
    "moderation.status": action,
    "moderation.reason": reason,
    "moderation.by": context.auth.uid,
    "moderation.at": admin.firestore.FieldValue.serverTimestamp(),
  };

  if (action === "removed") {
    updateData.status = "cancelled";
    updateData.isActive = false;
  }

  await db.collection(collection).doc(contentId).update(updateData);

  await db.collection("audit_logs").add({
    action: `moderate_${action}`,
    entityType: contentType,
    entityId: contentId,
    performedBy: context.auth.uid,
    reason,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// Assign admin role
export const assignRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "No autorizado");

  const callerDoc = await db.collection("users").doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== "superAdmin") {
    throw new functions.https.HttpsError("permission-denied", "Solo super administradores");
  }

  const { userId, role } = data;
  const validRoles = ["user", "businessOwner", "employee", "admin"];

  if (!validRoles.includes(role)) {
    throw new functions.https.HttpsError("invalid-argument", "Rol inválido");
  }

  await db.collection("users").doc(userId).update({ role });
  await admin.auth().setCustomUserClaims(userId, { role });

  await db.collection("audit_logs").add({
    action: "assign_role",
    entityId: userId,
    role,
    performedBy: context.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
