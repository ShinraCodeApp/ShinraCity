import 'package:dartz/dartz.dart';
import 'package:latlong2/latlong.dart';
import 'package:mockito/mockito.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/commerce_entity.dart';
import 'package:shinra_city/domain/repositories/commerce_repository.dart';

class MockCommerceRepository extends Mock implements CommerceRepository {
  @override
  Future<Either<Failure, CommerceEntity>> getCommerce(String? id) =>
      super.noSuchMethod(
        Invocation.method(#getCommerce, [id]),
        returnValue: Future.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, CommerceEntity>> getCommerceByOwnerId(String? ownerId) =>
      super.noSuchMethod(
        Invocation.method(#getCommerceByOwnerId, [ownerId]),
        returnValue: Future.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, bool>> isUserFavorite({
    required String? userId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #isUserFavorite,
          [],
          {#userId: userId, #commerceId: commerceId},
        ),
        returnValue: Future.value(const Right(false)),
      );

  @override
  Future<Either<Failure, bool>> isUserFollowing({
    required String? userId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #isUserFollowing,
          [],
          {#userId: userId, #commerceId: commerceId},
        ),
        returnValue: Future.value(const Right(false)),
      );

  @override
  Future<Either<Failure, void>> toggleFavorite({
    required String? userId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #toggleFavorite,
          [],
          {#userId: userId, #commerceId: commerceId},
        ),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, void>> toggleFollow({
    required String? userId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #toggleFollow,
          [],
          {#userId: userId, #commerceId: commerceId},
        ),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, CommerceEntity>> updateCommerce(CommerceEntity? commerce) =>
      super.noSuchMethod(
        Invocation.method(#updateCommerce, [commerce]),
        returnValue: Future.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, List<CommerceEntity>>> getUserFavorites(String? userId) =>
      super.noSuchMethod(
        Invocation.method(#getUserFavorites, [userId]),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, List<CommerceEntity>>> getUserFollowing(String? userId) =>
      super.noSuchMethod(
        Invocation.method(#getUserFollowing, [userId]),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, CommerceEntity>> createCommerce(CommerceEntity? commerce) =>
      super.noSuchMethod(
        Invocation.method(#createCommerce, [commerce]),
        returnValue: Future.value(Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, void>> deleteCommerce(String? id) =>
      super.noSuchMethod(
        Invocation.method(#deleteCommerce, [id]),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, List<CommerceEntity>>> getNearbyCommerces({
    required LatLng? location,
    required double? radiusKm,
    CommerceCategory? category,
    String? searchQuery,
    bool onlyOpen = false,
    bool onlyWithPromotions = false,
    CommercePlan? minPlan,
    int limit = 50,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getNearbyCommerces, [], {
          #location: location,
          #radiusKm: radiusKm,
          #category: category,
          #searchQuery: searchQuery,
          #onlyOpen: onlyOpen,
          #onlyWithPromotions: onlyWithPromotions,
          #minPlan: minPlan,
          #limit: limit,
        }),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, List<CommerceEntity>>> searchCommerces({
    required String? query,
    CommerceCategory? category,
    LatLng? location,
    double? radiusKm,
    int limit = 20,
  }) =>
      super.noSuchMethod(
        Invocation.method(#searchCommerces, [], {
          #query: query,
          #category: category,
          #location: location,
          #radiusKm: radiusKm,
          #limit: limit,
        }),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, List<CommerceEntity>>> getFeaturedCommerces({
    LatLng? location,
    int limit = 10,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFeaturedCommerces, [], {
          #location: location,
          #limit: limit,
        }),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, String>> uploadLogo({
    required String? commerceId,
    required String? filePath,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #uploadLogo,
          [],
          {#commerceId: commerceId, #filePath: filePath},
        ),
        returnValue: Future.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, String>> uploadGalleryImage({
    required String? commerceId,
    required String? filePath,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #uploadGalleryImage,
          [],
          {#commerceId: commerceId, #filePath: filePath},
        ),
        returnValue: Future.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, void>> deleteGalleryImage({
    required String? commerceId,
    required String? imageUrl,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #deleteGalleryImage,
          [],
          {#commerceId: commerceId, #imageUrl: imageUrl},
        ),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Stream<CommerceEntity> watchCommerce(String? id) => super.noSuchMethod(
        Invocation.method(#watchCommerce, [id]),
        returnValue: const Stream.empty(),
      );

  @override
  Stream<List<CommerceEntity>> watchNearbyCommerces({
    required LatLng? location,
    required double? radiusKm,
  }) =>
      super.noSuchMethod(
        Invocation.method(#watchNearbyCommerces, [], {
          #location: location,
          #radiusKm: radiusKm,
        }),
        returnValue: const Stream.empty(),
      );

  @override
  Future<Either<Failure, void>> updateBusinessHours({
    required String? commerceId,
    required Map<String, BusinessHours>? hours,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #updateBusinessHours,
          [],
          {#commerceId: commerceId, #hours: hours},
        ),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, void>> addEmployee({
    required String? commerceId,
    required String? employeeId,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #addEmployee,
          [],
          {#commerceId: commerceId, #employeeId: employeeId},
        ),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, void>> removeEmployee({
    required String? commerceId,
    required String? employeeId,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #removeEmployee,
          [],
          {#commerceId: commerceId, #employeeId: employeeId},
        ),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCommerceAnalytics({
    required String? commerceId,
    String period = 'week',
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #getCommerceAnalytics,
          [],
          {#commerceId: commerceId, #period: period},
        ),
        returnValue: Future.value(const Right(<String, dynamic>{})),
      );

  @override
  Future<Either<Failure, List<String>>> getAiSuggestions({
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #getAiSuggestions,
          [],
          {#commerceId: commerceId},
        ),
        returnValue: Future.value(const Right(<String>[])),
      );

  @override
  Future<Either<Failure, List<int>>> getDailyCouponCounts({
    required String? commerceId,
    int days = 30,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #getDailyCouponCounts,
          [],
          {#commerceId: commerceId, #days: days},
        ),
        returnValue: Future.value(Right(List<int>.filled(30, 0))),
      );

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRecentCouponActivity({
    required String? commerceId,
    int limit = 5,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #getRecentCouponActivity,
          [],
          {#commerceId: commerceId, #limit: limit},
        ),
        returnValue:
            Future.value(const Right(<Map<String, dynamic>>[])),
      );
}
