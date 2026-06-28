import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum UserRole { user, businessOwner, employee, admin, superAdmin }

enum UserLevel { explorer, frequent, exemplary, ambassador, lifetime }

extension UserLevelX on UserLevel {
  String get levelDisplayName {
    switch (this) {
      case UserLevel.explorer: return 'Explorador';
      case UserLevel.frequent: return 'Cliente Frecuente';
      case UserLevel.exemplary: return 'Cliente Ejemplar';
      case UserLevel.ambassador: return 'Embajador';
      case UserLevel.lifetime: return 'Socio Vitalicio';
    }
  }

  int? get nextLevelPoints {
    switch (this) {
      case UserLevel.explorer: return 500;
      case UserLevel.frequent: return 2000;
      case UserLevel.exemplary: return 5000;
      case UserLevel.ambassador: return 15000;
      case UserLevel.lifetime: return null;
    }
  }

  double levelProgress(int currentPoints) {
    final next = nextLevelPoints;
    if (next == null || currentPoints >= next) return 1.0;
    final previous = _previousThreshold;
    if (next == previous) return 1.0;
    return (currentPoints - previous) / (next - previous);
  }

  int get _previousThreshold {
    switch (this) {
      case UserLevel.explorer: return 0;
      case UserLevel.frequent: return 500;
      case UserLevel.exemplary: return 2000;
      case UserLevel.ambassador: return 5000;
      case UserLevel.lifetime: return 15000;
    }
  }
}

enum AuthProvider { email, google, apple, facebook }

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final UserRole role;
  final UserLevel level;
  final int totalPoints;
  final int availablePoints;
  final int totalCouponsRedeemed;
  final int totalSavings;
  final List<String> favoriteCommerceIds;
  final List<String> followingCategories;
  final List<String> followingCommerceIds;
  final List<String> badgeIds;
  final List<String> achievementIds;
  final LatLng? lastLocation;
  final bool isActive;
  final bool isVerified;
  final bool notificationsEnabled;
  final bool locationEnabled;
  final String? fcmToken;
  final AuthProvider authProvider;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final String? referralCode;
  final String? referredBy;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.role = UserRole.user,
    this.level = UserLevel.explorer,
    this.totalPoints = 0,
    this.availablePoints = 0,
    this.totalCouponsRedeemed = 0,
    this.totalSavings = 0,
    this.favoriteCommerceIds = const [],
    this.followingCategories = const [],
    this.followingCommerceIds = const [],
    this.badgeIds = const [],
    this.achievementIds = const [],
    this.lastLocation,
    this.isActive = true,
    this.isVerified = false,
    this.notificationsEnabled = true,
    this.locationEnabled = true,
    this.fcmToken,
    this.authProvider = AuthProvider.email,
    required this.createdAt,
    this.lastActiveAt,
    this.referralCode,
    this.referredBy,
  });

  String get levelDisplayName {
    switch (level) {
      case UserLevel.explorer: return 'Explorador';
      case UserLevel.frequent: return 'Cliente Frecuente';
      case UserLevel.exemplary: return 'Cliente Ejemplar';
      case UserLevel.ambassador: return 'Embajador';
      case UserLevel.lifetime: return 'Socio Vitalicio';
    }
  }

  int get nextLevelPoints {
    switch (level) {
      case UserLevel.explorer: return 500;
      case UserLevel.frequent: return 2000;
      case UserLevel.exemplary: return 5000;
      case UserLevel.ambassador: return 15000;
      case UserLevel.lifetime: return 15000;
    }
  }

  double get levelProgress {
    final current = totalPoints;
    final next = nextLevelPoints;
    if (current >= next) return 1.0;
    return current / next;
  }

  UserEntity copyWith({
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    UserRole? role,
    UserLevel? level,
    int? totalPoints,
    int? availablePoints,
    int? totalCouponsRedeemed,
    int? totalSavings,
    List<String>? favoriteCommerceIds,
    List<String>? followingCategories,
    List<String>? followingCommerceIds,
    List<String>? badgeIds,
    List<String>? achievementIds,
    LatLng? lastLocation,
    bool? isActive,
    bool? isVerified,
    bool? notificationsEnabled,
    bool? locationEnabled,
    String? fcmToken,
    DateTime? lastActiveAt,
  }) {
    return UserEntity(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      level: level ?? this.level,
      totalPoints: totalPoints ?? this.totalPoints,
      availablePoints: availablePoints ?? this.availablePoints,
      totalCouponsRedeemed: totalCouponsRedeemed ?? this.totalCouponsRedeemed,
      totalSavings: totalSavings ?? this.totalSavings,
      favoriteCommerceIds: favoriteCommerceIds ?? this.favoriteCommerceIds,
      followingCategories: followingCategories ?? this.followingCategories,
      followingCommerceIds: followingCommerceIds ?? this.followingCommerceIds,
      badgeIds: badgeIds ?? this.badgeIds,
      achievementIds: achievementIds ?? this.achievementIds,
      lastLocation: lastLocation ?? this.lastLocation,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
      authProvider: authProvider,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      referralCode: referralCode,
      referredBy: referredBy,
    );
  }

  @override
  List<Object?> get props => [id, email, role, level, totalPoints];
}
