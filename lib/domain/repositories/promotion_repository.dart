import 'package:dartz/dartz.dart';
import 'package:latlong2/latlong.dart';
import '../entities/promotion_entity.dart';
import '../../core/errors/failures.dart';

abstract class PromotionRepository {
  Future<Either<Failure, PromotionEntity>> createPromotion(PromotionEntity promotion);

  Future<Either<Failure, PromotionEntity>> getPromotion(String id);

  Future<Either<Failure, PromotionEntity>> updatePromotion(PromotionEntity promotion);

  Future<Either<Failure, void>> deletePromotion(String id);

  Future<Either<Failure, void>> changePromotionStatus({
    required String promotionId,
    required PromotionStatus status,
  });

  Future<Either<Failure, List<PromotionEntity>>> getNearbyPromotions({
    required LatLng location,
    required double radiusKm,
    List<String>? categories,
    bool onlyActive = true,
    int limit = 50,
  });

  Future<Either<Failure, List<PromotionEntity>>> getCommercePromotions({
    required String commerceId,
    PromotionStatus? status,
    int limit = 20,
  });

  Future<Either<Failure, List<PromotionEntity>>> getFeaturedPromotions({
    LatLng? location,
    int limit = 10,
  });

  Future<Either<Failure, List<PromotionEntity>>> getRecommendedPromotions({
    required String userId,
    required LatLng location,
    int limit = 20,
  });

  Future<Either<Failure, String>> uploadPromotionImage({
    required String promotionId,
    required String filePath,
  });

  Stream<List<PromotionEntity>> watchCommercePromotions(String commerceId);

  Stream<List<PromotionEntity>> watchNearbyPromotions({
    required LatLng location,
    required double radiusKm,
  });

  Future<Either<Failure, void>> incrementViewCount(String promotionId);
}
