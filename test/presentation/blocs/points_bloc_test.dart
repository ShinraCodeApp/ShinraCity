import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/achievement_entity.dart';
import 'package:shinra_city/domain/entities/user_entity.dart';
import 'package:shinra_city/domain/repositories/points_repository.dart';
import 'package:shinra_city/presentation/blocs/points/points_bloc.dart';

class MockPointsRepository extends Mock implements PointsRepository {
  @override
  Future<Either<Failure, int>> getUserPoints(String? userId) =>
      super.noSuchMethod(
        Invocation.method(#getUserPoints, [userId]),
        returnValue: Future.value(const Right(0)),
      );

  @override
  Future<Either<Failure, UserLevel>> checkAndUpdateUserLevel(String? userId) =>
      super.noSuchMethod(
        Invocation.method(#checkAndUpdateUserLevel, [userId]),
        returnValue: Future.value(const Right(UserLevel.explorer)),
      );

  @override
  Future<Either<Failure, List<UserAchievementEntity>>> getUserAchievements(String? userId) =>
      super.noSuchMethod(
        Invocation.method(#getUserAchievements, [userId]),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, List<AchievementEntity>>> getAvailableAchievements() =>
      super.noSuchMethod(
        Invocation.method(#getAvailableAchievements, []),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getLeaderboard({
    String? city,
    int limit = 50,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getLeaderboard, [], {#city: city, #limit: limit}),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, void>> redeemReward({
    required String? userId,
    required String? rewardId,
    required String? commerceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#redeemReward, [], {
          #userId: userId,
          #rewardId: rewardId,
          #commerceId: commerceId,
        }),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPointsHistory({
    required String? userId,
    int limit = 20,
    String? lastTransactionId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getPointsHistory, [], {
          #userId: userId,
          #limit: limit,
          #lastTransactionId: lastTransactionId,
        }),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, UserAchievementEntity?>> checkAndUnlockAchievement({
    required String? userId,
    required String? achievementId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#checkAndUnlockAchievement, [], {
          #userId: userId,
          #achievementId: achievementId,
        }),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, List<RewardEntity>>> getCommerceRewards({
    required String? commerceId,
    bool onlyActive = true,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getCommerceRewards, [], {
          #commerceId: commerceId,
          #onlyActive: onlyActive,
        }),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, List<RewardEntity>>> getAllActiveRewards({
    int limit = 50,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getAllActiveRewards, [], {#limit: limit}),
        returnValue: Future.value(const Right(<RewardEntity>[])),
      );

  @override
  Future<Either<Failure, RewardEntity>> createReward(RewardEntity? reward) =>
      super.noSuchMethod(
        Invocation.method(#createReward, [reward]),
        returnValue: Future.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, void>> addPoints({
    required String? userId,
    required int? points,
    required String? reason,
    String? commerceId,
    String? promotionId,
    String? couponId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#addPoints, [], {
          #userId: userId,
          #points: points,
          #reason: reason,
          #commerceId: commerceId,
          #promotionId: promotionId,
          #couponId: couponId,
        }),
        returnValue: Future.value(const Right(null)),
      );

  @override
  Future<Either<Failure, void>> deductPoints({
    required String? userId,
    required int? points,
    required String? reason,
    String? rewardId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#deductPoints, [], {
          #userId: userId,
          #points: points,
          #reason: reason,
          #rewardId: rewardId,
        }),
        returnValue: Future.value(const Right(null)),
      );
}

AchievementEntity _fakeAchievement() => const AchievementEntity(
      id: 'a1',
      title: 'Explorador',
      description: 'Primer cupón',
      iconUrl: '',
      category: AchievementCategory.explorer,
      condition: {},
    );

UserAchievementEntity _fakeUserAchievement() => UserAchievementEntity(
      id: 'ua1',
      userId: 'u1',
      achievementId: 'a1',
      achievement: _fakeAchievement(),
      unlockedAt: DateTime(2025),
    );

void main() {
  late MockPointsRepository repo;

  setUp(() => repo = MockPointsRepository());

  group('LoadUserPoints', () {
    blocTest<PointsBloc, PointsState>(
      'emite PointsDashboardLoaded con puntos y nivel',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(const LoadUserPoints()),
      setUp: () {
        when(repo.getUserPoints('u1')).thenAnswer((_) async => const Right(250));
        when(repo.checkAndUpdateUserLevel('u1'))
            .thenAnswer((_) async => const Right(UserLevel.frequent));
        when(repo.getUserAchievements('u1'))
            .thenAnswer((_) async => Right([_fakeUserAchievement()]));
      },
      expect: () => [
        PointsLoading(),
        isA<PointsDashboardLoaded>()
            .having((s) => s.points, 'points', 250)
            .having((s) => s.level, 'level', UserLevel.frequent)
            .having((s) => s.userAchievements.length, 'achievements', 1),
      ],
    );

    blocTest<PointsBloc, PointsState>(
      'emite PointsError si getUserPoints falla',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(const LoadUserPoints()),
      setUp: () {
        when(repo.getUserPoints('u1')).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Sin conexión')),
        );
        when(repo.checkAndUpdateUserLevel('u1'))
            .thenAnswer((_) async => const Right(UserLevel.explorer));
        when(repo.getUserAchievements('u1'))
            .thenAnswer((_) async => const Right([]));
      },
      expect: () => [
        PointsLoading(),
        isA<PointsError>().having((s) => s.message, 'message', 'Sin conexión'),
      ],
    );
  });

  group('LoadLeaderboard', () {
    blocTest<PointsBloc, PointsState>(
      'emite LeaderboardLoaded con las entradas correctas',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(const LoadLeaderboard()),
      setUp: () {
        when(repo.getLeaderboard()).thenAnswer(
          (_) async => Right([
            {'userId': 'u1', 'displayName': 'Ana', 'totalPoints': 500},
            {'userId': 'u2', 'displayName': 'Bob', 'totalPoints': 300},
          ]),
        );
      },
      expect: () => [
        LeaderboardLoading(),
        isA<LeaderboardLoaded>()
            .having((s) => s.entries.length, 'count', 2)
            .having((s) => s.currentUserId, 'userId', 'u1'),
      ],
    );
  });

  group('LoadAchievements', () {
    blocTest<PointsBloc, PointsState>(
      'emite AchievementsLoaded con logros disponibles y desbloqueados',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(const LoadAchievements()),
      setUp: () {
        when(repo.getAvailableAchievements())
            .thenAnswer((_) async => Right([_fakeAchievement()]));
        when(repo.getUserAchievements('u1'))
            .thenAnswer((_) async => Right([_fakeUserAchievement()]));
      },
      expect: () => [
        isA<AchievementsLoaded>()
            .having((s) => s.all.length, 'all', 1)
            .having((s) => s.unlocked.length, 'unlocked', 1),
      ],
    );
  });

  group('RedeemReward', () {
    blocTest<PointsBloc, PointsState>(
      'emite RewardRedeemed en caso exitoso',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(const RedeemReward(rewardId: 'r1', commerceId: 'c1')),
      setUp: () {
        when(repo.redeemReward(userId: 'u1', rewardId: 'r1', commerceId: 'c1'))
            .thenAnswer((_) async => const Right(null));
      },
      expect: () => [
        RewardRedeeming(),
        isA<RewardRedeemed>().having((s) => s.rewardId, 'rewardId', 'r1'),
      ],
    );

    blocTest<PointsBloc, PointsState>(
      'emite PointsError si no hay puntos suficientes',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(const RedeemReward(rewardId: 'r1', commerceId: 'c1')),
      setUp: () {
        when(repo.redeemReward(userId: 'u1', rewardId: 'r1', commerceId: 'c1'))
            .thenAnswer(
          (_) async => const Left(ValidationFailure(message: 'Puntos insuficientes')),
        );
      },
      expect: () => [
        RewardRedeeming(),
        isA<PointsError>()
            .having((s) => s.message, 'message', 'Puntos insuficientes'),
      ],
    );
  });

  group('LoadAvailableRewards', () {
    blocTest<PointsBloc, PointsState>(
      'emite RewardsListLoaded con recompensas activas',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      setUp: () {
        when(repo.getAllActiveRewards()).thenAnswer(
          (_) async => Right([
            RewardEntity(
              id: 'r1',
              commerceId: 'c1',
              title: 'Café gratis',
              description: 'Un café de cortesía',
              pointsCost: 150,
            ),
          ]),
        );
      },
      act: (bloc) => bloc.add(const LoadAvailableRewards()),
      expect: () => [
        isA<RewardsListLoaded>()
            .having((s) => s.rewards.length, 'count', 1)
            .having((s) => s.rewards.first.id, 'id', 'r1'),
      ],
    );

    blocTest<PointsBloc, PointsState>(
      'emite PointsError si el repositorio falla',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      setUp: () {
        when(repo.getAllActiveRewards()).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Sin conexión')),
        );
      },
      act: (bloc) => bloc.add(const LoadAvailableRewards()),
      expect: () => [
        isA<PointsError>().having((s) => s.message, 'message', 'Sin conexión'),
      ],
    );
  });

  group('CheckAchievement', () {
    blocTest<PointsBloc, PointsState>(
      'emite AchievementUnlocked si el logro se desbloquea',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      setUp: () {
        when(repo.checkAndUnlockAchievement(
          userId: 'u1',
          achievementId: 'a1',
        )).thenAnswer((_) async => Right(_fakeUserAchievement()));
      },
      act: (bloc) => bloc.add(const CheckAchievement('a1')),
      expect: () => [
        isA<AchievementUnlocked>()
            .having((s) => s.achievement.achievementId, 'id', 'a1'),
      ],
    );

    blocTest<PointsBloc, PointsState>(
      'no emite estado si el logro ya estaba desbloqueado (null)',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      setUp: () {
        when(repo.checkAndUnlockAchievement(
          userId: 'u1',
          achievementId: 'a1',
        )).thenAnswer((_) async => const Right(null));
      },
      act: (bloc) => bloc.add(const CheckAchievement('a1')),
      expect: () => [],
    );
  });

  group('LoadPointsHistory', () {
    blocTest<PointsBloc, PointsState>(
      'emite PointsHistoryLoaded con historial',
      build: () => PointsBloc(repository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(const LoadPointsHistory()),
      setUp: () {
        when(repo.getPointsHistory(userId: 'u1')).thenAnswer(
          (_) async => Right([
            {'points': 50, 'reason': 'Cupón canjeado', 'createdAt': '2025-01-01'},
          ]),
        );
      },
      expect: () => [
        PointsHistoryLoading(),
        isA<PointsHistoryLoaded>()
            .having((s) => s.history.length, 'count', 1),
      ],
    );
  });
}
