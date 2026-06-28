import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../models/promotion_model.dart';

class FirebasePromotionDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebasePromotionDatasource({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage;

  Future<PromotionModel> createPromotion(PromotionModel promotion) async {
    final ref = _firestore.collection(AppConstants.promotionsCollection).doc();
    final data = {
      ...promotion.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data);

    // Update commerce activePromotionsCount
    if (promotion.status == PromotionStatus.active) {
      await _firestore
          .collection(AppConstants.commercesCollection)
          .doc(promotion.commerceId)
          .update({
        'activePromotionsCount': FieldValue.increment(1),
        'hasActivePromotion': true,
      });
    }

    return PromotionModel.fromMap({...data, 'id': ref.id}, ref.id);
  }

  Future<PromotionModel> getPromotion(String id) async {
    final doc = await _firestore
        .collection(AppConstants.promotionsCollection)
        .doc(id)
        .get();
    if (!doc.exists) throw Exception('PromociÃ³n no encontrada');
    return PromotionModel.fromFirestore(doc);
  }

  Future<void> updatePromotion(PromotionModel promotion) async {
    await _firestore
        .collection(AppConstants.promotionsCollection)
        .doc(promotion.id)
        .update(promotion.toFirestore());
  }

  Future<void> changeStatus({
    required String promotionId,
    required String commerceId,
    required PromotionStatus newStatus,
    required PromotionStatus oldStatus,
  }) async {
    final batch = _firestore.batch();
    final promoRef = _firestore
        .collection(AppConstants.promotionsCollection)
        .doc(promotionId);
    final commerceRef = _firestore
        .collection(AppConstants.commercesCollection)
        .doc(commerceId);

    batch.update(promoRef, {
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Sync commerce active count
    if (newStatus == PromotionStatus.active && oldStatus != PromotionStatus.active) {
      batch.update(commerceRef, {
        'activePromotionsCount': FieldValue.increment(1),
        'hasActivePromotion': true,
      });
    } else if (oldStatus == PromotionStatus.active && newStatus != PromotionStatus.active) {
      batch.update(commerceRef, {
        'activePromotionsCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();
  }

  Future<List<PromotionModel>> getNearbyPromotions({
    required LatLng location,
    required double radiusKm,
    List<String>? categories,
    bool onlyActive = true,
    int limit = 50,
  }) async {
    // Get active promotions from nearby commerces
    final geohash = GeoUtils.encodeGeohash(
      location.latitude,
      location.longitude,
      AppConstants.geohashPrecision,
    );
    final prefix = geohash.substring(0, 5);

    // First get nearby commerce IDs
    final commercesSnapshot = await _firestore
        .collection(AppConstants.commercesCollection)
        .where('status', isEqualTo: 'active')
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThan: '${prefix}~')
        .limit(30)
        .get();

    if (commercesSnapshot.docs.isEmpty) return [];

    final commerceIds = commercesSnapshot.docs.map((d) => d.id).toList();

    // Firestore whereIn max 30 items
    final batches = <List<String>>[];
    for (var i = 0; i < commerceIds.length; i += 10) {
      batches.add(commerceIds.sublist(i, i + 10 > commerceIds.length ? commerceIds.length : i + 10));
    }

    final allPromotions = <PromotionModel>[];
    for (final batch in batches) {
      Query query = _firestore
          .collection(AppConstants.promotionsCollection)
          .where('commerceId', whereIn: batch)
          .where('endDate', isGreaterThan: Timestamp.now());

      if (onlyActive) {
        query = query.where('status', isEqualTo: PromotionStatus.active.name);
      }

      final snapshot = await query.limit(limit).get();
      allPromotions.addAll(
        snapshot.docs.map((d) => PromotionModel.fromFirestore(d)),
      );
    }

    // Sort by featured commerce plan (premium first), then by recency
    allPromotions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return allPromotions.take(limit).toList();
  }

  Future<List<PromotionModel>> getCommercePromotions({
    required String commerceId,
    PromotionStatus? status,
    int limit = 20,
  }) async {
    Query query = _firestore
        .collection(AppConstants.promotionsCollection)
        .where('commerceId', isEqualTo: commerceId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((d) => PromotionModel.fromFirestore(d)).toList();
  }

  Future<List<PromotionModel>> getFeaturedPromotions({int limit = 10}) async {
    final snapshot = await _firestore
        .collection(AppConstants.promotionsCollection)
        .where('status', isEqualTo: PromotionStatus.active.name)
        .where('endDate', isGreaterThan: Timestamp.now())
        .orderBy('endDate')
        .orderBy('claimCount', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((d) => PromotionModel.fromFirestore(d)).toList();
  }

  Future<String> uploadPromotionImage({
    required String promotionId,
    required String filePath,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref(
      '${AppConstants.promotionImagesPath}/$promotionId/$timestamp.jpg',
    );
    await ref.putFile(File(filePath));
    return await ref.getDownloadURL();
  }

  Future<void> incrementViewCount(String promotionId) async {
    await _firestore
        .collection(AppConstants.promotionsCollection)
        .doc(promotionId)
        .update({'viewCount': FieldValue.increment(1)});
  }

  Stream<List<PromotionModel>> watchActivePromotions({int limit = 100}) {
    return _firestore
        .collection(AppConstants.promotionsCollection)
        .where('status', isEqualTo: PromotionStatus.active.name)
        .where('endDate', isGreaterThan: Timestamp.now())
        .orderBy('endDate')
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => PromotionModel.fromFirestore(d)).toList());
  }

  Stream<List<PromotionModel>> watchCommercePromotions(String commerceId) {
    return _firestore
        .collection(AppConstants.promotionsCollection)
        .where('commerceId', isEqualTo: commerceId)
        .where('status', whereIn: [
          PromotionStatus.active.name,
          PromotionStatus.scheduled.name,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PromotionModel.fromFirestore(d)).toList());
  }

  // Auto-expire promotions (called from scheduled function)
  Future<void> expirePromotions() async {
    final now = Timestamp.now();
    final expired = await _firestore
        .collection(AppConstants.promotionsCollection)
        .where('status', isEqualTo: PromotionStatus.active.name)
        .where('endDate', isLessThan: now)
        .limit(100)
        .get();

    final batch = _firestore.batch();
    final commerceIds = <String>{};

    for (final doc in expired.docs) {
      batch.update(doc.reference, {
        'status': PromotionStatus.expired.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      commerceIds.add(doc.data()['commerceId'] as String);
    }

    await batch.commit();

    // Update commerce hasActivePromotion flag
    for (final cid in commerceIds) {
      final remaining = await _firestore
          .collection(AppConstants.promotionsCollection)
          .where('commerceId', isEqualTo: cid)
          .where('status', isEqualTo: PromotionStatus.active.name)
          .count()
          .get();

      await _firestore.collection(AppConstants.commercesCollection).doc(cid).update({
        'hasActivePromotion': remaining.count! > 0,
        'activePromotionsCount': remaining.count,
      });
    }
  }
}
