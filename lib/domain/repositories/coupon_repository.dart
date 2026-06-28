import 'package:dartz/dartz.dart';
import '../entities/coupon_entity.dart';
import '../../core/errors/failures.dart';

abstract class CouponRepository {
  Future<Either<Failure, CouponEntity>> claimCoupon({
    required String userId,
    required String promotionId,
    required String deviceId,
  });

  Future<Either<Failure, CouponEntity>> validateAndRedeemCoupon({
    required String qrData,
    required String employeeId,
    required String commerceId,
    String? branchId,
  });

  Future<Either<Failure, CouponEntity>> getCoupon(String id);

  Future<Either<Failure, List<CouponEntity>>> getUserCoupons({
    required String userId,
    CouponStatus? status,
    int limit = 20,
    String? lastCouponId,
  });

  Future<Either<Failure, List<CouponEntity>>> getCommerceCoupons({
    required String commerceId,
    CouponStatus? status,
    int limit = 20,
  });

  Future<Either<Failure, void>> cancelCoupon({
    required String couponId,
    required String userId,
    String? reason,
  });

  Future<Either<Failure, bool>> checkCouponEligibility({
    required String userId,
    required String promotionId,
    required String deviceId,
  });

  Stream<List<CouponEntity>> watchUserCoupons(String userId);

  Future<Either<Failure, Map<String, dynamic>>> getCouponAnalytics({
    required String commerceId,
    DateTime? startDate,
    DateTime? endDate,
  });
}
