import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, collection, query, orderBy, limit, getDocs,
  runTransaction, writeBatch, serverTimestamp, increment,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'shinra-city',
  firestore: {
    rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    host: '127.0.0.1', port: 8080,
  },
});

let pass = 0, fail = 0;
async function t(name, fn) {
  try { await fn(); pass++; console.log('OK   ', name); }
  catch (e) { fail++; console.log('FAIL ', name, '-', e.message.split('\n')[0]); }
}

const seed = async (path, data) =>
  env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), path), data));

await env.clearFirestore();
await seed('users/u1', { email: 'u1@x.com', role: 'user', totalPoints: 495, availablePoints: 100, totalCouponsRedeemed: 3, level: 'explorer' });
await seed('users/u2', { email: 'u2@x.com', role: 'user', totalPoints: 0, availablePoints: 0, level: 'explorer' });
await seed('commerces/shop1', { ownerId: 'owner1', name: 'Shop' });
await seed('coupons/c_used', { userId: 'u1', commerceId: 'shop1', promotionId: 'p1', status: 'used' });
await seed('coupons/c_avail', { userId: 'u1', commerceId: 'shop1', promotionId: 'p1', status: 'available' });
await seed('coupons/c_other', { userId: 'u2', commerceId: 'shop1', promotionId: 'p1', status: 'used' });
await seed('config/plans', { free: 0 });
await seed('config/secret', { x: 1 });

const u1 = env.authenticatedContext('u1', { email: 'u1@x.com' }).firestore();
const u2 = env.authenticatedContext('u2', { email: 'u2@x.com' }).firestore();
const nu = env.authenticatedContext('newbie', { email: 'new@x.com' }).firestore();
const adm = env.authenticatedContext('admin1', { email: 'admin@shinracity.com' }).firestore();
const anon = env.unauthenticatedContext().firestore();

// --- alta de perfil
await t('registro normal', () => assertSucceeds(setDoc(doc(nu, 'users/newbie'), { email: 'new@x.com', role: 'user', totalPoints: 0, availablePoints: 0, level: 'explorer', isVerified: false })));
await t('registro como negocio', async () => {
  const c = env.authenticatedContext('biz', { email: 'biz@x.com' }).firestore();
  await assertSucceeds(setDoc(doc(c, 'users/biz'), { role: 'businessOwner', totalPoints: 0, availablePoints: 0, level: 'explorer' }));
});
await t('registro como superAdmin -> bloqueado', async () => {
  const c = env.authenticatedContext('evil', { email: 'evil@x.com' }).firestore();
  await assertFails(setDoc(doc(c, 'users/evil'), { role: 'superAdmin', totalPoints: 0 }));
});
await t('registro con puntos -> bloqueado', async () => {
  const c = env.authenticatedContext('evil2', { email: 'e2@x.com' }).firestore();
  await assertFails(setDoc(doc(c, 'users/evil2'), { role: 'user', totalPoints: 9999 }));
});

// --- ediciÃ³n de perfil
await t('editar su nombre', () => assertSucceeds(updateDoc(doc(u1, 'users/u1'), { displayName: 'Juan' })));
await t('subirse puntos -> bloqueado', () => assertFails(updateDoc(doc(u1, 'users/u1'), { totalPoints: 99999 })));
await t('subirse availablePoints -> bloqueado', () => assertFails(updateDoc(doc(u1, 'users/u1'), { availablePoints: 9999 })));
await t('gastar puntos', () => assertSucceeds(updateDoc(doc(u1, 'users/u1'), { availablePoints: increment(-50) })));
await t('ponerse admin -> bloqueado', () => assertFails(updateDoc(doc(u1, 'users/u1'), { role: 'superAdmin' })));
await t('admin cambia rol de otro', () => assertSucceeds(updateDoc(doc(adm, 'users/u2'), { isActive: true })));
await t('leer perfil ajeno -> bloqueado', () => assertFails(getDoc(doc(u2, 'users/u1'))));

// --- cobrar puntos de cupÃ³n (mismo flujo que FirebaseCouponDatasource.claimCouponPoints)
async function claim(db, uid, couponId, pts = 10) {
  return runTransaction(db, async (tx) => {
    const txRef = doc(db, 'points_transactions', 'coupon_' + couponId);
    if ((await tx.get(txRef)).exists()) return 0;
    const userRef = doc(db, 'users', uid);
    const u = (await tx.get(userRef)).data();
    const total = (u.totalPoints ?? 0) + pts;
    const level = total >= 500 ? 'frequent' : 'explorer';
    tx.update(userRef, {
      totalPoints: total, availablePoints: (u.availablePoints ?? 0) + pts,
      totalCouponsRedeemed: (u.totalCouponsRedeemed ?? 0) + 1, level,
      lastPointsCouponId: couponId, updatedAt: serverTimestamp(),
    });
    tx.set(txRef, { userId: uid, points: pts, type: 'earned', reason: 'CupÃ³n canjeado', couponId, balanceAfter: 0, createdAt: serverTimestamp() });
    tx.set(doc(db, 'public_profiles', uid), { totalPoints: total, level, updatedAt: serverTimestamp() }, { merge: true });
    return pts;
  });
}
await t('cobrar cupÃ³n canjeado (+10, sube a frequent)', async () => {
  const r = await assertSucceeds(claim(u1, 'u1', 'c_used'));
  if (r !== 10) throw new Error('devolviÃ³ ' + r);
  const u = (await getDoc(doc(u1, 'users/u1'))).data();
  if (u.totalPoints !== 505 || u.level !== 'frequent' || u.totalCouponsRedeemed !== 4) throw new Error(JSON.stringify(u));
});
await t('cobrar el mismo cupÃ³n otra vez -> 0', async () => {
  const r = await claim(u1, 'u1', 'c_used');
  if (r !== 0) throw new Error('devolviÃ³ ' + r);
});
await t('forzar cobro repetido sin leer -> bloqueado', () => assertFails((async () => {
  const b = writeBatch(u1);
  b.update(doc(u1, 'users/u1'), { totalPoints: 515, availablePoints: 70, totalCouponsRedeemed: 5, level: 'frequent', lastPointsCouponId: 'c_used' });
  b.set(doc(u1, 'points_transactions/coupon_c_used'), { userId: 'u1', points: 10, type: 'earned', couponId: 'c_used' });
  await b.commit();
})()));
await t('cobrar cupÃ³n sin canjear -> bloqueado', () => assertFails(claim(u1, 'u1', 'c_avail')));
await t('cobrar cupÃ³n ajeno -> bloqueado', () => assertFails(claim(u1, 'u1', 'c_other')));
await t('cobrar 1000 puntos -> bloqueado', () => assertFails(claim(u2, 'u2', 'c_other', 1000)));
await t('dueÃ±o del cupÃ³n ajeno sÃ­ cobra', () => assertSucceeds(claim(u2, 'u2', 'c_other')));
await t('crear movimiento positivo suelto -> bloqueado', () => assertFails(setDoc(doc(u1, 'points_transactions/x1'), { userId: 'u1', points: 500, type: 'earned' })));
await t('registrar gasto', () => assertSucceeds(setDoc(doc(u1, 'points_transactions/x2'), { userId: 'u1', points: -50, type: 'redeemed' })));
await t('leer movimiento ajeno -> bloqueado', () => assertFails(getDoc(doc(u2, 'points_transactions/coupon_c_used'))));

// --- perfil pÃºblico / ranking
await t('publicar perfil con puntos reales', () => assertSucceeds(setDoc(doc(u2, 'public_profiles/u2'), { displayName: 'B', photoUrl: null, totalPoints: 10, level: 'explorer', achievementCount: 0, updatedAt: serverTimestamp() })));
await t('perfil pÃºblico con puntos falsos -> bloqueado', () => assertFails(setDoc(doc(u2, 'public_profiles/u2'), { displayName: 'B', totalPoints: 99999, level: 'explorer' })));
await t('perfil pÃºblico con email -> bloqueado', () => assertFails(setDoc(doc(u2, 'public_profiles/u2'), { totalPoints: 10, level: 'explorer', email: 'u2@x.com' })));
await t('perfil pÃºblico de otro -> bloqueado', () => assertFails(setDoc(doc(u2, 'public_profiles/u1'), { totalPoints: 505, level: 'frequent' })));
await t('ranking', () => assertSucceeds(getDocs(query(collection(u1, 'public_profiles'), orderBy('totalPoints', 'desc'), limit(50)))));
await t('ranking sin sesiÃ³n -> bloqueado', () => assertFails(getDocs(query(collection(anon, 'public_profiles'), limit(5)))));

// --- Ã­ndice de emails
await t('registrar su email', () => assertSucceeds(setDoc(doc(u1, 'user_emails/u1@x.com'), { uid: 'u1' })));
await t('registrar email ajeno -> bloqueado', () => assertFails(setDoc(doc(u2, 'user_emails/u1@x.com'), { uid: 'u2' })));
await t('buscar email exacto', () => assertSucceeds(getDoc(doc(u2, 'user_emails/u1@x.com'))));
await t('listar emails -> bloqueado', () => assertFails(getDocs(collection(u2, 'user_emails'))));

// --- config / admin
await t('comercio lee config/plans', () => assertSucceeds(getDoc(doc(u1, 'config/plans'))));
await t('leer otra config -> bloqueado', () => assertFails(getDoc(doc(u1, 'config/secret'))));
await t('admin lee audit_logs', () => assertSucceeds(getDocs(collection(adm, 'audit_logs'))));
await t('usuario lee audit_logs -> bloqueado', () => assertFails(getDocs(collection(u1, 'audit_logs'))));

console.log(`\n${pass} ok, ${fail} fallas`);
await env.cleanup();
process.exit(fail ? 1 : 0);
