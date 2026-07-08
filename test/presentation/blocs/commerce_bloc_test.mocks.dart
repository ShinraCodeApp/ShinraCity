import 'package:dartz/dartz.dart';
import 'package:latlong2/latlong.dart';
import 'package:mockito/mockito.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/commerce_entity.dart';
import 'package:shinra_city/domain/entities/review_entity.dart';
import 'package:shinra_city/domain/repositories/commerce_repository.dart';

class MockCommerceRepository extends Mock implements CommerceRepository {
  @override
  Future<Either<Failure, CommerceEntity>> getCommerce(String? id) =>
      super.noSuchMethod(
        Invocation.method(#getCommerce, [id]),
        returnValue: Future<Either<Failure, CommerceEntity>>.value(const Left(ServerFailure(message: 'error'))),
        returnValueForMissingStub: Future<Either<Failure, CommerceEntity>>.value(const Left(ServerFailure(message: 'error'))),
      ) as Future<Either<Failure, CommerceEntity>>;

  @override
  Future<Either<Failure, CommerceEntity>> getCommerceByOwnerId(String? ownerId) =>
      super.noSuchMethod(
        Invocation.method(#getCommerceByOwnerId, [ownerId]),
        returnValue: Future<Either<Failure, CommerceEntity>>.value(const Left(ServerFailure(message: 'error'))),
        returnValueForMissingStub: Future<Either<Failure, CommerceEntity>>.value(const Left(ServerFailure(message: 'error'))),
      ) as Future<Either<Failure, CommerceEntity>>;

  @override
  Future<Either<Failure, bool>> isUserFavorite({
    required String? userId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#isUserFavorite, [], {#userId: userId, #commerceId: commerceId}),
        returnValue: Future<Either<Failure, bool>>.value(const Right(false)),
        returnValueForMissingStub: Future<Either<Failure, bool>>.value(const Right(false)),
      ) as Future<Either<Failure, bool>>;

  @override
  Future<Either<Failure, bool>> isUserFollowing({
    required String? userId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#isUserFollowing, [], {#userId: userId, #commerceId: commerceId}),
        returnValue: Future<Either<Failure, bool>>.value(const Right(false)),
        returnValueForMissingStub: Future<Either<Failure, bool>>.value(const Right(false)),
      ) as Future<Either<Failure, bool>>;

  @override
  Future<Either<Failure, void>> toggleFavorite({
    required String? userId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#toggleFavorite, [], {#userId: userId, #commerceId: commerceId}),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
        returnValueForMissingStub: Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, void>> toggleFollow({
    required String? userId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#toggleFollow, [], {#userId: userId, #commerceId: commerceId}),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
        returnValueForMissingStub: Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, CommerceEntity>> updateCommerce(CommerceEntity? commerce) =>
      super.noSuchMethod(
        Invocation.method(#updateCommerce, [commerce]),
        returnValue: Future<Either<Failure, CommerceEntity>>.value(const Left(ServerFailure(message: 'error'))),
        returnValueForMissingStub: Future<Either<Failure, CommerceEntity>>.value(const Left(ServerFailure(message: 'error'))),
      ) as Future<Either<Failure, CommerceEntity>>;

  @override
  Future<Either<Failure, List<CommerceEntity>>> getUserFavorites(String? userId) =>
      super.noSuchMethod(
        Invocation.method(#getUserFavorites, [userId]),
        returnValue: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
        returnValueForMissingStub: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
      ) as Future<Either<Failure, List<CommerceEntity>>>;

  @override
  Future<Either<Failure, List<CommerceEntity>>> getUserFollowing(String? userId) =>
      super.noSuchMethod(
        Invocation.method(#getUserFollowing, [userId]),
        returnValue: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
        returnValueForMissingStub: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
      ) as Future<Either<Failure, List<CommerceEntity>>>;

  @override
  Future<Either<Failure, CommerceEntity>> createCommerce(CommerceEntity? commerce) =>
      super.noSuchMethod(
        Invocation.method(#createCommerce, [commerce]),
        returnValue: Future<Either<Failure, CommerceEntity>>.value(const Left(ServerFailure(message: 'error'))),
        returnValueForMissingStub: Future<Either<Failure, CommerceEntity>>.value(const Left(ServerFailure(message: 'error'))),
      ) as Future<Either<Failure, CommerceEntity>>;

  @override
  Future<Either<Failure, void>> deleteCommerce(String? id) =>
      super.noSuchMethod(
        Invocation.method(#deleteCommerce, [id]),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
        returnValueForMissingStub: Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;

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
          #location: location, #radiusKm: radiusKm, #category: category,
          #searchQuery: searchQuery, #onlyOpen: onlyOpen,
          #onlyWithPromotions: onlyWithPromotions, #minPlan: minPlan, #limit: limit,
        }),
        returnValue: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
        returnValueForMissingStub: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
      ) as Future<Either<Failure, List<CommerceEntity>>>;

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
          #query: query, #category: category, #location: location,
          #radiusKm: radiusKm, #limit: limit,
        }),
        returnValue: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
        returnValueForMissingStub: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
      ) as Future<Either<Failure, List<CommerceEntity>>>;

  @override
  Future<Either<Failure, List<CommerceEntity>>> getFeaturedCommerces({
    LatLng? location,
    int limit = 10,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFeaturedCommerces, [], {#location: location, #limit: limit}),
        returnValue: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
        returnValueForMissingStub: Future<Either<Failure, List<CommerceEntity>>>.value(const Right([])),
      ) as Future<Either<Failure, List<CommerceEntity>>>;

  @override
  Future<Either<Failure, String>> uploadLogo({
    required String? commerceId,
    required String? filePath,
  }) =>
      super.noSuchMethod(
        Invocation.method(#uploadLogo, [], {#commerceId: commerceId, #filePath: filePath}),
        returnValue: Future<Either<Failure, String>>.value(const Left(ServerFailure(message: 'error'))),
        returnValueForMissingStub: Future<Either<Failure, String>>.value(const Left(ServerFailure(message: 'error'))),
      ) as Future<Either<Failure, String>>;

  @override
  Future<Either<Failure, String>> uploadGalleryImage({
    required String? commerceId,
    required String? filePath,
  }) =>
      super.noSuchMethod(
        Invocation.method(#uploadGalleryImage, [], {#commerceId: commerceId, #filePath: filePath}),
        returnValue: Future<Either<Failure, String>>.value(const Left(ServerFailure(message: 'error'))),
        returnValueForMissingStub: Future<Either<Failure, String>>.value(const Left(ServerFailure(message: 'error'))),
      ) as Future<Either<Failure, String>>;

  @override
  Future<Either<Failure, void>> deleteGalleryImage({
    required String? commerceId,
    required String? imageUrl,
  }) =>
      super.noSuchMethod(
        Invocation.method(#deleteGalleryImage, [], {#commerceId: commerceId, #imageUrl: imageUrl}),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
        returnValueForMissingStub: Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Stream<CommerceEntity> watchCommerce(String? id) => super.noSuchMethod(
        Invocation.method(#watchCommerce, [id]),
        returnValue: const Stream<CommerceEntity>.empty(),
        returnValueForMissingStub: const Stream<CommerceEntity>.empty(),
      ) as Stream<CommerceEntity>;

  @override
  Stream<List<CommerceEntity>> watchNearbyCommerces({
    required LatLng? location,
    required double? radiusKm,
  }) =>
      super.noSuchMethod(
        Invocation.method(#watchNearbyCommerces, [], {#location: location, #radiusKm: radiusKm}),
        returnValue: const Stream<List<CommerceEntity>>.empty(),
        returnValueForMissingStub: const Stream<List<CommerceEntity>>.empty(),
      ) as Stream<List<CommerceEntity>>;

  @override
  Future<Either<Failure, void>> updateBusinessHours({
    required String? commerceId,
    required Map<String, BusinessHours>? hours,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateBusinessHours, [], {#commerceId: commerceId, #hours: hours}),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
        returnValueForMissingStub: Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, void>> addEmployee({
    required String? commerceId,
    required String? employeeId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#addEmployee, [], {#commerceId: commerceId, #employeeId: employeeId}),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
        returnValueForMissingStub: Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, void>> removeEmployee({
    required String? commerceId,
    required String? employeeId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#removeEmployee, [], {#commerceId: commerceId, #employeeId: employeeId}),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
        returnValueForMissingStub: Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCommerceAnalytics({
    required String? commerceId,
    String period = 'week',
  }) =>
      super.noSuchMethod(
        Invocation.method(#getCommerceAnalytics, [], {#commerceId: commerceId, #period: period}),
        returnValue: Future<Either<Failure, Map<String, dynamic>>>.value(const Right(<String, dynamic>{})),
        returnValueForMissingStub: Future<Either<Failure, Map<String, dynamic>>>.value(const Right(<String, dynamic>{})),
      ) as Future<Either<Failure, Map<String, dynamic>>>;

  @override
  Future<Either<Failure, List<String>>> getAiSuggestions({
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getAiSuggestions, [], {#commerceId: commerceId}),
        returnValue: Future<Either<Failure, List<String>>>.value(const Right(<String>[])),
        returnValueForMissingStub: Future<Either<Failure, List<String>>>.value(const Right(<String>[])),
      ) as Future<Either<Failure, List<String>>>;

  @override
  Future<Either<Failure, List<int>>> getDailyCouponCounts({
    required String? commerceId,
    int days = 30,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getDailyCouponCounts, [], {#commerceId: commerceId, #days: days}),
        returnValue: Future<Either<Failure, List<int>>>.value(Right(List<int>.filled(30, 0))),
        returnValueForMissingStub: Future<Either<Failure, List<int>>>.value(Right(List<int>.filled(30, 0))),
      ) as Future<Either<Failure, List<int>>>;

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRecentCouponActivity({
    required String? commerceId,
    int limit = 5,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getRecentCouponActivity, [], {#commerceId: commerceId, #limit: limit}),
        returnValue: Future<Either<Failure, List<Map<String, dynamic>>>>.value(const Right(<Map<String, dynamic>>[])),
        returnValueForMissingStub: Future<Either<Failure, List<Map<String, dynamic>>>>.value(const Right(<Map<String, dynamic>>[])),
      ) as Future<Either<Failure, List<Map<String, dynamic>>>>;

  @override
  Future<Either<Failure, List<ReviewEntity>>> getCommerceReviews({
    required String? commerceId,
    int limit = 20,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getCommerceReviews, [], {#commerceId: commerceId, #limit: limit}),
        returnValue: Future<Either<Failure, List<ReviewEntity>>>.value(const Right([])),
        returnValueForMissingStub: Future<Either<Failure, List<ReviewEntity>>>.value(const Right([])),
      ) as Future<Either<Failure, List<ReviewEntity>>>;

  @override
  Future<Either<Failure, ReviewEntity>> addReview({
    required String? commerceId,
    required String? userId,
    required String? userName,
    String? userPhotoUrl,
    required double? rating,
    required String? comment,
  }) =>
      super.noSuchMethod(
        Invocation.method(#addReview, [], {
          #commerceId: commerceId,
          #userId: userId,
          #userName: userName,
          #userPhotoUrl: userPhotoUrl,
          #rating: rating,
          #comment: comment,
        }),
        returnValue: Future<Either<Failure, ReviewEntity>>.value(
          const Left(ServerFailure(message: 'error')),
        ),
        returnValueForMissingStub: Future<Either<Failure, ReviewEntity>>.value(
          const Left(ServerFailure(message: 'error')),
        ),
      ) as Future<Either<Failure, ReviewEntity>>;

  @override
  Future<Either<Failure, void>> voteHelpful({required String? reviewId}) =>
      super.noSuchMethod(
        Invocation.method(#voteHelpful, [], {#reviewId: reviewId}),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
        returnValueForMissingStub: Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;
}
