/**
 * Emulator seed script — populates local Firestore with test data.
 * Run: npx ts-node scripts/seed-emulator.ts
 * Requires emulators running: firebase emulators:start
 */

import * as admin from "firebase-admin";

// Point admin SDK at the local emulator
process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099";

admin.initializeApp({ projectId: "shinra-city" });

const db = admin.firestore();
const auth = admin.auth();

// ─── Helpers ─────────────────────────────────────────────────────────────────

const geohash = (lat: number, lng: number, precision = 7): string => {
  const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
  let minLat = -90, maxLat = 90, minLng = -180, maxLng = 180;
  let hash = "";
  let bits = 0, bit = 0, even = true;
  while (hash.length < precision) {
    if (even) {
      const mid = (minLng + maxLng) / 2;
      if (lng >= mid) { bit = (bit << 1) | 1; minLng = mid; }
      else { bit = bit << 1; maxLng = mid; }
    } else {
      const mid = (minLat + maxLat) / 2;
      if (lat >= mid) { bit = (bit << 1) | 1; minLat = mid; }
      else { bit = bit << 1; maxLat = mid; }
    }
    even = !even;
    if (++bits === 5) { hash += BASE32[bit]; bits = 0; bit = 0; }
  }
  return hash;
};

const now = admin.firestore.Timestamp.now();
const future = (days: number) =>
  admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + days * 86400000)
  );
const past = (days: number) =>
  admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - days * 86400000)
  );

// ─── Buenos Aires test locations ─────────────────────────────────────────────
const LOCATIONS = {
  palermo:      { lat: -34.5871, lng: -58.4328 },
  recoleta:     { lat: -34.5875, lng: -58.3944 },
  sanTelmo:     { lat: -34.6216, lng: -58.3731 },
  belgrano:     { lat: -34.5575, lng: -58.4592 },
  caballito:    { lat: -34.6188, lng: -58.4572 },
};

// ─── Auth users ───────────────────────────────────────────────────────────────
async function seedUsers() {
  console.log("👤 Seeding users...");

  const users = [
    { uid: "user_test_1", email: "user1@test.com", displayName: "María García", role: "user" },
    { uid: "user_test_2", email: "user2@test.com", displayName: "Juan Pérez", role: "user" },
    { uid: "business_test_1", email: "biz1@test.com", displayName: "Café Palermo", role: "businessOwner" },
    { uid: "business_test_2", email: "biz2@test.com", displayName: "Tech Store BA", role: "businessOwner" },
    { uid: "admin_test_1", email: "admin@test.com", displayName: "Admin ShinraCity", role: "admin" },
  ];

  for (const u of users) {
    try {
      await auth.createUser({
        uid: u.uid,
        email: u.email,
        password: "Test1234!",
        displayName: u.displayName,
        emailVerified: true,
      });
    } catch (e: any) {
      if (e.code !== "auth/uid-already-exists") throw e;
    }

    await db.collection("users").doc(u.uid).set({
      id: u.uid,
      email: u.email,
      displayName: u.displayName,
      role: u.role,
      level: "explorer",
      totalPoints: u.role === "user" ? 350 : 0,
      availablePoints: u.role === "user" ? 350 : 0,
      totalCouponsRedeemed: u.role === "user" ? 4 : 0,
      totalSavings: u.role === "user" ? 1200 : 0,
      favoriteCommerceIds: [],
      followingCommerceIds: [],
      followingCategories: [],
      badgeIds: [],
      achievementIds: [],
      isActive: true,
      isVerified: u.email.includes("admin"),
      notificationsEnabled: true,
      locationEnabled: true,
      authProvider: "email",
      createdAt: now,
      lastActiveAt: now,
    });
  }
  console.log("  ✓ 5 users created");
}

// ─── Commerces ────────────────────────────────────────────────────────────────
async function seedCommerces() {
  console.log("🏪 Seeding commerces...");

  const commerces = [
    {
      id: "commerce_cafe_1",
      ownerId: "business_test_1",
      name: "Café del Barrio",
      description: "El mejor café de especialidad en Palermo. Granos de origen seleccionados, baristas apasionados.",
      category: "cafes",
      address: "Thames 1850, Palermo, Buenos Aires",
      phone: "+541112345678",
      ...LOCATIONS.palermo,
      rating: 4.7,
      totalReviews: 142,
      plan: "premium",
      status: "verified",
      followerCount: 89,
      totalCouponsRedeemed: 234,
      isCurrentlyOpen: true,
      businessHours: {
        monday:    { isOpen: true, openTime: "08:00", closeTime: "20:00" },
        tuesday:   { isOpen: true, openTime: "08:00", closeTime: "20:00" },
        wednesday: { isOpen: true, openTime: "08:00", closeTime: "20:00" },
        thursday:  { isOpen: true, openTime: "08:00", closeTime: "20:00" },
        friday:    { isOpen: true, openTime: "08:00", closeTime: "21:00" },
        saturday:  { isOpen: true, openTime: "09:00", closeTime: "21:00" },
        sunday:    { isOpen: false, openTime: null,   closeTime: null },
      },
      galleryUrls: [],
      logoUrl: null,
      tags: ["café", "especialidad", "desayuno", "merienda"],
    },
    {
      id: "commerce_tech_1",
      ownerId: "business_test_2",
      name: "TechStore BA",
      description: "Accesorios, gadgets y electrónica al mejor precio. Garantía oficial y servicio técnico.",
      category: "technology",
      address: "Santa Fe 3240, Recoleta, Buenos Aires",
      phone: "+541198765432",
      ...LOCATIONS.recoleta,
      rating: 4.3,
      totalReviews: 67,
      plan: "basic",
      status: "verified",
      followerCount: 34,
      totalCouponsRedeemed: 89,
      isCurrentlyOpen: true,
      businessHours: {
        monday:    { isOpen: true, openTime: "10:00", closeTime: "20:00" },
        tuesday:   { isOpen: true, openTime: "10:00", closeTime: "20:00" },
        wednesday: { isOpen: true, openTime: "10:00", closeTime: "20:00" },
        thursday:  { isOpen: true, openTime: "10:00", closeTime: "20:00" },
        friday:    { isOpen: true, openTime: "10:00", closeTime: "20:00" },
        saturday:  { isOpen: true, openTime: "10:00", closeTime: "18:00" },
        sunday:    { isOpen: false, openTime: null,   closeTime: null },
      },
      galleryUrls: [],
      logoUrl: null,
      tags: ["tecnología", "gadgets", "accesorios"],
    },
    {
      id: "commerce_resto_1",
      ownerId: "business_test_1",
      name: "La Parrilla de San Telmo",
      description: "Carnes premium a la parrilla, vista al casco histórico. Reservas recomendadas los fines de semana.",
      category: "restaurants",
      address: "Defensa 890, San Telmo, Buenos Aires",
      phone: "+541145678901",
      ...LOCATIONS.sanTelmo,
      rating: 4.9,
      totalReviews: 312,
      plan: "enterprise",
      status: "verified",
      followerCount: 215,
      totalCouponsRedeemed: 567,
      isCurrentlyOpen: true,
      businessHours: {
        monday:    { isOpen: false, openTime: null,   closeTime: null },
        tuesday:   { isOpen: true, openTime: "12:00", closeTime: "23:00" },
        wednesday: { isOpen: true, openTime: "12:00", closeTime: "23:00" },
        thursday:  { isOpen: true, openTime: "12:00", closeTime: "23:00" },
        friday:    { isOpen: true, openTime: "12:00", closeTime: "24:00" },
        saturday:  { isOpen: true, openTime: "12:00", closeTime: "24:00" },
        sunday:    { isOpen: true, openTime: "12:00", closeTime: "22:00" },
      },
      galleryUrls: [],
      logoUrl: null,
      tags: ["parrilla", "carnes", "tradicional", "almuerzo", "cena"],
    },
    {
      id: "commerce_farm_1",
      ownerId: "business_test_2",
      name: "Farmacia Belgrano",
      description: "Farmacia de barrio con más de 30 años. Medicamentos, cosmética y asesoramiento farmacéutico.",
      category: "pharmacies",
      address: "Cabildo 2150, Belgrano, Buenos Aires",
      phone: "+541156789012",
      ...LOCATIONS.belgrano,
      rating: 4.5,
      totalReviews: 48,
      plan: "free",
      status: "active",
      followerCount: 12,
      totalCouponsRedeemed: 23,
      isCurrentlyOpen: true,
      businessHours: {
        monday:    { isOpen: true, openTime: "08:00", closeTime: "22:00" },
        tuesday:   { isOpen: true, openTime: "08:00", closeTime: "22:00" },
        wednesday: { isOpen: true, openTime: "08:00", closeTime: "22:00" },
        thursday:  { isOpen: true, openTime: "08:00", closeTime: "22:00" },
        friday:    { isOpen: true, openTime: "08:00", closeTime: "22:00" },
        saturday:  { isOpen: true, openTime: "09:00", closeTime: "21:00" },
        sunday:    { isOpen: true, openTime: "10:00", closeTime: "20:00" },
      },
      galleryUrls: [],
      logoUrl: null,
      tags: ["farmacia", "salud", "medicamentos"],
    },
  ];

  for (const c of commerces) {
    const { lat, lng, ...rest } = c as any;
    await db.collection("commerces").doc(c.id).set({
      ...rest,
      location: new admin.firestore.GeoPoint(lat, lng),
      locationGeohash: geohash(lat, lng),
      subCategories: [],
      createdAt: past(30),
      updatedAt: now,
    });
  }
  console.log(`  ✓ ${commerces.length} commerces created`);
}

// ─── Promotions ───────────────────────────────────────────────────────────────
async function seedPromotions() {
  console.log("🎉 Seeding promotions...");

  const promotions = [
    {
      id: "promo_1",
      commerceId: "commerce_cafe_1",
      commerceName: "Café del Barrio",
      title: "2x1 en cafés de especialidad",
      description: "Pedí dos cafés y pagá solo uno. Válido para todas las variedades del menú.",
      type: "twoForOne",
      status: "active",
      discountType: "twoForOne",
      discountValue: 0,
      originalPrice: 1800,
      discountedPrice: 1800,
      startDate: past(1),
      endDate: future(7),
      totalSlots: 50,
      usedSlots: 12,
      perUserLimit: 1,
      isExclusiveForFollowers: false,
      isVip: false,
      requiresCode: false,
      pointsAwarded: 15,
      imageUrls: [],
      categories: ["cafés"],
      conditions: "Un canje por persona por día. No acumulable con otras promos.",
    },
    {
      id: "promo_2",
      commerceId: "commerce_cafe_1",
      commerceName: "Café del Barrio",
      title: "Happy Hour 15-17hs",
      description: "Todos los días de 15 a 17hs, 30% de descuento en bebidas frías.",
      type: "happyHour",
      status: "active",
      discountType: "percentage",
      discountValue: 30,
      originalPrice: 2200,
      discountedPrice: 1540,
      startDate: past(5),
      endDate: future(30),
      totalSlots: null,
      usedSlots: 78,
      perUserLimit: 2,
      isExclusiveForFollowers: true,
      isVip: false,
      requiresCode: false,
      pointsAwarded: 10,
      imageUrls: [],
      categories: ["cafés", "bebidas"],
      conditions: "Solo válido entre 15:00 y 17:00hs.",
    },
    {
      id: "promo_3",
      commerceId: "commerce_tech_1",
      commerceName: "TechStore BA",
      title: "20% off en accesorios",
      description: "Descuento en fundas, cables, auriculares y más. Renovamos stock semanalmente.",
      type: "discount",
      status: "active",
      discountType: "percentage",
      discountValue: 20,
      originalPrice: 0,
      discountedPrice: 0,
      startDate: past(2),
      endDate: future(14),
      totalSlots: 100,
      usedSlots: 31,
      perUserLimit: 3,
      isExclusiveForFollowers: false,
      isVip: false,
      requiresCode: false,
      pointsAwarded: 20,
      imageUrls: [],
      categories: ["tecnología"],
      conditions: "Descuento aplicable en productos seleccionados.",
    },
    {
      id: "promo_4",
      commerceId: "commerce_resto_1",
      commerceName: "La Parrilla de San Telmo",
      title: "Postre gratis con menú ejecutivo",
      description: "Pedí el menú ejecutivo del mediodía y llevate un postre de cortesía.",
      type: "freeItem",
      status: "active",
      discountType: "freeItem",
      discountValue: 0,
      originalPrice: 8500,
      discountedPrice: 8500,
      startDate: past(3),
      endDate: future(21),
      totalSlots: 30,
      usedSlots: 8,
      perUserLimit: 1,
      isExclusiveForFollowers: false,
      isVip: true,
      requiresCode: false,
      pointsAwarded: 25,
      imageUrls: [],
      categories: ["restaurantes", "almuerzo"],
      conditions: "Válido de martes a viernes al mediodía (12-15hs).",
    },
  ];

  for (const p of promotions) {
    await db.collection("promotions").doc(p.id).set({
      ...p,
      promoCode: null,
      remainingSlots: p.totalSlots ? p.totalSlots - p.usedSlots : null,
      createdAt: past(5),
      updatedAt: now,
    });
  }
  console.log(`  ✓ ${promotions.length} promotions created`);
}

// ─── Points / Rewards ─────────────────────────────────────────────────────────
async function seedPoints() {
  console.log("⭐ Seeding points...");

  await db.collection("points").doc("user_test_1").set({
    userId: "user_test_1",
    totalPoints: 350,
    availablePoints: 350,
    level: "explorer",
    totalCouponsRedeemed: 4,
    totalSavings: 1200,
    history: [
      { type: "earned", amount: 15, description: "Cupón canjeado - 2x1 Café", date: past(1) },
      { type: "earned", amount: 10, description: "Cupón canjeado - Happy Hour", date: past(3) },
      { type: "earned", amount: 20, description: "Cupón canjeado - 20% TechStore", date: past(7) },
      { type: "earned", amount: 25, description: "Cupón canjeado - Parrilla", date: past(10) },
    ],
    createdAt: past(30),
    updatedAt: now,
  });

  await db.collection("points").doc("user_test_2").set({
    userId: "user_test_2",
    totalPoints: 820,
    availablePoints: 820,
    level: "frequent",
    totalCouponsRedeemed: 11,
    totalSavings: 4350,
    history: [],
    createdAt: past(60),
    updatedAt: now,
  });

  console.log("  ✓ Points seeded for 2 users");
}

// ─── Leaderboard ──────────────────────────────────────────────────────────────
async function seedLeaderboard() {
  console.log("🏆 Seeding leaderboard...");

  const entries = [
    { userId: "user_test_2", displayName: "Juan Pérez", points: 820, level: "frequent", rank: 1 },
    { userId: "user_test_1", displayName: "María García", points: 350, level: "explorer", rank: 2 },
  ];

  const snapshot = { period: "global", entries, updatedAt: now };
  await db.collection("leaderboard").doc("global_current").set(snapshot);
  console.log("  ✓ Leaderboard snapshot created");
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log("🌱 ShinraCity — seeding emulator data\n");
  try {
    await seedUsers();
    await seedCommerces();
    await seedPromotions();
    await seedPoints();
    await seedLeaderboard();
    console.log("\n✅ Seed complete! Emulators ready at http://localhost:4000");
  } catch (err) {
    console.error("❌ Seed failed:", err);
    process.exit(1);
  }
}

main();
