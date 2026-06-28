part of 'points_bloc.dart';

abstract class PointsState extends Equatable {
  const PointsState();
  @override
  List<Object?> get props => [];
}

class PointsInitial extends PointsState {}

class PointsLoading extends PointsState {}

class PointsHistoryLoading extends PointsState {}

class LeaderboardLoading extends PointsState {}

class RewardRedeeming extends PointsState {}

class PointsDashboardLoaded extends PointsState {
  final int points;
  final UserLevel level;
  final List<UserAchievementEntity> userAchievements;

  const PointsDashboardLoaded({
    required this.points,
    required this.level,
    required this.userAchievements,
  });

  @override
  List<Object?> get props => [points, level, userAchievements];
}

class PointsHistoryLoaded extends PointsState {
  final List<Map<String, dynamic>> history;
  const PointsHistoryLoaded(this.history);
  @override
  List<Object?> get props => [history];
}

class AchievementsLoaded extends PointsState {
  final List<AchievementEntity> all;
  final List<UserAchievementEntity> unlocked;
  const AchievementsLoaded({required this.all, required this.unlocked});
  @override
  List<Object?> get props => [all, unlocked];
}

class AchievementUnlocked extends PointsState {
  final UserAchievementEntity achievement;
  const AchievementUnlocked(this.achievement);
  @override
  List<Object?> get props => [achievement];
}

class LeaderboardLoaded extends PointsState {
  final List<Map<String, dynamic>> entries;
  final String currentUserId;
  const LeaderboardLoaded(this.entries, {required this.currentUserId});
  @override
  List<Object?> get props => [entries, currentUserId];
}

class RewardRedeemed extends PointsState {
  final String rewardId;
  const RewardRedeemed(this.rewardId);
  @override
  List<Object?> get props => [rewardId];
}

class RewardsListLoaded extends PointsState {
  final List<RewardEntity> rewards;
  const RewardsListLoaded(this.rewards);
  @override
  List<Object?> get props => [rewards];
}

class PointsError extends PointsState {
  final String message;
  const PointsError(this.message);
  @override
  List<Object?> get props => [message];
}
