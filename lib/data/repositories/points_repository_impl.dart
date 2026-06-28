import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/achievement_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/points_repository.dart';
import '../datasources/firebase/firebase_points_datasource.dart';

class PointsRepositoryImpl implements PointsRepository {
  final FirebasePointsDatasource _datasource;

  PointsRepositoryImpl({required FirebasePointsDatasource datasource})
      : _datasource = datasource;

  @override
  Future<Either<Failure, int>> getUserPoints(String userId) async {
    try {
      final points = await _datasource.getUserPoints(userId);
      return Right(points);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addPoints({
    required String userId,
    required int points,
    required String reason,
    String? commerceId,
    String? promotionId,
    String? couponId,
  }) async {
    try {
      await _datasource.addPoints(
        userId: userId,
        points: points,
        reason: reason,
        commerceId: commerceId,
        promotionId: promotionId,
        couponId: couponId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deductPoints({
    required String userId,
    required int points,
    required String reason,
    String? rewardId,
  }) async {
    try {
      await _datasource.deductPoints(
        userId: userId,
        points: points,
        reason: reason,
        rewardId: rewardId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ValidationFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPointsHistory({
    required String userId,
    int limit = 20,
    String? lastTransactionId,
  }) async {
    try {
      final history = await _datasource.getPointsHistory(
        userId: userId,
        limit: limit,
      );
      return Right(history);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserLevel>> checkAndUpdateUserLevel(String userId) async {
    try {
      final points = await _datasource.getUserPoints(userId);
      UserLevel level;
      if (points >= 15000) level = UserLevel.lifetime;
      else if (points >= 5000) level = UserLevel.ambassador;
      else if (points >= 2000) level = UserLevel.exemplary;
      else if (points >= 500) level = UserLevel.frequent;
      else level = UserLevel.explorer;
      return Right(level);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AchievementEntity>>> getAvailableAchievements() async {
    try {
      final data = await _datasource.getAchievementDefinitions();
      final achievements = data.map(_mapToAchievement).toList();
      return Right(achievements);
    } catch (e) {
      return Right(_getDefaultAchievements());
    }
  }

  @override
  Future<Either<Failure, List<UserAchievementEntity>>> getUserAchievements(
      String userId) async {
    try {
      final ids = await _datasource.getUserAchievementIds(userId);
      final defaults = _getDefaultAchievements();
      final userAchievements = ids
          .map((id) {
            final achievement = defaults.firstWhere(
              (a) => a.id == id,
              orElse: () => AchievementEntity(
                id: id,
                title: id,
                description: '',
                iconUrl: '',
                category: AchievementCategory.special,
                condition: {},
              ),
            );
            return UserAchievementEntity(
              id: '$userId-$id',
              userId: userId,
              achievementId: id,
              achievement: achievement,
              unlockedAt: DateTime.now(),
              isNew: false,
            );
          })
          .toList();
      return Right(userAchievements);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserAchievementEntity?>> checkAndUnlockAchievement({
    required String userId,
    required String achievementId,
  }) async {
    try {
      final ids = await _datasource.getUserAchievementIds(userId);
      if (ids.contains(achievementId)) return const Right(null);

      await _datasource.unlockAchievement(userId, achievementId);

      final achievement = _getDefaultAchievements()
          .firstWhere((a) => a.id == achievementId, orElse: () => AchievementEntity(
                id: achievementId,
                title: achievementId,
                description: '',
                iconUrl: '',
                category: AchievementCategory.special,
                condition: {},
              ));

      return Right(UserAchievementEntity(
        id: '$userId-$achievementId',
        userId: userId,
        achievementId: achievementId,
        achievement: achievement,
        unlockedAt: DateTime.now(),
        isNew: true,
      ));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RewardEntity>>> getCommerceRewards({
    required String commerceId,
    bool onlyActive = true,
  }) async {
    try {
      final data = await _datasource.getCommerceRewards(
        commerceId: commerceId,
        onlyActive: onlyActive,
      );
      final rewards = data.map(_mapToReward).toList();
      return Right(rewards);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<RewardEntity>>> getAllActiveRewards({
    int limit = 50,
  }) async {
    try {
      final data = await _datasource.getAllActiveRewards(limit: limit);
      return Right(data.map(_mapToReward).toList());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, RewardEntity>> createReward(RewardEntity reward) async {
    try {
      final data = {
        'commerceId': reward.commerceId,
        'title': reward.title,
        'description': reward.description,
        'imageUrl': reward.imageUrl,
        'pointsCost': reward.pointsCost,
        'availableQuantity': reward.availableQuantity,
        'isActive': reward.isActive,
        'metadata': reward.metadata,
      };
      final id = await _datasource.createReward(data);
      return Right(RewardEntity(
        id: id,
        commerceId: reward.commerceId,
        title: reward.title,
        description: reward.description,
        imageUrl: reward.imageUrl,
        pointsCost: reward.pointsCost,
        availableQuantity: reward.availableQuantity,
        isActive: reward.isActive,
        metadata: reward.metadata,
      ));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> redeemReward({
    required String userId,
    required String rewardId,
    required String commerceId,
  }) async {
    try {
      await _datasource.redeemReward(
        userId: userId,
        rewardId: rewardId,
        commerceId: commerceId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ValidationFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getLeaderboard({
    String? city,
    int limit = 50,
  }) async {
    try {
      final data = await _datasource.getLeaderboard(city: city, limit: limit);
      return Right(data);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  AchievementEntity _mapToAchievement(Map<String, dynamic> data) {
    return AchievementEntity(
      id: data['id'] as String,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      iconUrl: data['iconUrl'] as String? ?? '',
      category: AchievementCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => AchievementCategory.special,
      ),
      rarity: BadgeRarity.values.firstWhere(
        (r) => r.name == data['rarity'],
        orElse: () => BadgeRarity.common,
      ),
      pointsReward: data['pointsReward'] as int? ?? 0,
      condition: data['condition'] as Map<String, dynamic>? ?? {},
      isSecret: data['isSecret'] as bool? ?? false,
    );
  }

  RewardEntity _mapToReward(Map<String, dynamic> data) {
    return RewardEntity(
      id: data['id'] as String,
      commerceId: data['commerceId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      imageUrl: data['imageUrl'] as String?,
      pointsCost: data['pointsCost'] as int,
      availableQuantity: data['availableQuantity'] as int?,
      redeemedCount: data['redeemedCount'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  List<AchievementEntity> _getDefaultAchievements() {
    return [
      const AchievementEntity(
        id: 'first_coupon',
        title: 'Primer Cupón',
        description: 'Usaste tu primer cupón en ShinraCity',
        iconUrl: 'assets/icons/achievement_first.png',
        category: AchievementCategory.shopping,
        rarity: BadgeRarity.common,
        pointsReward: 50,
        condition: {'type': 'coupons_redeemed', 'value': 1},
      ),
      const AchievementEntity(
        id: 'ten_coupons',
        title: 'Cliente Activo',
        description: 'Canjeaste 10 cupones',
        iconUrl: 'assets/icons/achievement_10.png',
        category: AchievementCategory.shopping,
        rarity: BadgeRarity.uncommon,
        pointsReward: 100,
        condition: {'type': 'coupons_redeemed', 'value': 10},
      ),
      const AchievementEntity(
        id: 'fifty_coupons',
        title: 'Experto Cazaofertas',
        description: 'Canjeaste 50 cupones',
        iconUrl: 'assets/icons/achievement_50.png',
        category: AchievementCategory.shopping,
        rarity: BadgeRarity.rare,
        pointsReward: 250,
        condition: {'type': 'coupons_redeemed', 'value': 50},
      ),
      const AchievementEntity(
        id: 'hundred_coupons',
        title: 'Leyenda del Ahorro',
        description: 'Canjeaste 100 cupones',
        iconUrl: 'assets/icons/achievement_100.png',
        category: AchievementCategory.shopping,
        rarity: BadgeRarity.legendary,
        pointsReward: 500,
        condition: {'type': 'coupons_redeemed', 'value': 100},
      ),
      const AchievementEntity(
        id: 'first_review',
        title: 'Crítico',
        description: 'Escribiste tu primera reseña',
        iconUrl: 'assets/icons/achievement_review.png',
        category: AchievementCategory.social,
        rarity: BadgeRarity.common,
        pointsReward: 30,
        condition: {'type': 'reviews_written', 'value': 1},
      ),
      const AchievementEntity(
        id: 'explorer',
        title: 'Explorador',
        description: 'Visitaste 10 comercios diferentes',
        iconUrl: 'assets/icons/achievement_explorer.png',
        category: AchievementCategory.explorer,
        rarity: BadgeRarity.uncommon,
        pointsReward: 100,
        condition: {'type': 'commerces_visited', 'value': 10},
      ),
      const AchievementEntity(
        id: 'referral_pro',
        title: 'Embajador',
        description: 'Referiste a 5 amigos',
        iconUrl: 'assets/icons/achievement_referral.png',
        category: AchievementCategory.social,
        rarity: BadgeRarity.epic,
        pointsReward: 500,
        condition: {'type': 'referrals', 'value': 5},
      ),
    ];
  }
}
