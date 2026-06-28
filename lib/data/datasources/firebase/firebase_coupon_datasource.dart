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

      // Check per-user limit
      final perUserLimit = promotionData['perUserLimit'] as int? ?? 1;
      final existingCoupons = await _firestore
          .collection(AppConstants.couponsCollection)
          .where('userId', isEqualTo: userId)
          .where('promotionId', isEqualTo: promotionId)
          .where('status', whereNotIn: ['cancelled', 'expired'])
          .count()
          .get();

      if (existingCoupons.count! >= perUserLimit) {
        throw const CouponFailure(message: 'Ya reclamaste el máximo de cupones para esta promoción');
      }

      // Antifraud: check device fingerprint
      final fingerprint = CouponGenerator.generateAntifraudFingerprint(
        userId: userId,
        deviceId: deviceId,
        promotionId: promotionId,
      );

      final fraudCheck = await _firestore
          .collection(AppConstants.couponsCollection)
          .where('deviceFingerprint', isEqualTo: fingerprint)
          .where('promotionId', isEqualTo: promotionId)
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

      final couponData = {
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

      transaction.set(couponRef, couponData);
      transaction.update(promotionRef, {
        'usedSlots': FieldValue.increment(1),
      });

      return couponData;
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

  Future<List<Map<String, dynamic>>> getUserCoupons({
    required String userId,
    CouponStatus? status,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    Query query = _firestore
        .collection(AppConstants.couponsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('issuedAt', descending: true)
        .limit(limit);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
  }

  Stream<List<Map<String, dynamic>>> watchUserCoupons(String userId) {
    return _firestore
        .collection(AppConstants.couponsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [CouponStatus.available.name, CouponStatus.reserved.name])
        .orderBy('expiresAt')
        .snapshots()
        .map((s) => s.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> checkAndExpireCoupons(String userId) async {
    final now = Timestamp.now();
    final expiredCoupons = await _firestore
        .collection(AppConstants.couponsCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: CouponStatus.available.name)
        .where('expiresAt', isLessThan: now)
        .get();

    final batch = _firestore.batch();
    for (final doc in expiredCoupons.docs) {
      batch.update(doc.reference, {'status': CouponStatus.expired.name});
    }
    await batch.commit();
  }
}
