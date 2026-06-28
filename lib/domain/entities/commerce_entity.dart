import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum CommerceStatus { active, inactive, pending, suspended, verified }

enum CommercePlan { free, basic, premium, enterprise }

enum CommerceCategory {
  // Gastronomía
  restaurants,
  cafes,
  fastFood,
  bar,
  bakery,
  // Salud y bienestar
  pharmacies,
  health,
  beauty,
  // Comercio general
  clothing,
  supermarket,
  hardware,
  jewelry,
  market,
  // Emprendedores
  streetVendor,
  entrepreneur,
  // Servicios
  services,
  automotive,
  education,
  // Ocio y tecnología
  technology,
  entertainment,
  sports,
  tourism,
  // Otras
  pets,
  other,
}

class BusinessHours extends Equatable {
  final bool isOpen;
  final String? openTime;
  final String? closeTime;

  const BusinessHours({
    required this.isOpen,
    this.openTime,
    this.closeTime,
  });

  @override
  List<Object?> get props => [isOpen, openTime, closeTime];
}

class CommerceEntity extends Equatable {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String? logoUrl;
  final List<String> galleryUrls;
  final CommerceCategory category;
  final List<CommerceCategory> subCategories;
  final CommercePlan plan;
  final CommerceStatus status;
  final LatLng location;
  final String geohash;
  final String address;
  final String city;
  final String country;
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String> socialLinks;
  final Map<String, BusinessHours> businessHours;
  final double rating;
  final int reviewCount;
  final int followerCount;
  final int activePromotionsCount;
  final bool isCurrentlyOpen;
  final bool hasActivePromotion;
  final bool isVerified;
  final bool isFeatured;
  final List<String> tags;
  final Map<String, dynamic> pointsConfig;
  final List<String> authorizedEmployeeIds;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? taxId;
  final String? legalName;

  const CommerceEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    this.logoUrl,
    this.galleryUrls = const [],
    required this.category,
    this.subCategories = const [],
    this.plan = CommercePlan.free,
    this.status = CommerceStatus.pending,
    required this.location,
    required this.geohash,
    required this.address,
    required this.city,
    this.country = 'Argentina',
    this.phone,
    this.email,
    this.website,
    this.socialLinks = const {},
    this.businessHours = const {},
    this.rating = 0.0,
    this.reviewCount = 0,
    this.followerCount = 0,
    this.activePromotionsCount = 0,
    this.isCurrentlyOpen = false,
    this.hasActivePromotion = false,
    this.isVerified = false,
    this.isFeatured = false,
    this.tags = const [],
    this.pointsConfig = const {},
    this.authorizedEmployeeIds = const [],
    required this.createdAt,
    this.verifiedAt,
    this.taxId,
    this.legalName,
  });

  String get categoryDisplayName {
    switch (category) {
      case CommerceCategory.restaurants: return 'Restaurante';
      case CommerceCategory.cafes: return 'Cafetería';
      case CommerceCategory.fastFood: return 'Comida Rápida';
      case CommerceCategory.bar: return 'Bar / Pub';
      case CommerceCategory.bakery: return 'Panadería';
      case CommerceCategory.pharmacies: return 'Farmacia';
      case CommerceCategory.health: return 'Salud';
      case CommerceCategory.beauty: return 'Belleza';
      case CommerceCategory.clothing: return 'Indumentaria';
      case CommerceCategory.supermarket: return 'Supermercado';
      case CommerceCategory.hardware: return 'Ferretería';
      case CommerceCategory.jewelry: return 'Joyería';
      case CommerceCategory.market: return 'Feria / Mercado';
      case CommerceCategory.streetVendor: return 'Vendedor Ambulante';
      case CommerceCategory.entrepreneur: return 'Emprendimiento';
      case CommerceCategory.services: return 'Servicios';
      case CommerceCategory.automotive: return 'Automotriz';
      case CommerceCategory.education: return 'Educación';
      case CommerceCategory.technology: return 'Tecnología';
      case CommerceCategory.entertainment: return 'Entretenimiento';
      case CommerceCategory.sports: return 'Deportes';
      case CommerceCategory.tourism: return 'Turismo';
      case CommerceCategory.pets: return 'Mascotas';
      case CommerceCategory.other: return 'Otros';
    }
  }

  String get planDisplayName {
    switch (plan) {
      case CommercePlan.free: return 'Gratuito';
      case CommercePlan.basic: return 'BÃ¡sico';
      case CommercePlan.premium: return 'Premium';
      case CommercePlan.enterprise: return 'Empresarial';
    }
  }

  int get maxActivePromotions {
    switch (plan) {
      case CommercePlan.free: return 2;
      case CommercePlan.basic: return -1;
      case CommercePlan.premium: return -1;
      case CommercePlan.enterprise: return -1;
    }
  }

  CommerceEntity copyWith({
    String? name,
    String? description,
    String? logoUrl,
    List<String>? galleryUrls,
    CommerceCategory? category,
    CommercePlan? plan,
    CommerceStatus? status,
    LatLng? location,
    String? geohash,
    String? address,
    String? city,
    String? phone,
    String? website,
    Map<String, String>? socialLinks,
    Map<String, BusinessHours>? businessHours,
    double? rating,
    int? reviewCount,
    int? followerCount,
    int? activePromotionsCount,
    bool? isCurrentlyOpen,
    bool? hasActivePromotion,
    bool? isVerified,
    bool? isFeatured,
    List<String>? tags,
    Map<String, dynamic>? pointsConfig,
  }) {
    return CommerceEntity(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      category: category ?? this.category,
      subCategories: subCategories,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      location: location ?? this.location,
      geohash: geohash ?? this.geohash,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country,
      phone: phone ?? this.phone,
      email: email,
      website: website ?? this.website,
      socialLinks: socialLinks ?? this.socialLinks,
      businessHours: businessHours ?? this.businessHours,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      followerCount: followerCount ?? this.followerCount,
      activePromotionsCount: activePromotionsCount ?? this.activePromotionsCount,
      isCurrentlyOpen: isCurrentlyOpen ?? this.isCurrentlyOpen,
      hasActivePromotion: hasActivePromotion ?? this.hasActivePromotion,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      tags: tags ?? this.tags,
      pointsConfig: pointsConfig ?? this.pointsConfig,
      authorizedEmployeeIds: authorizedEmployeeIds,
      createdAt: createdAt,
      verifiedAt: verifiedAt,
      taxId: taxId,
      legalName: legalName,
    );
  }

  @override
  List<Object?> get props => [id, name, status, plan, location];
}
