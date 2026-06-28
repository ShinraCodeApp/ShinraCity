import 'package:dartz/dartz.dart';
import 'package:latlong2/latlong.dart';
import '../entities/commerce_entity.dart';
import '../../core/errors/failures.dart';

abstract class CommerceRepository {
  Future<Either<Failure, CommerceEntity>> createCommerce(CommerceEntity commerce);

  Future<Either<Failure, CommerceEntity>> getCommerce(String id);

  Future<Either<Failure, CommerceEntity>> updateCommerce(CommerceEntity commerce);

  Future<Either<Failure, void>> deleteCommerce(String id);

  Future<Either<Failure, List<CommerceEntity>>> getNearbyCommerces({
    required LatLng location,
    required double radiusKm,
    CommerceCategory? category,
    String? searchQuery,
    bool onlyOpen = false,
    bool onlyWithPromotions = false,
    CommercePlan? minPlan,
    int limit = 50,
  });

  Future<Either<Failure, List<CommerceEntity>>> searchCommerces({
    required String query,
    CommerceCategory? category,
    LatLng? location,
    double? radiusKm,
    int limit = 20,
  });

  Future<Either<Failure, List<CommerceEntity>>> getFeaturedCommerces({
    LatLng? location,
    int limit = 10,
  });

  Future<Either<Failure, List<CommerceEntity>>> getUserFavorites(String userId);

  Future<Either<Failure, List<CommerceEntity>>> getUserFollowing(String userId);

  Future<Either<Failure, bool>> isUserFavorite({
    required String userId,
    required String commerceId,
  });

  Future<Either<Failure, bool>> isUserFollowing({
    required String userId,
    required String commerceId,
  });

  Future<Either<Failure, void>> toggleFavorite({
    required String userId,
    required String commerceId,
  });

  Future<Either<Failure, void>> toggleFollow({
    required String userId,
    required String commerceId,
  });

  Future<Either<Failure, String>> uploadLogo({
    required String commerceId,
    required String filePath,
  });

  Future<Either<Failure, String>> uploadGalleryImage({
    required String commerceId,
    required String filePath,
  });

  Future<Either<Failure, void>> deleteGalleryImage({
    required String commerceId,
    required String imageUrl,
  });

  Stream<CommerceEntity> watchCommerce(String id);

  Stream<List<CommerceEntity>> watchNearbyCommerces({
    required LatLng location,
    required double radiusKm,
  });

  Future<Either<Failure, CommerceEntity>> getCommerceByOwnerId(String ownerId);

  Future<Either<Failure, void>> updateBusinessHours({
    required String commerceId,
    required Map<String, BusinessHours> hours,
  });

  Future<Either<Failure, void>> addEmployee({
    required String commerceId,
    required String employeeId,
  });

  Future<Either<Failure, void>> removeEmployee({
    required String commerceId,
    required String employeeId,
  });

  Future<Either<Failure, Map<String, dynamic>>> getCommerceAnalytics({
    required String commerceId,
    String period = 'week',
  });

  Future<Either<Failure, List<String>>> getAiSuggestions({
    required String commerceId,
  });

  Future<Either<Failure, List<int>>> getDailyCouponCounts({
    required String commerceId,
    int days = 30,
  });

  Future<Either<Failure, List<Map<String, dynamic>>>> getRecentCouponActivity({
    required String commerceId,
    int limit = 5,
  });
}
