import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum PromotionType {
  hourly,
  daily,
  weekly,
  monthly,
  limited,
  geolocated,
  followers,
  vip,
  discount,
  twoForOne,
  freeItem,
  happyHour,
  cashback,
  fidelity,
  combo,
  event,
}

enum PromotionStatus {
  draft,
  active,
  paused,
  expired,
  cancelled,
  scheduled,
}

enum DiscountType {
  percentage,
  fixedAmount,
  twoForOne,
  freeItem,
  pointsMultiplier,
  gift,
}

class PromotionEntity extends Equatable {
  final String id;
  final String commerceId;
  final String commerceName;
  final String? commerceLogoUrl;
  final String title;
  final String? description;
  final List<String> imageUrls;
  final PromotionType type;
  final PromotionStatus status;
  final DiscountType discountType;
  final double discountValue;
  final String? discountDescription;
  final DateTime startDate;
  final DateTime endDate;
  final int? totalSlots;
  final int usedSlots;
  final int? dailyLimit;
  final int? perUserLimit;
  final String? conditions;
  final List<String> categories;
  final bool isExclusiveForFollowers;
  final bool isVip;
  final bool isGeolocated;
  final LatLng? geoLocation;
  final double? geoRadius;
  final double originalPrice;
  final double? discountedPrice;
  final int? pointsRequired;
  final int? pointsAwarded;
  final bool requiresCode;
  final String? promoCode;
  final DateTime createdAt;
  final int viewCount;
  final int claimCount;
  final double? savedAmount;

  const PromotionEntity({
    required this.id,
    required this.commerceId,
    required this.commerceName,
    this.commerceLogoUrl,
    required this.title,
    required this.description,
    this.imageUrls = const [],
    required this.type,
    this.status = PromotionStatus.draft,
    required this.discountType,
    required this.discountValue,
    this.discountDescription,
    required this.startDate,
    required this.endDate,
    this.totalSlots,
    this.usedSlots = 0,
    this.dailyLimit,
    this.perUserLimit = 1,
    this.conditions,
    this.categories = const [],
    this.isExclusiveForFollowers = false,
    this.isVip = false,
    this.isGeolocated = false,
    this.geoLocation,
    this.geoRadius,
    required this.originalPrice,
    this.discountedPrice,
    this.pointsRequired,
    this.pointsAwarded,
    this.requiresCode = false,
    this.promoCode,
    required this.createdAt,
    this.viewCount = 0,
    this.claimCount = 0,
    this.savedAmount,
  });

  bool get isActive => status == PromotionStatus.active;

  bool get isExpired =>
      status == PromotionStatus.expired ||
      DateTime.now().isAfter(endDate);

  bool get hasAvailableSlots =>
      totalSlots == null || usedSlots < totalSlots!;

  int? get remainingSlots =>
      totalSlots == null ? null : totalSlots! - usedSlots;

  double get discountPercentage {
    if (discountType == DiscountType.percentage) return discountValue;
    if (originalPrice > 0 && discountedPrice != null) {
      return ((originalPrice - discountedPrice!) / originalPrice) * 100;
    }
    return 0;
  }

  Duration get timeRemaining => endDate.difference(DateTime.now());

  String get typeDisplayName {
    switch (type) {
      case PromotionType.hourly: return 'Por Horas';
      case PromotionType.daily: return 'Diaria';
      case PromotionType.weekly: return 'Semanal';
      case PromotionType.monthly: return 'Mensual';
      case PromotionType.limited: return 'Cupos Limitados';
      case PromotionType.geolocated: return 'Geolocalizada';
      case PromotionType.followers: return 'Solo Seguidores';
      case PromotionType.vip: return 'VIP';
      case PromotionType.discount: return 'Descuento';
      case PromotionType.twoForOne: return '2x1';
      case PromotionType.freeItem: return 'Producto Gratis';
      case PromotionType.happyHour: return 'Happy Hour';
      case PromotionType.cashback: return 'Cashback';
      case PromotionType.fidelity: return 'Fidelidad';
      case PromotionType.combo: return 'Combo';
      case PromotionType.event: return 'Evento';
    }
  }

  @override
  List<Object?> get props => [id, commerceId, title, status, startDate, endDate];
}
