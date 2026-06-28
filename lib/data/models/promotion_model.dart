import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/promotion_entity.dart';

class PromotionModel extends PromotionEntity {
  const PromotionModel({
    required super.id,
    required super.commerceId,
    required super.commerceName,
    super.commerceLogoUrl,
    required super.title,
    required super.description,
    super.imageUrls,
    required super.type,
    super.status,
    required super.discountType,
    required super.discountValue,
    super.discountDescription,
    required super.startDate,
    required super.endDate,
    super.totalSlots,
    super.usedSlots,
    super.dailyLimit,
    super.perUserLimit,
    super.conditions,
    super.categories,
    super.isExclusiveForFollowers,
    super.isVip,
    super.isGeolocated,
    super.geoLocation,
    super.geoRadius,
    required super.originalPrice,
    super.discountedPrice,
    super.pointsRequired,
    super.pointsAwarded,
    super.requiresCode,
    super.promoCode,
    required super.createdAt,
    super.viewCount,
    super.claimCount,
    super.savedAmount,
  });

  factory PromotionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromotionModel.fromMap(data, doc.id);
  }

  factory PromotionModel.fromMap(Map<String, dynamic> map, String id) {
    LatLng? geoLocation;
    if (map['geoLocation'] != null) {
      final geo = map['geoLocation'] as GeoPoint;
      geoLocation = LatLng(geo.latitude, geo.longitude);
    }

    return PromotionModel(
      id: id,
      commerceId: map['commerceId'] ?? '',
      commerceName: map['commerceName'] ?? '',
      commerceLogoUrl: map['commerceLogoUrl'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      type: PromotionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => PromotionType.daily,
      ),
      status: PromotionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PromotionStatus.draft,
      ),
      discountType: DiscountType.values.firstWhere(
        (d) => d.name == map['discountType'],
        orElse: () => DiscountType.percentage,
      ),
      discountValue: (map['discountValue'] ?? 0).toDouble(),
      discountDescription: map['discountDescription'],
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
      totalSlots: map['totalSlots'],
      usedSlots: map['usedSlots'] ?? 0,
      dailyLimit: map['dailyLimit'],
      perUserLimit: map['perUserLimit'] ?? 1,
      conditions: map['conditions'],
      categories: List<String>.from(map['categories'] ?? []),
      isExclusiveForFollowers: map['isExclusiveForFollowers'] ?? false,
      isVip: map['isVip'] ?? false,
      isGeolocated: map['isGeolocated'] ?? false,
      geoLocation: geoLocation,
      geoRadius: (map['geoRadius'] as num?)?.toDouble(),
      originalPrice: (map['originalPrice'] ?? 0).toDouble(),
      discountedPrice: (map['discountedPrice'] as num?)?.toDouble(),
      pointsRequired: map['pointsRequired'],
      pointsAwarded: map['pointsAwarded'] ?? 10,
      requiresCode: map['requiresCode'] ?? false,
      promoCode: map['promoCode'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewCount: map['viewCount'] ?? 0,
      claimCount: map['claimCount'] ?? 0,
      savedAmount: (map['savedAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'commerceId': commerceId,
      'commerceName': commerceName,
      'commerceLogoUrl': commerceLogoUrl,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'type': type.name,
      'status': status.name,
      'discountType': discountType.name,
      'discountValue': discountValue,
      'discountDescription': discountDescription,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalSlots': totalSlots,
      'usedSlots': usedSlots,
      'dailyLimit': dailyLimit,
      'perUserLimit': perUserLimit,
      'conditions': conditions,
      'categories': categories,
      'isExclusiveForFollowers': isExclusiveForFollowers,
      'isVip': isVip,
      'isGeolocated': isGeolocated,
      'geoLocation': geoLocation != null
          ? GeoPoint(geoLocation!.latitude, geoLocation!.longitude)
          : null,
      'geoRadius': geoRadius,
      'originalPrice': originalPrice,
      'discountedPrice': discountedPrice,
      'pointsRequired': pointsRequired,
      'pointsAwarded': pointsAwarded,
      'requiresCode': requiresCode,
      'promoCode': promoCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewCount': viewCount,
      'claimCount': claimCount,
      'savedAmount': savedAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
