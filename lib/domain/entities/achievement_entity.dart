import 'package:equatable/equatable.dart';

enum AchievementCategory {
  shopping,
  social,
  explorer,
  loyalty,
  special,
}

enum BadgeRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

class AchievementEntity extends Equatable {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final AchievementCategory category;
  final BadgeRarity rarity;
  final int pointsReward;
  final Map<String, dynamic> condition;
  final bool isSecret;
  final int? totalUnlocked;

  const AchievementEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.category,
    this.rarity = BadgeRarity.common,
    this.pointsReward = 0,
    required this.condition,
    this.isSecret = false,
    this.totalUnlocked,
  });

  @override
  List<Object?> get props => [id, title, category, rarity];
}

class UserAchievementEntity extends Equatable {
  final String id;
  final String userId;
  final String achievementId;
  final AchievementEntity achievement;
  final DateTime unlockedAt;
  final bool isNew;

  const UserAchievementEntity({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.achievement,
    required this.unlockedAt,
    this.isNew = true,
  });

  @override
  List<Object?> get props => [id, userId, achievementId, unlockedAt];
}

class RewardEntity extends Equatable {
  final String id;
  final String commerceId;
  final String title;
  final String description;
  final String? imageUrl;
  final int pointsCost;
  final int? availableQuantity;
  final int redeemedCount;
  final DateTime? expiresAt;
  final bool isActive;
  final Map<String, dynamic> metadata;

  const RewardEntity({
    required this.id,
    required this.commerceId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.pointsCost,
    this.availableQuantity,
    this.redeemedCount = 0,
    this.expiresAt,
    this.isActive = true,
    this.metadata = const {},
  });

  bool get isAvailable =>
      isActive &&
      (availableQuantity == null || redeemedCount < availableQuantity!) &&
      (expiresAt == null || DateTime.now().isBefore(expiresAt!));

  @override
  List<Object?> get props => [id, commerceId, title, pointsCost];
}
