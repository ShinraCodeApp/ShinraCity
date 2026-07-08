import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/commerce_entity.dart';

class CommerceModel extends CommerceEntity {
  const CommerceModel({
    required super.id,
    required super.ownerId,
    required super.name,
    required super.description,
    super.logoUrl,
    super.galleryUrls,
    required super.category,
    super.subCategories,
    super.plan,
    super.status,
    required super.location,
    required super.geohash,
    required super.address,
    required super.city,
    super.country,
    super.phone,
    super.email,
    super.website,
    super.socialLinks,
    super.businessHours,
    super.rating,
    super.reviewCount,
    super.followerCount,
    super.activePromotionsCount,
    super.isCurrentlyOpen,
    super.hasActivePromotion,
    super.isVerified,
    super.isFeatured,
    super.isAmbulant,
    super.liveLocation,
    super.liveLocationUpdatedAt,
    super.tags,
    super.pointsConfig,
    super.authorizedEmployeeIds,
    required super.createdAt,
    super.verifiedAt,
    super.taxId,
    super.legalName,
  });

  factory CommerceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommerceModel.fromMap(data, doc.id);
  }

  factory CommerceModel.fromMap(Map<String, dynamic> map, String id) {
    final geoPoint = map['location'] as GeoPoint;
    final location = LatLng(geoPoint.latitude, geoPoint.longitude);

    final businessHoursMap = <String, BusinessHours>{};
    if (map['businessHours'] != null) {
      (map['businessHours'] as Map<String, dynamic>).forEach((day, value) {
        final hours = value as Map<String, dynamic>;
        businessHoursMap[day] = BusinessHours(
          isOpen: hours['isOpen'] ?? false,
          openTime: hours['openTime'],
          closeTime: hours['closeTime'],
        );
      });
    }

    return CommerceModel(
      id: id,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      logoUrl: map['logoUrl'],
      galleryUrls: List<String>.from(map['galleryUrls'] ?? []),
      category: CommerceCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => CommerceCategory.other,
      ),
      subCategories: (map['subCategories'] as List<dynamic>? ?? [])
          .map((c) => CommerceCategory.values.firstWhere(
                (cat) => cat.name == c,
                orElse: () => CommerceCategory.other,
              ))
          .toList(),
      plan: CommercePlan.values.firstWhere(
        (p) => p.name == map['plan'],
        orElse: () => CommercePlan.free,
      ),
      status: CommerceStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => CommerceStatus.pending,
      ),
      location: location,
      geohash: map['geohash'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? 'Argentina',
      phone: map['phone'],
      email: map['email'],
      website: map['website'],
      socialLinks: Map<String, String>.from(map['socialLinks'] ?? {}),
      businessHours: businessHoursMap,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      followerCount: map['followerCount'] ?? 0,
      activePromotionsCount: map['activePromotionsCount'] ?? 0,
      isCurrentlyOpen: map['isCurrentlyOpen'] ?? false,
      hasActivePromotion: map['hasActivePromotion'] ?? false,
      isVerified: map['isVerified'] ?? false,
      isFeatured: map['isFeatured'] ?? false,
      isAmbulant: map['isAmbulant'] ?? false,
      liveLocation: map['liveLocation'] != null
          ? LatLng((map['liveLocation'] as GeoPoint).latitude,
              (map['liveLocation'] as GeoPoint).longitude)
          : null,
      liveLocationUpdatedAt:
          (map['liveLocationUpdatedAt'] as Timestamp?)?.toDate(),
      tags: List<String>.from(map['tags'] ?? []),
      pointsConfig: Map<String, dynamic>.from(map['pointsConfig'] ?? {}),
      authorizedEmployeeIds: List<String>.from(map['authorizedEmployeeIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt: (map['verifiedAt'] as Timestamp?)?.toDate(),
      taxId: map['taxId'],
      legalName: map['legalName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    final businessHoursMap = <String, dynamic>{};
    businessHours.forEach((day, hours) {
      businessHoursMap[day] = {
        'isOpen': hours.isOpen,
        'openTime': hours.openTime,
        'closeTime': hours.closeTime,
      };
    });

    return {
      'ownerId': ownerId,
      'name': name,
      'nameLowercase': name.toLowerCase(),
      'description': description,
      'logoUrl': logoUrl,
      'galleryUrls': galleryUrls,
      'category': category.name,
      'subCategories': subCategories.map((c) => c.name).toList(),
      'plan': plan.name,
      'status': status.name,
      'location': GeoPoint(location.latitude, location.longitude),
      'geohash': geohash,
      'address': address,
      'city': city,
      'country': country,
      'phone': phone,
      'email': email,
      'website': website,
      'socialLinks': socialLinks,
      'businessHours': businessHoursMap,
      'rating': rating,
      'reviewCount': reviewCount,
      'followerCount': followerCount,
      'activePromotionsCount': activePromotionsCount,
      'isCurrentlyOpen': isCurrentlyOpen,
      'hasActivePromotion': hasActivePromotion,
      'isVerified': isVerified,
      'isFeatured': isFeatured,
      'isAmbulant': isAmbulant,
      if (liveLocation != null)
        'liveLocation': GeoPoint(liveLocation!.latitude, liveLocation!.longitude),
      if (liveLocationUpdatedAt != null)
        'liveLocationUpdatedAt': Timestamp.fromDate(liveLocationUpdatedAt!),
      'tags': tags,
      'pointsConfig': pointsConfig,
      'authorizedEmployeeIds': authorizedEmployeeIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'taxId': taxId,
      'legalName': legalName,
      'updatedAt': FieldValue.serverTimestamp(),
      'searchTerms': _generateSearchTerms(),
    };
  }

  List<String> _generateSearchTerms() {
    final terms = <String>{};
    final words = name.toLowerCase().split(' ');
    for (final word in words) {
      for (var i = 1; i <= word.length; i++) {
        terms.add(word.substring(0, i));
      }
    }
    terms.add(category.name.toLowerCase());
    terms.addAll(tags.map((t) => t.toLowerCase()));
    return terms.toList();
  }
}
