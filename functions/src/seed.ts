/**
 * Emulator seed script — populates local Firestore + Auth with test data.
 *
 * Usage (from the functions/ directory):
 *   npm run seed
 *
 * Requires Firebase emulators running:
 *   firebase emulators:start
 */

process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099";

import * as admin from "firebase-admin";

admin.initializeApp({ projectId: "shinra-city" });

const db = admin.firestore();
const auth = admin.auth();

// ─── Helpers ─────────────────────────────────────────────────────────────────

function geohash(lat: number, lng: number, precision = 7): string {
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
}

const now = admin.firestore.Timestamp.now();
const future = (days: number) =>
  admin.firestore.Timestamp.fromDate(new Date(Date.now() + days * 86400000));
const past = (days: number) =>
  admin.firestore.Timestamp.fromDate(new Date(Date.now() - days * 86400000));

// ─── Auth + Firestore users ───────────────────────────────────────────────────

async function seedUsers() {
  console.log("👤  Seeding users...");

  const users = [
    {
      uid: "user_test_1",
      email: "user1@test.com",
      displayName: "María García",
      role: "user",
      level: "explorer",
      totalPoints: 350,
      availablePoints: 350,
      totalCouponsRedeemed: 4,
      totalSavings: 1200,
    },
    {
      uid: "user_test_2",
      email: "user2@test.com",
      displayName: "Juan Pérez",
      role: "user",
      level: "frequent",
      totalPoints: 820,
      availablePoints: 820,
      totalCouponsRedeemed: 11,
      totalSavings: 4350,
    },
    {
      uid: "business_test_1",
      email: "biz1@test.com",
      displayName: "Café Palermo",
      role: "businessOwner",
      level: "explorer",
      totalPoints: 0,
      availablePoints: 0,
      totalCouponsRedeemed: 0,
      totalSavings: 0,
    },
    {
      uid: "business_test_2",
      email: "biz2@test.com",
      displayName: "Tech Store BA",
      role: "businessOwner",
      level: "explorer",
      totalPoints: 0,
      availablePoints: 0,
      totalCouponsRedeemed: 0,
      totalSavings: 0,
    },
    {
      uid: "admin_test_1",
      email: "admin@test.com",
      displayName: "Admin ShinraCity",
      role: "admin",
      level: "lifetime",
      totalPoints: 9999,
      availablePoints: 9999,
      totalCouponsRedeemed: 0,
      totalSavings: 0,
    },
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
      level: u.level,
      totalPoints: u.totalPoints,
      availablePoints: u.availablePoints,
      totalCouponsRedeemed: u.totalCouponsRedeemed,
      totalSavings: u.totalSavings,
      favoriteCommerceIds: [],
      followingCommerceIds: [],
      followingCategories: [],
      badgeIds: [],
      achievementIds: [],
      isActive: true,
      isVerified: u.role === "admin",
      notificationsEnabled: true,
      locationEnabled: true,
      authProvider: "email",
      createdAt: now,
      lastActiveAt: now,
    });
  }
  console.log(`    ✓ ${users.length} users`);
}

// ─── Commerces ────────────────────────────────────────────────────────────────

async function seedCommerces() {
  console.log("🏪  Seeding commerces...");

  type Hours = {
    isOpen: boolean;
    openTime: string | null;
    closeTime: string | null;
  };
  type Commerce = {
    id: string;
    ownerId: string;
    name: string;
    description: string;
    category: string;
    address: string;
    phone: string;
    lat: number;
    lng: number;
    rating: number;
    totalReviews: number;
    plan: string;
    status: string;
    followerCount: number;
    totalCouponsRedeemed: number;
    isCurrentlyOpen: boolean;
    businessHours: { [day: string]: Hours };
    tags: string[];
  };

  const open = (o: string, c: string): Hours => ({
    isOpen: true,
    openTime: o,
    closeTime: c,
  });
  const closed: Hours = { isOpen: false, openTime: null, closeTime: null };

  const commerces: Commerce[] = [
    {
      id: "commerce_cafe_1",
      ownerId: "business_test_1",
      name: "Café del Barrio",
      description:
        "El mejor café de especialidad en Palermo. Granos de origen seleccionados, baristas apasionados.",
      category: "cafes",
      address: "Thames 1850, Palermo, Buenos Aires",
      phone: "+541112345678",
      lat: -34.5871,
      lng: -58.4328,
      rating: 4.7,
      totalReviews: 142,
      plan: "premium",
      status: "verified",
      followerCount: 89,
      totalCouponsRedeemed: 234,
      isCurrentlyOpen: true,
      businessHours: {
        monday: open("08:00", "20:00"),
        tuesday: open("08:00", "20:00"),
        wednesday: open("08:00", "20:00"),
        thursday: open("08:00", "20:00"),
        friday: open("08:00", "21:00"),
        saturday: open("09:00", "21:00"),
        sunday: closed,
      },
      tags: ["café", "especialidad", "desayuno", "merienda"],
    },
    {
      id: "commerce_tech_1",
      ownerId: "business_test_2",
      name: "TechStore BA",
      description:
        "Accesorios, gadgets y electrónica al mejor precio. Garantía oficial y servicio técnico.",
      category: "technology",
      address: "Santa Fe 3240, Recoleta, Buenos Aires",
      phone: "+541198765432",
      lat: -34.5875,
      lng: -58.3944,
      rating: 4.3,
      totalReviews: 67,
      plan: "basic",
      status: "verified",
      followerCount: 34,
      totalCouponsRedeemed: 89,
      isCurrentlyOpen: true,
      businessHours: {
        monday: open("10:00", "20:00"),
        tuesday: open("10:00", "20:00"),
        wednesday: open("10:00", "20:00"),
        thursday: open("10:00", "20:00"),
        friday: open("10:00", "20:00"),
        saturday: open("10:00", "18:00"),
        sunday: closed,
      },
      tags: ["tecnología", "gadgets", "accesorios"],
    },
    {
      id: "commerce_resto_1",
      ownerId: "business_test_1",
      name: "La Parrilla de San Telmo",
      description:
        "Carnes premium a la parrilla, vista al casco histórico. Reservas recomendadas los fines de semana.",
      category: "restaurants",
      address: "Defensa 890, San Telmo, Buenos Aires",
      phone: "+541145678901",
      lat: -34.6216,
      lng: -58.3731,
      rating: 4.9,
      totalReviews: 312,
      plan: "enterprise",
      status: "verified",
      followerCount: 215,
      totalCouponsRedeemed: 567,
      isCurrentlyOpen: true,
      businessHours: {
        monday: closed,
        tuesday: open("12:00", "23:00"),
        wednesday: open("12:00", "23:00"),
        thursday: open("12:00", "23:00"),
        friday: open("12:00", "24:00"),
        saturday: open("12:00", "24:00"),
        sunday: open("12:00", "22:00"),
      },
      tags: ["parrilla", "carnes", "tradicional", "almuerzo", "cena"],
    },
    {
      id: "commerce_farm_1",
      ownerId: "business_test_2",
      name: "Farmacia Belgrano",
      description:
        "Farmacia de barrio con más de 30 años. Medicamentos, cosmética y asesoramiento farmacéutico.",
      category: "pharmacies",
      address: "Cabildo 2150, Belgrano, Buenos Aires",
      phone: "+541156789012",
      lat: -34.5575,
      lng: -58.4592,
      rating: 4.5,
      totalReviews: 48,
      plan: "free",
      status: "active",
      followerCount: 12,
      totalCouponsRedeemed: 23,
      isCurrentlyOpen: true,
      businessHours: {
        monday: open("08:00", "22:00"),
        tuesday: open("08:00", "22:00"),
        wednesday: open("08:00", "22:00"),
        thursday: open("08:00", "22:00"),
        friday: open("08:00", "22:00"),
        saturday: open("09:00", "21:00"),
        sunday: open("10:00", "20:00"),
      },
      tags: ["farmacia", "salud", "medicamentos"],
    },
    {
      id: "commerce_gym_1",
      ownerId: "business_test_1",
      name: "FitZone Caballito",
      description:
        "Gimnasio equipado con pesas libres, máquinas cardio y clases grupales. Acceso 24/7.",
      category: "sports",
      address: "Rivadavia 5400, Caballito, Buenos Aires",
      phone: "+541167890123",
      lat: -34.6188,
      lng: -58.4572,
      rating: 4.1,
      totalReviews: 95,
      plan: "basic",
      status: "active",
      followerCount: 67,
      totalCouponsRedeemed: 44,
      isCurrentlyOpen: true,
      businessHours: {
        monday: open("06:00", "23:00"),
        tuesday: open("06:00", "23:00"),
        wednesday: open("06:00", "23:00"),
        thursday: open("06:00", "23:00"),
        friday: open("06:00", "22:00"),
        saturday: open("08:00", "20:00"),
        sunday: open("09:00", "18:00"),
      },
      tags: ["gimnasio", "fitness", "crossfit", "musculación"],
    },
  ];

  for (const c of commerces) {
    const { lat, lng, ...rest } = c;
    await db
      .collection("commerces")
      .doc(c.id)
      .set({
        ...rest,
        location: new admin.firestore.GeoPoint(lat, lng),
        locationGeohash: geohash(lat, lng),
        subCategories: [],
        galleryUrls: [],
        logoUrl: null,
        createdAt: past(30),
        updatedAt: now,
      });
  }
  console.log(`    ✓ ${commerces.length} commerces`);
}

// ─── Promotions ───────────────────────────────────────────────────────────────

async function seedPromotions() {
  console.log("🎉  Seeding promotions...");

  const promotions = [
    {
      id: "promo_1",
      commerceId: "commerce_cafe_1",
      commerceName: "Café del Barrio",
      title: "2x1 en cafés de especialidad",
      description:
        "Pedí dos cafés y pagá solo uno. Válido para todas las variedades.",
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
      remainingSlots: 38,
      perUserLimit: 1,
      isExclusiveForFollowers: false,
      isVip: false,
      requiresCode: false,
      promoCode: null,
      pointsAwarded: 15,
      imageUrls: [],
      categories: ["cafés"],
      conditions: "Un canje por persona por día.",
    },
    {
      id: "promo_2",
      commerceId: "commerce_cafe_1",
      commerceName: "Café del Barrio",
      title: "Happy Hour 15–17hs",
      description: "Todos los días de 15 a 17hs, 30% en bebidas frías.",
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
      remainingSlots: null,
      perUserLimit: 2,
      isExclusiveForFollowers: true,
      isVip: false,
      requiresCode: false,
      promoCode: null,
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
      description: "Descuento en fundas, cables, auriculares y más.",
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
      remainingSlots: 69,
      perUserLimit: 3,
      isExclusiveForFollowers: false,
      isVip: false,
      requiresCode: false,
      promoCode: null,
      pointsAwarded: 20,
      imageUrls: [],
      categories: ["tecnología"],
      conditions: "Descuento en productos seleccionados.",
    },
    {
      id: "promo_4",
      commerceId: "commerce_resto_1",
      commerceName: "La Parrilla de San Telmo",
      title: "Postre gratis con menú ejecutivo",
      description: "Pedí el menú ejecutivo y llevate un postre de cortesía.",
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
      remainingSlots: 22,
      perUserLimit: 1,
      isExclusiveForFollowers: false,
      isVip: true,
      requiresCode: false,
      promoCode: null,
      pointsAwarded: 25,
      imageUrls: [],
      categories: ["restaurantes", "almuerzo"],
      conditions: "Válido mar–vie al mediodía (12–15hs).",
    },
    {
      id: "promo_5",
      commerceId: "commerce_gym_1",
      commerceName: "FitZone Caballito",
      title: "Primer mes 50% off",
      description: "Para nuevos socios: primer mes de membresía al 50%.",
      type: "discount",
      status: "active",
      discountType: "percentage",
      discountValue: 50,
      originalPrice: 12000,
      discountedPrice: 6000,
      startDate: past(1),
      endDate: future(15),
      totalSlots: 20,
      usedSlots: 7,
      remainingSlots: 13,
      perUserLimit: 1,
      isExclusiveForFollowers: false,
      isVip: false,
      requiresCode: true,
      promoCode: "NUEVO50",
      pointsAwarded: 50,
      imageUrls: [],
      categories: ["deportes", "gimnasio"],
      conditions: "Solo para nuevos socios. Requiere código NUEVO50 al inscribirse.",
    },
  ];

  for (const p of promotions) {
    await db
      .collection("promotions")
      .doc(p.id)
      .set({ ...p, createdAt: past(5), updatedAt: now });
  }
  console.log(`    ✓ ${promotions.length} promotions`);
}

// ─── Points ───────────────────────────────────────────────────────────────────

async function seedPoints() {
  console.log("⭐  Seeding points...");

  const pointsData = [
    {
      userId: "user_test_1",
      totalPoints: 350,
      availablePoints: 350,
      level: "explorer",
      totalCouponsRedeemed: 4,
      totalSavings: 1200,
      history: [
        {
          type: "earned",
          amount: 15,
          description: "Cupón - 2x1 Café del Barrio",
          date: past(1),
        },
        {
          type: "earned",
          amount: 10,
          description: "Cupón - Happy Hour Café",
          date: past(3),
        },
        {
          type: "earned",
          amount: 20,
          description: "Cupón - 20% TechStore",
          date: past(7),
        },
        {
          type: "earned",
          amount: 25,
          description: "Cupón - Postre gratis Parrilla",
          date: past(10),
        },
      ],
    },
    {
      userId: "user_test_2",
      totalPoints: 820,
      availablePoints: 820,
      level: "frequent",
      totalCouponsRedeemed: 11,
      totalSavings: 4350,
      history: [],
    },
  ];

  for (const p of pointsData) {
    await db
      .collection("points")
      .doc(p.userId)
      .set({ ...p, createdAt: past(60), updatedAt: now });
  }
  console.log("    ✓ Points for 2 users");
}

// ─── Leaderboard ──────────────────────────────────────────────────────────────

async function seedLeaderboard() {
  console.log("🏆  Seeding leaderboard...");

  await db.collection("leaderboard").doc("global_current").set({
    period: "global",
    updatedAt: now,
    entries: [
      {
        userId: "user_test_2",
        displayName: "Juan Pérez",
        points: 820,
        level: "frequent",
        rank: 1,
      },
      {
        userId: "user_test_1",
        displayName: "María García",
        points: 350,
        level: "explorer",
        rank: 2,
      },
    ],
  });
  console.log("    ✓ Leaderboard snapshot");
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log("\n🌱  ShinraCity — seeding emulator data\n");
  try {
    await seedUsers();
    await seedCommerces();
    await seedPromotions();
    await seedPoints();
    await seedLeaderboard();
    console.log(
      "\n✅  Seed complete! Open http://localhost:4000 to inspect the data.\n"
    );
  } catch (err) {
    console.error("\n❌  Seed failed:", err);
    process.exit(1);
  }
}

main();
