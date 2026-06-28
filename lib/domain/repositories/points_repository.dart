import 'package:dartz/dartz.dart';
import '../entities/achievement_entity.dart';
import '../entities/user_entity.dart';
import '../../core/errors/failures.dart';

abstract class PointsRepository {
  Future<Either<Failure, int>> getUserPoints(String userId);

  Future<Either<Failure, void>> addPoints({
    required String userId,
    required int points,
    required String reason,
    String? commerceId,
    String? promotionId,
    String? couponId,
  });

  Future<Either<Failure, void>> deductPoints({
    required String userId,
    required int points,
    required String reason,
    String? rewardId,
  });

  Future<Either<Failure, List<Map<String, dynamic>>>> getPointsHistory({
    required String userId,
    int limit = 20,
    String? lastTransactionId,
  });

  Future<Either<Failure, UserLevel>> checkAndUpdateUserLevel(String userId);

  Future<Either<Failure, List<AchievementEntity>>> getAvailableAchievements();

  Future<Either<Failure, List<UserAchievementEntity>>> getUserAchievements(String userId);

  Future<Either<Failure, UserAchievementEntity?>> checkAndUnlockAchievement({
    required String userId,
    required String achievementId,
  });

  Future<Either<Failure, List<RewardEntity>>> getCommerceRewards({
    required String commerceId,
    bool onlyActive = true,
  });

  Future<Either<Failure, List<RewardEntity>>> getAllActiveRewards({
    int limit = 50,
  });

  Future<Either<Failure, RewardEntity>> createReward(RewardEntity reward);

  Future<Either<Failure, void>> redeemReward({
    required String userId,
    required String rewardId,
    required String commerceId,
  });

  Future<Either<Failure, List<Map<String, dynamic>>>> getLeaderboard({
    String? city,
    int limit = 50,
  });
}
