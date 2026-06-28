import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import Stripe from "stripe";

const db = admin.firestore();

const getStripe = () => new Stripe(functions.config().stripe?.secret_key ?? process.env.STRIPE_SECRET_KEY ?? "", {
  apiVersion: "2023-10-16",
});

const DEFAULT_PLAN_PRICES: Record<string, number> = {
  basic: 2990,
  premium: 5990,
  enterprise: 14990,
};

async function getPlanPrice(plan: string, billingCycle: string): Promise<number> {
  try {
    const doc = await db.collection("config").doc("plans").get();
    if (doc.exists) {
      const data = doc.data()!;
      const monthly = data[plan]?.monthly as number ?? DEFAULT_PLAN_PRICES[plan] ?? 2990;
      const annual = data[plan]?.annual as number ?? Math.floor(monthly * 0.8);
      return billingCycle === "annual" ? annual * 12 : monthly;
    }
  } catch (_) {}
  const base = DEFAULT_PLAN_PRICES[plan] ?? 2990;
  return billingCycle === "annual" ? Math.floor(base * 12 * 0.8) : base;
}

// Create Stripe payment intent for plan upgrade
export const createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión");
  }

  const { plan, billingCycle, currency = "ars" } = data;
  const stripe = getStripe();

  if (!DEFAULT_PLAN_PRICES[plan]) {
    throw new functions.https.HttpsError("invalid-argument", "Plan inválido");
  }

  const amount = await getPlanPrice(plan, billingCycle);

  const userDoc = await db.collection("users").doc(context.auth.uid).get();
  const user = userDoc.data();

  let customerId = user?.stripeCustomerId;
  if (!customerId) {
    const customer = await stripe.customers.create({
      email: user?.email,
      name: user?.displayName,
      metadata: { userId: context.auth.uid },
    });
    customerId = customer.id;
    await db.collection("users").doc(context.auth.uid).update({
      stripeCustomerId: customerId,
    });
  }

  const paymentIntent = await stripe.paymentIntents.create({
    amount,
    currency,
    customer: customerId,
    metadata: {
      userId: context.auth.uid,
      plan,
      billingCycle,
    },
    automatic_payment_methods: { enabled: true },
  });

  return {
    clientSecret: paymentIntent.client_secret,
    amount,
    currency,
  };
});

// Stripe webhook handler
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const stripe = getStripe();
  const webhookSecret = functions.config().stripe?.webhook_secret ?? "";
  const sig = req.headers["stripe-signature"] as string;

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    res.status(400).send(`Webhook Error: ${(err as Error).message}`);
    return;
  }

  switch (event.type) {
    case "payment_intent.succeeded":
      await handlePaymentSucceeded(event.data.object as Stripe.PaymentIntent);
      break;
    case "payment_intent.payment_failed":
      await handlePaymentFailed(event.data.object as Stripe.PaymentIntent);
      break;
    case "customer.subscription.deleted":
      await handleSubscriptionCancelled(event.data.object as Stripe.Subscription);
      break;
    case "customer.subscription.updated":
      await handleSubscriptionUpdated(event.data.object as Stripe.Subscription);
      break;
  }

  res.json({ received: true });
});

// Mercado Pago payment preference (for LATAM)
export const createMercadoPagoPreference = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión");
  }

  const { plan, billingCycle } = data;
  const mpAccessToken = functions.config().mercadopago?.access_token ?? "";

  if (!DEFAULT_PLAN_PRICES[plan]) {
    throw new functions.https.HttpsError("invalid-argument", "Plan inválido");
  }

  const amount = await getPlanPrice(plan, billingCycle);

  const planNames: Record<string, string> = {
    basic: "ShinraCity Básico",
    premium: "ShinraCity Premium",
    enterprise: "ShinraCity Empresarial",
  };

  const response = await fetch("https://api.mercadopago.com/checkout/preferences", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${mpAccessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      items: [{
        title: `${planNames[plan]} - ${billingCycle === "annual" ? "Anual" : "Mensual"}`,
        unit_price: amount / 100,
        quantity: 1,
        currency_id: "ARS",
      }],
      payer: { email: context.auth.token.email },
      external_reference: `${context.auth.uid}:${plan}:${billingCycle}`,
      back_urls: {
        success: "shinracity://payment/success",
        failure: "shinracity://payment/failure",
        pending: "shinracity://payment/pending",
      },
      auto_return: "approved",
    }),
  });

  const preference = await response.json();
  return { preferenceId: preference.id, initPoint: preference.init_point };
});

// Mercado Pago webhook
export const mercadoPagoWebhook = functions.https.onRequest(async (req, res) => {
  const { type, data } = req.body;

  if (type === "payment") {
    const paymentId = data.id;
    const mpAccessToken = functions.config().mercadopago?.access_token ?? "";

    const response = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      headers: { "Authorization": `Bearer ${mpAccessToken}` },
    });

    const payment = await response.json();

    if (payment.status === "approved") {
      const [userId, plan, billingCycle] = (payment.external_reference ?? "").split(":");
      if (userId && plan) {
        await activateCommercePlan(userId, plan, billingCycle ?? "monthly");
      }
    }
  }

  res.status(200).send("OK");
});

async function handlePaymentSucceeded(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const { userId, plan, billingCycle } = paymentIntent.metadata;
  if (userId && plan) {
    await activateCommercePlan(userId, plan, billingCycle ?? "monthly");
  }
}

async function handlePaymentFailed(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const { userId } = paymentIntent.metadata;
  if (userId) {
    await db.collection("payment_logs").add({
      userId,
      status: "failed",
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

async function handleSubscriptionCancelled(subscription: Stripe.Subscription): Promise<void> {
  const customer = subscription.customer as string;
  const userQuery = await db
    .collection("users")
    .where("stripeCustomerId", "==", customer)
    .limit(1)
    .get();

  if (!userQuery.empty) {
    const userId = userQuery.docs[0].id;
    const commerceQuery = await db
      .collection("commerces")
      .where("ownerId", "==", userId)
      .limit(1)
      .get();

    if (!commerceQuery.empty) {
      await commerceQuery.docs[0].ref.update({ plan: "free" });
    }
  }
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription): Promise<void> {
  const customer = subscription.customer as string;
  const userQuery = await db
    .collection("users")
    .where("stripeCustomerId", "==", customer)
    .limit(1)
    .get();

  if (userQuery.empty) return;

  const userId = userQuery.docs[0].id;
  const commerceQuery = await db
    .collection("commerces")
    .where("ownerId", "==", userId)
    .limit(1)
    .get();

  if (commerceQuery.empty) return;

  // Map Stripe price ID to plan name (using default price IDs)
  const STRIPE_PRICE_IDS: Record<string, { monthly: string; annual: string }> = {
    basic: { monthly: "price_basic_monthly", annual: "price_basic_annual" },
    premium: { monthly: "price_premium_monthly", annual: "price_premium_annual" },
    enterprise: { monthly: "price_enterprise_monthly", annual: "price_enterprise_annual" },
  };
  const priceId = subscription.items.data[0]?.price.id ?? "";
  let plan = "free";
  for (const [planKey, planData] of Object.entries(STRIPE_PRICE_IDS)) {
    if (priceId === planData.monthly || priceId === planData.annual) {
      plan = planKey;
      break;
    }
  }

  const isActive = subscription.status === "active";
  await commerceQuery.docs[0].ref.update({
    plan: isActive ? plan : "free",
    "subscription.status": subscription.status,
    "subscription.currentPeriodEnd": admin.firestore.Timestamp.fromMillis(
      subscription.current_period_end * 1000
    ),
    "subscription.updatedAt": admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function activateCommercePlan(
  userId: string,
  plan: string,
  billingCycle: string
): Promise<void> {
  const commerceQuery = await db
    .collection("commerces")
    .where("ownerId", "==", userId)
    .limit(1)
    .get();

  if (commerceQuery.empty) return;

  const expiresAt = new Date();
  if (billingCycle === "annual") {
    expiresAt.setFullYear(expiresAt.getFullYear() + 1);
  } else {
    expiresAt.setMonth(expiresAt.getMonth() + 1);
  }

  await commerceQuery.docs[0].ref.update({
    plan,
    "subscription.status": "active",
    "subscription.billingCycle": billingCycle,
    "subscription.currentPeriodEnd": admin.firestore.Timestamp.fromDate(expiresAt),
    "subscription.updatedAt": admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection("payment_logs").add({
    userId,
    commerceId: commerceQuery.docs[0].id,
    plan,
    billingCycle,
    status: "completed",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
