import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/coupon_generator.dart';
import '../../../domain/entities/coupon_entity.dart';

class FirebaseCouponDatasource {
  final FirebaseFirestore _firestore;

  FirebaseCouponDatasource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  Future<Map<String, dynamic>> claimCoupon({
    required String userId,
    required String promotionId,
    required String deviceId,
  }) async {
    return await _firestore.runTransaction((transaction) async {
      // Check eligibility with transaction
      final promotionRef = _firestore
          .collection(AppConstants.promotionsCollection)
          .doc(promotionId);

      final promotionDoc = await transaction.get(promotionRef);
      if (!promotionDoc.exists) {
        throw const NotFoundFailure(message: 'Promoción no encontrada');
      }

      final promotionData = promotionDoc.data()!;

      // Validate promotion is active
      if (promotionData['status'] != 'active') {
        throw const CouponFailure(message: 'Esta promoción ya no está activa');
      }

      // Validate promotion dates
      final endDate = (promotionData['endDate'] as Timestamp).toDate();
      if (DateTime.now().isAfter(endDate)) {
        throw const CouponFailure(message: 'Esta promoción ha expirado');
      }

      // Check available slots
      final totalSlots = promotionData['totalSlots'] as int?;
      final usedSlots = promotionData['usedSlots'] as int? ?? 0;
      if (totalSlots != null && usedSlots >= totalSlots) {
        throw const CouponFailure(message: 'No hay cupos disponibles');
      }

      // Check per-user limit — fetch by userId+promotionId, filter status in Dart
      final perUserLimit = promotionData['perUserLimit'] as int? ?? 1;
      final existingSnap = await _firestore
          .collection(AppConstants.couponsCollection)
          .where('userId', isEqualTo: userId)
          .where('promotionId', isEqualTo: promotionId)
          .get();

      final activeCount = existingSnap.docs.where((d) {
        final s = (d.data())['status'] as String?;
        return s != 'cancelled' && s != 'expired';
      }).length;

      if (activeCount >= perUserLimit) {
        throw const CouponFailure(message: 'Ya reclamaste el máximo de cupones para esta promoción');
      }

      // Antifraud: fingerprint already encodes userId+deviceId+promotionId — single field query
      final fingerprint = CouponGenerator.generateAntifraudFingerprint(
        userId: userId,
        deviceId: deviceId,
        promotionId: promotionId,
      );

      final fraudCheck = await _firestore
          .collection(AppConstants.couponsCollection)
          .where('userId', isEqualTo: userId)
          .where('deviceFingerprint', isEqualTo: fingerprint)
          .count()
          .get();

      if (fraudCheck.count! > 0) {
        throw const FraudDetectedFailure();
      }

      // Generate coupon
      final couponId = CouponGenerator.generateUniqueId();
      final expiresAt = DateTime.now().add(
        Duration(days: AppConstants.couponDefaultExpirationDays),
      );

      final token = CouponGenerator.generateToken(
        couponId: couponId,
        userId: userId,
        promotionId: promotionId,
        expiresAt: expiresAt,
      );

      final qrData = CouponGenerator.generateQRData(
        couponId: couponId,
        token: token,
      );

      final checksum = CouponGenerator.generateChecksum('$couponId:$userId:$promotionId');

      final now = Timestamp.now();
      final firestoreData = {
        'id': couponId,
        'userId': userId,
        'commerceId': promotionData['commerceId'],
        'commerceName': promotionData['commerceName'],
        'promotionId': promotionId,
        'promotionTitle': promotionData['title'],
        'token': token,
        'qrData': qrData,
        'checksum': checksum,
        'status': CouponStatus.available.name,
        'issuedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'deviceFingerprint': fingerprint,
        'metadata': {
          'promotionType': promotionData['type'],
          'discountValue': promotionData['discountValue'],
          'discountType': promotionData['discountType'],
        },
      };

      final couponRef = _firestore
          .collection(AppConstants.couponsCollection)
          .doc(couponId);

      transaction.set(couponRef, firestoreData);
      transaction.update(promotionRef, {
        'usedSlots': FieldValue.increment(1),
      });

      // Retornar con Timestamp real para evitar FieldValue cast al parsear localmente
      return {...firestoreData, 'issuedAt': now};
    });
  }

  Future<Map<String, dynamic>> validateAndRedeemCoupon({
    required String qrData,
    required String employeeId,
    required String commerceId,
    String? branchId,
  }) async {
    // Parse QR data
    Map<String, dynamic> qrPayload;
    try {
      qrPayload = jsonDecode(qrData) as Map<String, dynamic>;
    } catch (_) {
      throw const CouponFailure(message: 'Código QR inválido');
    }

    if (qrPayload['shinra'] != '1') {
      throw const CouponFailure(message: 'QR no pertenece a ShinraCity');
    }

    final couponId = qrPayload['id'] as String?;
    final token = qrPayload['t'] as String?;

    if (couponId == null || token == null) {
      throw const CouponFailure(message: 'Datos del cupón incompletos');
    }

    // Validate token
    final tokenPayload = CouponGenerator.validateToken(token);
    if (tokenPayload == null) {
      throw const CouponFailure(message: 'Token del cupón inválido o expirado');
    }

    return await _firestore.runTransaction((transaction) async {
      final couponRef = _firestore
          .collection(AppConstants.couponsCollection)
          .doc(couponId);

      final couponDoc = await transaction.get(couponRef);
      if (!couponDoc.exists) {
        throw const CouponFailure(message: 'Cupón no encontrado');
      }

      final couponData = couponDoc.data()!;

      // Validate coupon belongs to this commerce
      if (couponData['commerceId'] != commerceId) {
        throw const UnauthorizedFailure(message: 'Este cupón no corresponde a tu comercio');
      }

      // Validate coupon status
      if (couponData['status'] != CouponStatus.available.name) {
        final status = couponData['status'] as String;
        throw CouponFailure(
          message: status == 'used'
              ? 'Este cupón ya fue utilizado'
              : status == 'expired'
                  ? 'Este cupón ha expirado'
                  : 'Este cupón no está disponible',
        );
      }

      // Validate expiration
      final expiresAt = (couponData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        transaction.update(couponRef, {'status': CouponStatus.expired.name});
        throw const CouponFailure(message: 'Este cupón ha expirado');
      }

      // Validate checksum
      final expectedChecksum = CouponGenerator.generateChecksum(
        '$couponId:${couponData['userId']}:${couponData['promotionId']}',
      );
      if (couponData['checksum'] != expectedChecksum) {
        throw const FraudDetectedFailure();
      }

      // Redeem coupon
      transaction.update(couponRef, {
        'status': CouponStatus.used.name,
        'usedAt': FieldValue.serverTimestamp(),
        'usedByEmployeeId': employeeId,
        'usedAtBranchId': branchId,
      });

      return couponData;
    });
  }

  /// Cobra los puntos de un cupón que el comercio ya canjeó. Lo hace la app
  /// del usuario (no hay Cloud Functions); firestore.rules (couponPointsClaim)
  /// verifica que el cupón sea suyo, esté 'used' y no se haya cobrado.
  /// Devuelve los puntos sumados (0 si ya estaba cobrado).
  Future<int> claimCouponPoints({
    required String userId,
    required String couponId,
  }) async {
    const points = AppConstants.pointsPerCouponRedeemed;
    return _firestore.runTransaction((t) async {
      final txRef = _firestore
          .collection(AppConstants.pointsTransactionsCollection)
          .doc('coupon_$couponId');
      if ((await t.get(txRef)).exists) return 0;

      final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
      final user = (await t.get(userRef)).data() ?? {};
      final total = (user['totalPoints'] as int? ?? 0) + points;
      final available = (user['availablePoints'] as int? ?? 0) + points;
      final level = levelForPoints(total);

      t.update(userRef, {
        'totalPoints': total,
        'availablePoints': available,
        'totalCouponsRedeemed': (user['totalCouponsRedeemed'] as int? ?? 0) + 1,
        'level': level,
        'lastPointsCouponId': couponId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      t.set(txRef, {
        'userId': userId,
        'points': points,
        'type': 'earned',
        'reason': 'Cupón canjeado',
        'couponId': couponId,
        'balanceAfter': available,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // mantener el ranking al día
      t.set(
        _firestore.collection(AppConstants.publicProfilesCollection).doc(userId),
        {'totalPoints': total, 'level': level, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      return points;
    });
  }

  static String levelForPoints(int totalPoints) {
    final t = AppConstants.levelThresholds;
    if (totalPoints >= t['lifetime']!) return 'lifetime';
    if (totalPoints >= t['ambassador']!) return 'ambassador';
    if (totalPoints >= t['exemplary']!) return 'exemplary';
    if (totalPoints >= t['frequent']!) return 'frequent';
    return 'explorer';
  }

  Future<List<Map<String, dynamic>>> getUserCoupons({
    required String userId,
    CouponStatus? status,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    Query query = _firestore
        .collection(AppConstants.couponsCollection)
        .where('userId', isEqualTo: userId)
        .limit(limit * 3);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs
        .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
        .toList()
      ..sort((a, b) {
        final aDate = (a['issuedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final bDate = (b['issuedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
    return docs.take(limit).toList();
  }

  Stream<List<Map<String, dynamic>>> watchUserCoupons(String userId) {
    return _firestore
        .collection(AppConstants.couponsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final docs = s.docs
              .map((d) => {...d.data(), 'id': d.id})
              .toList()
            ..sort((a, b) {
              final aDate = (a['issuedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
              final bDate = (b['issuedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
              return bDate.compareTo(aDate);
            });
          return docs;
        });
  }

  Future<void> checkAndExpireCoupons(String userId) async {
    final now = Timestamp.now();
    final snap = await _firestore
        .collection(AppConstants.couponsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: CouponStatus.available.name)
        .get();

    final expiredDocs = snap.docs.where((doc) {
      final expiresAt = (doc.data())['expiresAt'] as Timestamp?;
      return expiresAt != null && expiresAt.compareTo(now) < 0;
    });

    final batch = _firestore.batch();
    for (final doc in expiredDocs) {
      batch.update(doc.reference, {'status': CouponStatus.expired.name});
    }
    await batch.commit();
  }
}
