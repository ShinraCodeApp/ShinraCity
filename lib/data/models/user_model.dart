import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.displayName,
    super.photoUrl,
    super.phoneNumber,
    super.role,
    super.level,
    super.totalPoints,
    super.availablePoints,
    super.totalCouponsRedeemed,
    super.totalSavings,
    super.favoriteCommerceIds,
    super.followingCategories,
    super.followingCommerceIds,
    super.badgeIds,
    super.achievementIds,
    super.lastLocation,
    super.isActive,
    super.isVerified,
    super.notificationsEnabled,
    super.locationEnabled,
    super.fcmToken,
    super.authProvider,
    required super.createdAt,
    super.lastActiveAt,
    super.referralCode,
    super.referredBy,
    super.bio,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    LatLng? location;
    if (map['lastLocation'] != null) {
      final geo = map['lastLocation'] as GeoPoint;
      location = LatLng(geo.latitude, geo.longitude);
    }

    return UserModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      phoneNumber: map['phoneNumber'],
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.user,
      ),
      level: UserLevel.values.firstWhere(
        (l) => l.name == map['level'],
        orElse: () => UserLevel.explorer,
      ),
      totalPoints: map['totalPoints'] ?? 0,
      availablePoints: map['availablePoints'] ?? 0,
      totalCouponsRedeemed: map['totalCouponsRedeemed'] ?? 0,
      totalSavings: map['totalSavings'] ?? 0,
      favoriteCommerceIds: List<String>.from(map['favoriteCommerceIds'] ?? []),
      followingCategories: List<String>.from(map['followingCategories'] ?? []),
      followingCommerceIds: List<String>.from(map['followingCommerceIds'] ?? []),
      badgeIds: List<String>.from(map['badgeIds'] ?? []),
      achievementIds: List<String>.from(map['achievementIds'] ?? []),
      lastLocation: location,
      isActive: map['isActive'] ?? true,
      isVerified: map['isVerified'] ?? false,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      locationEnabled: map['locationEnabled'] ?? true,
      fcmToken: map['fcmToken'],
      authProvider: AuthProvider.values.firstWhere(
        (p) => p.name == map['authProvider'],
        orElse: () => AuthProvider.email,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (map['lastActiveAt'] as Timestamp?)?.toDate(),
      referralCode: map['referralCode'],
      referredBy: map['referredBy'],
      bio: map['bio'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'level': level.name,
      'totalPoints': totalPoints,
      'availablePoints': availablePoints,
      'totalCouponsRedeemed': totalCouponsRedeemed,
      'totalSavings': totalSavings,
      'favoriteCommerceIds': favoriteCommerceIds,
      'followingCategories': followingCategories,
      'followingCommerceIds': followingCommerceIds,
      'badgeIds': badgeIds,
      'achievementIds': achievementIds,
      'lastLocation': lastLocation != null
          ? GeoPoint(lastLocation!.latitude, lastLocation!.longitude)
          : null,
      'isActive': isActive,
      'isVerified': isVerified,
      'notificationsEnabled': notificationsEnabled,
      'locationEnabled': locationEnabled,
      'fcmToken': fcmToken,
      'authProvider': authProvider.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'bio': bio,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
