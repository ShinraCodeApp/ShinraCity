import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/geo_utils.dart';
import '../../domain/entities/commerce_entity.dart';
import '../../domain/repositories/commerce_repository.dart';
import '../datasources/firebase/firebase_commerce_datasource.dart';
import '../models/commerce_model.dart';

class CommerceRepositoryImpl implements CommerceRepository {
  final FirebaseCommerceDatasource _datasource;
  final FirebaseAuth _auth;

  CommerceRepositoryImpl({
    required FirebaseCommerceDatasource datasource,
    required FirebaseAuth auth,
  })  : _datasource = datasource,
        _auth = auth;

  @override
  Future<Either<Failure, CommerceEntity>> createCommerce(CommerceEntity commerce) async {
    try {
      final geohash = GeoUtils.encodeGeohash(
        commerce.location.latitude,
        commerce.location.longitude,
        AppConstants.geohashPrecision,
      );

      final model = CommerceModel(
        id: '',
        ownerId: _auth.currentUser!.uid,
        name: commerce.name,
        description: commerce.description,
        logoUrl: commerce.logoUrl,
        galleryUrls: commerce.galleryUrls,
        category: commerce.category,
        subCategories: commerce.subCategories,
        plan: CommercePlan.free,
        status: CommerceStatus.pending,
        location: commerce.location,
        geohash: geohash,
        address: commerce.address,
        city: commerce.city,
        country: commerce.country,
        phone: commerce.phone,
        email: commerce.email,
        website: commerce.website,
        socialLinks: commerce.socialLinks,
        businessHours: commerce.businessHours,
        tags: commerce.tags,
        authorizedEmployeeIds: const [],
        createdAt: DateTime.now(),
        taxId: commerce.taxId,
        legalName: commerce.legalName,
      );

      final created = await _datasource.createCommerce(model);
      return Right(created);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CommerceEntity>> getCommerce(String id) async {
    try {
      final commerce = await _datasource.getCommerce(id);
      return Right(commerce);
    } catch (e) {
      return Left(NotFoundFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CommerceEntity>> updateCommerce(CommerceEntity commerce) async {
    try {
      final model = CommerceModel(
        id: commerce.id,
        ownerId: commerce.ownerId,
        name: commerce.name,
        description: commerce.description,
        logoUrl: commerce.logoUrl,
        galleryUrls: commerce.galleryUrls,
        category: commerce.category,
        subCategories: commerce.subCategories,
        plan: commerce.plan,
        status: commerce.status,
        location: commerce.location,
        geohash: GeoUtils.encodeGeohash(
          commerce.location.latitude,
          commerce.location.longitude,
          AppConstants.geohashPrecision,
        ),
        address: commerce.address,
        city: commerce.city,
        country: commerce.country,
        phone: commerce.phone,
        email: commerce.email,
        website: commerce.website,
        socialLinks: commerce.socialLinks,
        businessHours: commerce.businessHours,
        rating: commerce.rating,
        reviewCount: commerce.reviewCount,
        followerCount: commerce.followerCount,
        activePromotionsCount: commerce.activePromotionsCount,
        isCurrentlyOpen: commerce.isCurrentlyOpen,
        hasActivePromotion: commerce.hasActivePromotion,
        isVerified: commerce.isVerified,
        isFeatured: commerce.isFeatured,
        tags: commerce.tags,
        pointsConfig: commerce.pointsConfig,
        authorizedEmployeeIds: commerce.authorizedEmployeeIds,
        createdAt: commerce.createdAt,
        verifiedAt: commerce.verifiedAt,
        taxId: commerce.taxId,
        legalName: commerce.legalName,
      );
      await _datasource.updateCommerce(model);
      return Right(commerce);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCommerce(String id) async {
    return const Left(ServerFailure(message: 'Use admin panel to delete'));
  }

  @override
  Future<Either<Failure, List<CommerceEntity>>> getNearbyCommerces({
    required LatLng location,
    required double radiusKm,
    CommerceCategory? category,
    String? searchQuery,
    bool onlyOpen = false,
    bool onlyWithPromotions = false,
    CommercePlan? minPlan,
    int limit = 50,
  }) async {
    try {
      final commerces = await _datasource.getNearbyCommerces(
        location: location,
        radiusKm: radiusKm,
        category: category,
        searchQuery: searchQuery,
        onlyOpen: onlyOpen,
        onlyWithPromotions: onlyWithPromotions,
        minPlan: minPlan,
        limit: limit,
      );
      return Right(commerces);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CommerceEntity>>> searchCommerces({
    required String query,
    CommerceCategory? category,
    LatLng? location,
    double? radiusKm,
    int limit = 20,
  }) async {
    try {
      final commerces = await _datasource.searchCommerces(
        query: query,
        category: category,
        location: location,
        radiusKm: radiusKm,
        limit: limit,
      );
      return Right(commerces);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CommerceEntity>>> getFeaturedCommerces({
    LatLng? location,
    int limit = 10,
  }) async {
    try {
      final commerces = await _datasource.getFeaturedCommerces(
        location: location,
        limit: limit,
      );
      return Right(commerces);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CommerceEntity>>> getUserFavorites(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final ids = List<String>.from(
          userDoc.data()?['favoriteCommerceIds'] ?? []);
      if (ids.isEmpty) return const Right([]);
      final results = await Future.wait(
        ids.map((id) => _datasource.getCommerce(id)),
      );
      return Right(results.cast<CommerceEntity>());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CommerceEntity>>> getUserFollowing(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final ids = List<String>.from(
          userDoc.data()?['followingCommerceIds'] ?? []);
      if (ids.isEmpty) return const Right([]);
      final results = await Future.wait(
        ids.map((id) => _datasource.getCommerce(id)),
      );
      return Right(results.cast<CommerceEntity>());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isUserFavorite({
    required String userId,
    required String commerceId,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final ids = List<String>.from(
          doc.data()?['favoriteCommerceIds'] ?? []);
      return Right(ids.contains(commerceId));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isUserFollowing({
    required String userId,
    required String commerceId,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final ids = List<String>.from(
          doc.data()?['followingCommerceIds'] ?? []);
      return Right(ids.contains(commerceId));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleFavorite({
    required String userId,
    required String commerceId,
  }) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final favorites = List<String>.from(userDoc.data()?['favoriteCommerceIds'] ?? []);

      if (favorites.contains(commerceId)) {
        await userRef.update({
          'favoriteCommerceIds': FieldValue.arrayRemove([commerceId]),
        });
      } else {
        await userRef.update({
          'favoriteCommerceIds': FieldValue.arrayUnion([commerceId]),
        });
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleFollow({
    required String userId,
    required String commerceId,
  }) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final following = List<String>.from(userDoc.data()?['followingCommerceIds'] ?? []);
      final commerceRef = FirebaseFirestore.instance.collection('commerces').doc(commerceId);

      if (following.contains(commerceId)) {
        await Future.wait([
          userRef.update({'followingCommerceIds': FieldValue.arrayRemove([commerceId])}),
          commerceRef.update({'followerCount': FieldValue.increment(-1)}),
        ]);
      } else {
        await Future.wait([
          userRef.update({'followingCommerceIds': FieldValue.arrayUnion([commerceId])}),
          commerceRef.update({'followerCount': FieldValue.increment(1)}),
        ]);
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadLogo({
    required String commerceId,
    required String filePath,
  }) async {
    try {
      final url = await _datasource.uploadLogo(
        commerceId: commerceId,
        filePath: filePath,
      );
      await FirebaseFirestore.instance
          .collection('commerces')
          .doc(commerceId)
          .update({'logoUrl': url});
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadGalleryImage({
    required String commerceId,
    required String filePath,
  }) async {
    try {
      final url = await _datasource.uploadGalleryImage(
        commerceId: commerceId,
        filePath: filePath,
      );
      await FirebaseFirestore.instance.collection('commerces').doc(commerceId).update({
        'galleryUrls': FieldValue.arrayUnion([url]),
      });
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGalleryImage({
    required String commerceId,
    required String imageUrl,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('commerces').doc(commerceId).update({
        'galleryUrls': FieldValue.arrayRemove([imageUrl]),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<CommerceEntity> watchCommerce(String id) =>
      _datasource.watchCommerce(id);

  @override
  Stream<List<CommerceEntity>> watchNearbyCommerces({
    required LatLng location,
    required double radiusKm,
  }) =>
      _datasource.watchNearbyCommerces(location: location, radiusKm: radiusKm);

  @override
  Future<Either<Failure, CommerceEntity>> getCommerceByOwnerId(String ownerId) async {
    try {
      final commerce = await _datasource.getCommerceByOwnerId(ownerId);
      if (commerce == null) return const Left(NotFoundFailure());
      return Right(commerce);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateBusinessHours({
    required String commerceId,
    required Map<String, BusinessHours> hours,
  }) async {
    try {
      final hoursMap = <String, dynamic>{};
      hours.forEach((day, h) {
        hoursMap[day] = {'isOpen': h.isOpen, 'openTime': h.openTime, 'closeTime': h.closeTime};
      });
      await FirebaseFirestore.instance.collection('commerces').doc(commerceId).update({
        'businessHours': hoursMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addEmployee({
    required String commerceId,
    required String employeeId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('commerces').doc(commerceId).update({
        'authorizedEmployeeIds': FieldValue.arrayUnion([employeeId]),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeEmployee({
    required String commerceId,
    required String employeeId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('commerces').doc(commerceId).update({
        'authorizedEmployeeIds': FieldValue.arrayRemove([employeeId]),
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCommerceAnalytics({
    required String commerceId,
    String period = 'week',
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getCommerceAnalytics')
          .call({'commerceId': commerceId, 'period': period});
      return Right(Map<String, dynamic>.from(result.data as Map));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAiSuggestions({
    required String commerceId,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getCampaignSuggestions')
          .call({'commerceId': commerceId});
      final data = result.data as Map;
      return Right(List<String>.from(data['suggestions'] as List? ?? []));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<int>>> getDailyCouponCounts({
    required String commerceId,
    int days = 30,
  }) async {
    try {
      final counts = await _datasource.getDailyCouponCounts(
        commerceId: commerceId,
        days: days,
      );
      return Right(counts);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRecentCouponActivity({
    required String commerceId,
    int limit = 5,
  }) async {
    try {
      final activity = await _datasource.getRecentCouponActivity(
        commerceId: commerceId,
        limit: limit,
      );
      return Right(activity);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
