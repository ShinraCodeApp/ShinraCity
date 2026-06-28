import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/achievement_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/points_repository.dart';
import '../../../services/analytics_service.dart';

part 'points_event.dart';
part 'points_state.dart';

class PointsBloc extends Bloc<PointsEvent, PointsState> {
  final PointsRepository _repository;
  final AnalyticsService? _analytics;
  final String userId;

  PointsBloc({
    required PointsRepository repository,
    required this.userId,
    AnalyticsService? analytics,
  })  : _repository = repository,
        _analytics = analytics,
        super(PointsInitial()) {
    on<LoadUserPoints>(_onLoadUserPoints);
    on<LoadPointsHistory>(_onLoadPointsHistory);
    on<LoadAchievements>(_onLoadAchievements);
    on<LoadLeaderboard>(_onLoadLeaderboard);
    on<RedeemReward>(_onRedeemReward);
    on<LoadAvailableRewards>(_onLoadAvailableRewards);
    on<CheckAchievement>(_onCheckAchievement);
  }

  Future<void> _onLoadUserPoints(
    LoadUserPoints event,
    Emitter<PointsState> emit,
  ) async {
    emit(PointsLoading());
    final pointsResult = await _repository.getUserPoints(userId);
    final levelResult = await _repository.checkAndUpdateUserLevel(userId);
    final achievementsResult = await _repository.getUserAchievements(userId);

    pointsResult.fold(
      (f) => emit(PointsError(f.message)),
      (points) {
        final level = levelResult.getOrElse(() => UserLevel.explorer);
        final userAchievements = achievementsResult.getOrElse(() => []);
        _analytics?.setUserLevel(level.name);
        emit(PointsDashboardLoaded(
          points: points,
          level: level,
          userAchievements: userAchievements,
        ));
      },
    );
  }

  Future<void> _onLoadPointsHistory(
    LoadPointsHistory event,
    Emitter<PointsState> emit,
  ) async {
    emit(PointsHistoryLoading());
    final result = await _repository.getPointsHistory(
      userId: userId,
      limit: event.limit,
    );
    result.fold(
      (f) => emit(PointsError(f.message)),
      (history) => emit(PointsHistoryLoaded(history)),
    );
  }

  Future<void> _onLoadAchievements(
    LoadAchievements event,
    Emitter<PointsState> emit,
  ) async {
    final allResult = await _repository.getAvailableAchievements();
    final userResult = await _repository.getUserAchievements(userId);

    allResult.fold(
      (f) => emit(PointsError(f.message)),
      (all) {
        final userAchievements = userResult.getOrElse(() => []);
        emit(AchievementsLoaded(
          all: all,
          unlocked: userAchievements,
        ));
      },
    );
  }

  Future<void> _onLoadLeaderboard(
    LoadLeaderboard event,
    Emitter<PointsState> emit,
  ) async {
    emit(LeaderboardLoading());
    final result = await _repository.getLeaderboard(
      city: event.city,
      limit: event.limit,
    );
    result.fold(
      (f) => emit(PointsError(f.message)),
      (entries) => emit(LeaderboardLoaded(entries, currentUserId: userId)),
    );
  }

  Future<void> _onRedeemReward(
    RedeemReward event,
    Emitter<PointsState> emit,
  ) async {
    emit(RewardRedeeming());
    final result = await _repository.redeemReward(
      userId: userId,
      rewardId: event.rewardId,
      commerceId: event.commerceId,
    );
    result.fold(
      (f) => emit(PointsError(f.message)),
      (_) {
        _analytics?.logRewardRedeemed(rewardId: event.rewardId, pointsCost: 0);
        emit(RewardRedeemed(event.rewardId));
      },
    );
  }

  Future<void> _onLoadAvailableRewards(
    LoadAvailableRewards event,
    Emitter<PointsState> emit,
  ) async {
    final result = await _repository.getAllActiveRewards();
    result.fold(
      (f) => emit(PointsError(f.message)),
      (rewards) => emit(RewardsListLoaded(rewards)),
    );
  }

  Future<void> _onCheckAchievement(
    CheckAchievement event,
    Emitter<PointsState> emit,
  ) async {
    final result = await _repository.checkAndUnlockAchievement(
      userId: userId,
      achievementId: event.achievementId,
    );
    result.fold(
      (_) => null,
      (userAchievement) {
        if (userAchievement != null) {
          _analytics?.logAchievementUnlocked(
            achievementId: userAchievement.achievementId,
          );
          emit(AchievementUnlocked(userAchievement));
        }
      },
    );
  }
}
