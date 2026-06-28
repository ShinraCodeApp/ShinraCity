import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/coupon_entity.dart';
import '../../domain/repositories/coupon_repository.dart';
import '../datasources/firebase/firebase_coupon_datasource.dart';

class CouponRepositoryImpl implements CouponRepository {
  final FirebaseCouponDatasource _datasource;
  final FirebaseAuth _auth;

  CouponRepositoryImpl({
    required FirebaseCouponDatasource datasource,
    required FirebaseAuth auth,
  })  : _datasource = datasource,
        _auth = auth;

  @override
  Future<Either<Failure, CouponEntity>> claimCoupon({
    required String userId,
    required String promotionId,
    required String deviceId,
  }) async {
    try {
      final data = await _datasource.claimCoupon(
        userId: userId,
        promotionId: promotionId,
        deviceId: deviceId,
      );
      return Right(_mapToCoupon(data));
    } on CouponFailure catch (e) {
      return Left(e);
    } on FraudDetectedFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CouponEntity>> validateAndRedeemCoupon({
    required String qrData,
    required String employeeId,
    required String commerceId,
    String? branchId,
  }) async {
    try {
      final data = await _datasource.validateAndRedeemCoupon(
        qrData: qrData,
        employeeId: employeeId,
        commerceId: commerceId,
        branchId: branchId,
      );
      return Right(_mapToCoupon(data));
    } on CouponFailure catch (e) {
      return Left(e);
    } on UnauthorizedFailure catch (e) {
      return Left(e);
    } on FraudDetectedFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CouponEntity>> getCoupon(String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('coupons').doc(id).get();
      if (!doc.exists) return const Left(NotFoundFailure());
      return Right(_mapToCoupon({...doc.data()!, 'id': doc.id}));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CouponEntity>>> getUserCoupons({
    required String userId,
    CouponStatus? status,
    int limit = 20,
    String? lastCouponId,
  }) async {
    try {
      final couponsData = await _datasource.getUserCoupons(
        userId: userId,
        status: status,
        limit: limit,
      );
      return Right(couponsData.map(_mapToCoupon).toList());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CouponEntity>>> getCommerceCoupons({
    required String commerceId,
    CouponStatus? status,
    int limit = 20,
  }) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('coupons')
          .where('commerceId', isEqualTo: commerceId)
          .orderBy('issuedAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();
      return Right(snapshot.docs
          .map((d) => _mapToCoupon({...d.data() as Map<String, dynamic>, 'id': d.id}))
          .toList());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelCoupon({
    required String couponId,
    required String userId,
    String? reason,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('coupons').doc(couponId).update({
        'status': CouponStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': reason,
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> checkCouponEligibility({
    required String userId,
    required String promotionId,
    required String deviceId,
  }) async {
    try {
      final existingCount = await FirebaseFirestore.instance
          .collection('coupons')
          .where('userId', isEqualTo: userId)
          .where('promotionId', isEqualTo: promotionId)
          .where('status', whereNotIn: ['cancelled', 'expired'])
          .count()
          .get();

      return Right(existingCount.count == 0);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<CouponEntity>> watchUserCoupons(String userId) {
    return _datasource.watchUserCoupons(userId).map(
          (data) => data.map(_mapToCoupon).toList(),
        );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCouponAnalytics({
    required String commerceId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('coupons')
          .where('commerceId', isEqualTo: commerceId)
          .where('status', isEqualTo: 'used');

      if (startDate != null) {
        query = query.where('usedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('usedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();

      return Right({
        'totalRedeemed': snapshot.size,
        'totalSavings': snapshot.docs.fold<double>(
          0,
          (sum, doc) => sum + ((doc.data() as Map)['savedAmount'] ?? 0.0 as double),
        ),
      });
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  CouponEntity _mapToCoupon(Map<String, dynamic> data) {
    return CouponEntity(
      id: data['id'] as String,
      userId: data['userId'] as String,
      commerceId: data['commerceId'] as String,
      commerceName: data['commerceName'] as String,
      promotionId: data['promotionId'] as String,
      promotionTitle: data['promotionTitle'] as String,
      token: data['token'] as String,
      qrData: data['qrData'] as String,
      checksum: data['checksum'] as String,
      status: CouponStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => CouponStatus.available,
      ),
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      usedByEmployeeId: data['usedByEmployeeId'] as String?,
      usedAtBranchId: data['usedAtBranchId'] as String?,
      savedAmount: (data['savedAmount'] as num?)?.toDouble(),
      pointsEarned: data['pointsEarned'] as int?,
      deviceFingerprint: data['deviceFingerprint'] as String? ?? '',
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}
