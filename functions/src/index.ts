import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();

// Export all function modules
export * from "./functions/coupon.functions";
export * from "./functions/notification.functions";
export * from "./functions/gamification.functions";
export * from "./functions/commerce.functions";
export * from "./functions/payment.functions";
export * from "./functions/ai.functions";
export * from "./functions/admin.functions";
export * from "./functions/geofencing.functions";
export * from "./functions/fraud.functions";

// Runtime config
const runtimeOpts: functions.RuntimeOptions = {
  timeoutSeconds: 60,
  memory: "256MB",
};

export { runtimeOpts };
