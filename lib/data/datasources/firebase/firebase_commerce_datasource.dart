import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/geo_utils.dart';
import '../../models/commerce_model.dart';
import '../../../domain/entities/commerce_entity.dart';

class FirebaseCommerceDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebaseCommerceDatasource({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage;

  Future<CommerceModel> createCommerce(CommerceModel commerce) async {
    final ref = _firestore.collection(AppConstants.commercesCollection).doc();
    final model = CommerceModel.fromMap(
      {...commerce.toFirestore(), 'createdAt': Timestamp.now()},
      ref.id,
    );
    await ref.set(model.toFirestore());
    return model;
  }

  Future<CommerceModel> getCommerce(String id) async {
    final doc = await _firestore
        .collection(AppConstants.commercesCollection)
        .doc(id)
        .get();

    if (!doc.exists) throw Exception('Comercio no encontrado');
    return CommerceModel.fromFirestore(doc);
  }

  Future<void> updateCommerce(CommerceModel commerce) async {
    await _firestore
        .collection(AppConstants.commercesCollection)
        .doc(commerce.id)
        .update(commerce.toFirestore());
  }

  Future<List<CommerceModel>> getNearbyCommerces({
    required LatLng location,
    required double radiusKm,
    CommerceCategory? category,
    String? searchQuery,
    bool onlyOpen = false,
    bool onlyWithPromotions = false,
    CommercePlan? minPlan,
    int limit = 50,
  }) async {
    final geohash = GeoUtils.encodeGeohash(
      location.latitude,
      location.longitude,
      AppConstants.geohashPrecision,
    );

    // Geohash prefix query for proximity search
    final geohashPrefix = geohash.substring(0, 5);

    Query query = _firestore
        .collection(AppConstants.commercesCollection)
        .where('status', isEqualTo: CommerceStatus.active.name)
        .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
        .where('geohash', isLessThan: '${geohashPrefix}~')
        .limit(limit * 2);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (onlyOpen) {
      query = query.where('isCurrentlyOpen', isEqualTo: true);
    }

    if (onlyWithPromotions) {
      query = query.where('hasActivePromotion', isEqualTo: true);
    }

    final snapshot = await query.get();
    var results = snapshot.docs
        .map((doc) => CommerceModel.fromFirestore(doc))
        .toList();

    // Filter by actual distance
    results = results.where((commerce) {
      return GeoUtils.isWithinRadius(location, commerce.location, radiusKm);
    }).toList();

    // Sort by plan priority (featured first) then by distance
    results.sort((a, b) {
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      if (a.plan.index != b.plan.index) return b.plan.index.compareTo(a.plan.index);
      final distA = GeoUtils.calculateDistance(location, a.location);
      final distB = GeoUtils.calculateDistance(location, b.location);
      return distA.compareTo(distB);
    });

    return results.take(limit).toList();
  }

  Future<List<CommerceModel>> searchCommerces({
    required String query,
    CommerceCategory? category,
    LatLng? location,
    double? radiusKm,
    int limit = 20,
  }) async {
    final searchTerm = query.toLowerCase();

    Query firestoreQuery = _firestore
        .collection(AppConstants.commercesCollection)
        .where('status', isEqualTo: CommerceStatus.active.name)
        .where('searchTerms', arrayContains: searchTerm)
        .limit(limit);

    if (category != null) {
      firestoreQuery = firestoreQuery.where('category', isEqualTo: category.name);
    }

    final snapshot = await firestoreQuery.get();
    var results = snapshot.docs
        .map((doc) => CommerceModel.fromFirestore(doc))
        .toList();

    if (location != null && radiusKm != null) {
      results = results.where((c) =>
          GeoUtils.isWithinRadius(location, c.location, radiusKm)).toList();
    }

    return results;
  }

  Future<List<CommerceModel>> getFeaturedCommerces({
    LatLng? location,
    int limit = 10,
  }) async {
    Query query = _firestore
        .collection(AppConstants.commercesCollection)
        .where('status', isEqualTo: CommerceStatus.active.name)
        .where('isFeatured', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => CommerceModel.fromFirestore(doc)).toList();
  }

  Future<String> uploadLogo({
    required String commerceId,
    required String filePath,
  }) async {
    final ref = _storage.ref(
      '${AppConstants.commerceLogosPath}/$commerceId/logo.jpg',
    );
    await ref.putFile(File(filePath));
    return await ref.getDownloadURL();
  }

  Future<String> uploadGalleryImage({
    required String commerceId,
    required String filePath,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref(
      '${AppConstants.commerceGalleryPath}/$commerceId/$timestamp.jpg',
    );
    await ref.putFile(File(filePath));
    return await ref.getDownloadURL();
  }

  Stream<CommerceModel> watchCommerce(String id) {
    return _firestore
        .collection(AppConstants.commercesCollection)
        .doc(id)
        .snapshots()
        .map((doc) => CommerceModel.fromFirestore(doc));
  }

  Stream<List<CommerceModel>> watchNearbyCommerces({
    required LatLng location,
    required double radiusKm,
  }) {
    final geohash = GeoUtils.encodeGeohash(
      location.latitude,
      location.longitude,
      AppConstants.geohashPrecision,
    );
    final prefix = geohash.substring(0, 5);

    return _firestore
        .collection(AppConstants.commercesCollection)
        .where('status', isEqualTo: CommerceStatus.active.name)
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThan: '${prefix}~')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommerceModel.fromFirestore(doc))
            .where((c) => GeoUtils.isWithinRadius(location, c.location, radiusKm))
            .toList());
  }

  Future<CommerceModel?> getCommerceByOwnerId(String ownerId) async {
    final snapshot = await _firestore
        .collection(AppConstants.commercesCollection)
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return CommerceModel.fromFirestore(snapshot.docs.first);
  }

  Future<List<int>> getDailyCouponCounts({
    required String commerceId,
    int days = 30,
  }) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _firestore
        .collection(AppConstants.couponsCollection)
        .where('commerceId', isEqualTo: commerceId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    final counts = List<int>.filled(days, 0);
    for (final doc in snapshot.docs) {
      final ts = doc.data()['createdAt'];
      if (ts is Timestamp) {
        final daysAgo = DateTime.now().difference(ts.toDate()).inDays;
        if (daysAgo < days) {
          counts[days - 1 - daysAgo]++;
        }
      }
    }
    return counts;
  }

  Future<List<Map<String, dynamic>>> getRecentCouponActivity({
    required String commerceId,
    int limit = 5,
  }) async {
    final snapshot = await _firestore
        .collection(AppConstants.couponsCollection)
        .where('commerceId', isEqualTo: commerceId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final isUsed = data['status'] == 'used';
          final Timestamp? ts = isUsed
              ? data['usedAt'] as Timestamp?
              : data['createdAt'] as Timestamp?;
          return {
            'title': isUsed ? 'CupÃ³n canjeado' : 'CupÃ³n reclamado',
            'time': ts != null ? _timeAgo(ts.toDate()) : '',
            'isUsed': isUsed,
          };
        })
        .take(limit)
        .toList();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} dÃ­a${diff.inDays > 1 ? "s" : ""}';
  }
}
