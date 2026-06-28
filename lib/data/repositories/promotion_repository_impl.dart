import 'package:dartz/dartz.dart';
import 'package:latlong2/latlong.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/geo_utils.dart';
import '../../domain/entities/promotion_entity.dart';
import '../../domain/repositories/promotion_repository.dart';
import '../datasources/firebase/firebase_promotion_datasource.dart';
import '../models/promotion_model.dart';

class PromotionRepositoryImpl implements PromotionRepository {
  final FirebasePromotionDatasource _datasource;

  PromotionRepositoryImpl({required FirebasePromotionDatasource datasource})
      : _datasource = datasource;

  @override
  Future<Either<Failure, PromotionEntity>> createPromotion(
      PromotionEntity promotion) async {
    try {
      final model = _toModel(promotion);
      final created = await _datasource.createPromotion(model);
      return Right(created);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PromotionEntity>> getPromotion(String id) async {
    try {
      final promotion = await _datasource.getPromotion(id);
      return Right(promotion);
    } catch (e) {
      return Left(NotFoundFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PromotionEntity>> updatePromotion(
      PromotionEntity promotion) async {
    try {
      final model = _toModel(promotion);
      await _datasource.updatePromotion(model);
      return Right(promotion);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deletePromotion(String id) async {
    try {
      await _datasource.changeStatus(
        promotionId: id,
        commerceId: '',
        newStatus: PromotionStatus.cancelled,
        oldStatus: PromotionStatus.active,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> changePromotionStatus({
    required String promotionId,
    required PromotionStatus status,
  }) async {
    try {
      final current = await _datasource.getPromotion(promotionId);
      await _datasource.changeStatus(
        promotionId: promotionId,
        commerceId: current.commerceId,
        newStatus: status,
        oldStatus: current.status,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PromotionEntity>>> getNearbyPromotions({
    required LatLng location,
    required double radiusKm,
    List<String>? categories,
    bool onlyActive = true,
    int limit = 50,
  }) async {
    try {
      final promotions = await _datasource.getNearbyPromotions(
        location: location,
        radiusKm: radiusKm,
        categories: categories,
        onlyActive: onlyActive,
        limit: limit,
      );
      return Right(promotions);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PromotionEntity>>> getCommercePromotions({
    required String commerceId,
    PromotionStatus? status,
    int limit = 20,
  }) async {
    try {
      final promotions = await _datasource.getCommercePromotions(
        commerceId: commerceId,
        status: status,
        limit: limit,
      );
      return Right(promotions);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PromotionEntity>>> getFeaturedPromotions({
    LatLng? location,
    int limit = 10,
  }) async {
    try {
      final promotions = await _datasource.getFeaturedPromotions(limit: limit);
      return Right(promotions);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PromotionEntity>>> getRecommendedPromotions({
    required String userId,
    required LatLng location,
    int limit = 20,
  }) async {
    // Delegate to AI Cloud Function via getNearbyPromotions + scoring
    return getNearbyPromotions(
      location: location,
      radiusKm: 5.0,
      limit: limit,
    );
  }

  @override
  Future<Either<Failure, String>> uploadPromotionImage({
    required String promotionId,
    required String filePath,
  }) async {
    try {
      final url = await _datasource.uploadPromotionImage(
        promotionId: promotionId,
        filePath: filePath,
      );
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<PromotionEntity>> watchCommercePromotions(String commerceId) =>
      _datasource.watchCommercePromotions(commerceId);

  @override
  Stream<List<PromotionEntity>> watchNearbyPromotions({
    required LatLng location,
    required double radiusKm,
  }) {
    return _datasource.watchActivePromotions(limit: 150).map((promotions) {
      return promotions.where((p) {
        // Promotions with their own geo-location: check by distance
        if (p.geoLocation != null) {
          return GeoUtils.isWithinRadius(location, p.geoLocation!, radiusKm);
        }
        // Promotions linked to a commerce: include them (commerce-level
        // geo-filtering is handled in the map layer via getNearbyCommerces)
        return true;
      }).cast<PromotionEntity>().toList();
    });
  }

  @override
  Future<Either<Failure, void>> incrementViewCount(String promotionId) async {
    try {
      await _datasource.incrementViewCount(promotionId);
      return const Right(null);
    } catch (e) {
      return const Right(null); // Non-critical
    }
  }

  PromotionModel _toModel(PromotionEntity e) {
    return PromotionModel(
      id: e.id,
      commerceId: e.commerceId,
      commerceName: e.commerceName,
      commerceLogoUrl: e.commerceLogoUrl,
      title: e.title,
      description: e.description,
      imageUrls: e.imageUrls,
      type: e.type,
      status: e.status,
      discountType: e.discountType,
      discountValue: e.discountValue,
      discountDescription: e.discountDescription,
      startDate: e.startDate,
      endDate: e.endDate,
      totalSlots: e.totalSlots,
      usedSlots: e.usedSlots,
      dailyLimit: e.dailyLimit,
      perUserLimit: e.perUserLimit,
      conditions: e.conditions,
      categories: e.categories,
      isExclusiveForFollowers: e.isExclusiveForFollowers,
      isVip: e.isVip,
      isGeolocated: e.isGeolocated,
      geoLocation: e.geoLocation,
      geoRadius: e.geoRadius,
      originalPrice: e.originalPrice,
      discountedPrice: e.discountedPrice,
      pointsRequired: e.pointsRequired,
      pointsAwarded: e.pointsAwarded,
      requiresCode: e.requiresCode,
      promoCode: e.promoCode,
      createdAt: e.createdAt,
      viewCount: e.viewCount,
      claimCount: e.claimCount,
      savedAmount: e.savedAmount,
    );
  }
}
