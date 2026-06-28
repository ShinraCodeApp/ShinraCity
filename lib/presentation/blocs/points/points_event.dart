part of 'points_bloc.dart';

abstract class PointsEvent extends Equatable {
  const PointsEvent();
  @override
  List<Object?> get props => [];
}

class LoadUserPoints extends PointsEvent {
  const LoadUserPoints();
}

class LoadPointsHistory extends PointsEvent {
  final int limit;
  const LoadPointsHistory({this.limit = 20});
  @override
  List<Object?> get props => [limit];
}

class LoadAchievements extends PointsEvent {
  const LoadAchievements();
}

class LoadLeaderboard extends PointsEvent {
  final String? city;
  final int limit;
  const LoadLeaderboard({this.city, this.limit = 50});
  @override
  List<Object?> get props => [city, limit];
}

class RedeemReward extends PointsEvent {
  final String rewardId;
  final String commerceId;
  const RedeemReward({required this.rewardId, required this.commerceId});
  @override
  List<Object?> get props => [rewardId, commerceId];
}

class LoadAvailableRewards extends PointsEvent {
  const LoadAvailableRewards();
}

class CheckAchievement extends PointsEvent {
  final String achievementId;
  const CheckAchievement(this.achievementId);
  @override
  List<Object?> get props => [achievementId];
}
