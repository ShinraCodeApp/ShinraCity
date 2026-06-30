import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mockito/mockito.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/promotion_entity.dart';
import 'package:shinra_city/domain/repositories/promotion_repository.dart';
import 'package:shinra_city/presentation/blocs/promotions/promotions_bloc.dart';

class MockPromotionRepository extends Mock implements PromotionRepository {
  @override
  Future<Either<Failure, List<PromotionEntity>>> getCommercePromotions({
    required String? commerceId,
    PromotionStatus? status,
    int limit = 20,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getCommercePromotions, [], {
          #commerceId: commerceId,
          #status: status,
          #limit: limit,
        }),
        returnValue: Future<Either<Failure, List<PromotionEntity>>>.value(const Right([])),
      );

  @override
  Future<Either<Failure, PromotionEntity>> createPromotion(PromotionEntity? promotion) =>
      super.noSuchMethod(
        Invocation.method(#createPromotion, [promotion]),
        returnValue: Future<Either<Failure, PromotionEntity>>.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, PromotionEntity>> updatePromotion(PromotionEntity? promotion) =>
      super.noSuchMethod(
        Invocation.method(#updatePromotion, [promotion]),
        returnValue: Future<Either<Failure, PromotionEntity>>.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, void>> changePromotionStatus({
    required String? promotionId,
    required PromotionStatus? status,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #changePromotionStatus,
          [],
          {#promotionId: promotionId, #status: status},
        ),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
      );

  @override
  Future<Either<Failure, void>> deletePromotion(String? id) =>
      super.noSuchMethod(
        Invocation.method(#deletePromotion, [id]),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
      );

  @override
  Future<Either<Failure, List<PromotionEntity>>> getNearbyPromotions({
    required LatLng? location,
    required double? radiusKm,
    List<String>? categories,
    bool onlyActive = true,
    int limit = 50,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getNearbyPromotions, [], {
          #location: location,
          #radiusKm: radiusKm,
          #categories: categories,
          #onlyActive: onlyActive,
          #limit: limit,
        }),
        returnValue: Future<Either<Failure, List<PromotionEntity>>>.value(const Right([])),
      );

  @override
  Future<Either<Failure, PromotionEntity>> getPromotion(String? id) =>
      super.noSuchMethod(
        Invocation.method(#getPromotion, [id]),
        returnValue: Future<Either<Failure, PromotionEntity>>.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Future<Either<Failure, List<PromotionEntity>>> getFeaturedPromotions({
    LatLng? location,
    int limit = 10,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getFeaturedPromotions, [], {
          #location: location,
          #limit: limit,
        }),
        returnValue: Future<Either<Failure, List<PromotionEntity>>>.value(const Right([])),
      );

  @override
  Future<Either<Failure, List<PromotionEntity>>> getRecommendedPromotions({
    required String? userId,
    required LatLng? location,
    int limit = 20,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getRecommendedPromotions, [], {
          #userId: userId,
          #location: location,
          #limit: limit,
        }),
        returnValue: Future<Either<Failure, List<PromotionEntity>>>.value(const Right([])),
      );

  @override
  Future<Either<Failure, String>> uploadPromotionImage({
    required String? promotionId,
    required String? filePath,
  }) =>
      super.noSuchMethod(
        Invocation.method(#uploadPromotionImage, [], {
          #promotionId: promotionId,
          #filePath: filePath,
        }),
        returnValue: Future<Either<Failure, String>>.value(const Left(ServerFailure(message: 'error'))),
      );

  @override
  Stream<List<PromotionEntity>> watchCommercePromotions(String? commerceId) =>
      super.noSuchMethod(
        Invocation.method(#watchCommercePromotions, [commerceId]),
        returnValue: const Stream<List<PromotionEntity>>.empty(),
      ) as Stream<List<PromotionEntity>>;

  @override
  Stream<List<PromotionEntity>> watchNearbyPromotions({
    required LatLng? location,
    required double? radiusKm,
  }) =>
      super.noSuchMethod(
        Invocation.method(#watchNearbyPromotions, [], {
          #location: location,
          #radiusKm: radiusKm,
        }),
        returnValue: const Stream<List<PromotionEntity>>.empty(),
      ) as Stream<List<PromotionEntity>>;

  @override
  Future<Either<Failure, void>> incrementViewCount(String? promotionId) =>
      super.noSuchMethod(
        Invocation.method(#incrementViewCount, [promotionId]),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
      );
}

PromotionEntity _fakePromotion() => PromotionEntity(
      id: 'p1',
      commerceId: 'c1',
      commerceName: 'Café Centro',
      title: 'Promo 2x1',
      description: '2 por 1 en cafés',
      type: PromotionType.daily,
      status: PromotionStatus.active,
      discountType: DiscountType.twoForOne,
      discountValue: 50,
      startDate: DateTime(2025),
      endDate: DateTime(2025, 12, 31),
      originalPrice: 0,
      createdAt: DateTime(2025),
    );

void main() {
  late MockPromotionRepository repo;

  setUp(() => repo = MockPromotionRepository());

  group('LoadCommercePromotions', () {
    blocTest<PromotionsBloc, PromotionsState>(
      'emite PromotionsLoaded con la lista correcta',
      build: () => PromotionsBloc(repository: repo),
      act: (bloc) => bloc.add(const LoadCommercePromotions(commerceId: 'c1')),
      setUp: () {
        when(repo.getCommercePromotions(commerceId: 'c1'))
            .thenAnswer((_) async => Right([_fakePromotion()]));
      },
      expect: () => [
        PromotionsLoading(),
        isA<PromotionsLoaded>()
            .having((s) => s.promotions.length, 'length', 1),
      ],
    );

    blocTest<PromotionsBloc, PromotionsState>(
      'emite PromotionsError cuando falla la carga',
      build: () => PromotionsBloc(repository: repo),
      act: (bloc) => bloc.add(const LoadCommercePromotions(commerceId: 'c1')),
      setUp: () {
        when(repo.getCommercePromotions(commerceId: 'c1')).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Sin conexión')),
        );
      },
      expect: () => [
        PromotionsLoading(),
        isA<PromotionsError>().having((s) => s.message, 'message', 'Sin conexión'),
      ],
    );
  });

  group('CreatePromotion', () {
    blocTest<PromotionsBloc, PromotionsState>(
      'emite PromotionCreated en caso exitoso',
      build: () => PromotionsBloc(repository: repo),
      act: (bloc) => bloc.add(CreatePromotion(_fakePromotion())),
      setUp: () {
        when(repo.createPromotion(any))
            .thenAnswer((_) async => Right(_fakePromotion()));
      },
      expect: () => [
        PromotionOperationLoading(),
        isA<PromotionCreated>().having((s) => s.promotion.id, 'id', 'p1'),
      ],
    );

    blocTest<PromotionsBloc, PromotionsState>(
      'emite PromotionsError si la creación falla',
      build: () => PromotionsBloc(repository: repo),
      act: (bloc) => bloc.add(CreatePromotion(_fakePromotion())),
      setUp: () {
        when(repo.createPromotion(any)).thenAnswer(
          (_) async => const Left(PlanLimitFailure()),
        );
      },
      expect: () => [
        PromotionOperationLoading(),
        isA<PromotionsError>(),
      ],
    );
  });

  group('ChangePromotionStatus', () {
    blocTest<PromotionsBloc, PromotionsState>(
      'emite PromotionStatusChanged cuando el cambio es exitoso',
      build: () => PromotionsBloc(repository: repo),
      act: (bloc) => bloc.add(const ChangePromotionStatus(
        promotionId: 'p1',
        status: PromotionStatus.paused,
      )),
      setUp: () {
        when(repo.changePromotionStatus(
          promotionId: 'p1',
          status: PromotionStatus.paused,
        )).thenAnswer((_) async => const Right(null));
      },
      expect: () => [
        isA<PromotionStatusChanged>()
            .having((s) => s.promotionId, 'id', 'p1')
            .having((s) => s.status, 'status', PromotionStatus.paused),
      ],
    );
  });

  group('DeletePromotion', () {
    blocTest<PromotionsBloc, PromotionsState>(
      'emite PromotionDeleted cuando se elimina correctamente',
      build: () => PromotionsBloc(repository: repo),
      act: (bloc) => bloc.add(const DeletePromotion('p1')),
      setUp: () {
        when(repo.deletePromotion('p1'))
            .thenAnswer((_) async => const Right(null));
      },
      expect: () => [
        isA<PromotionDeleted>().having((s) => s.promotionId, 'id', 'p1'),
      ],
    );
  });

  group('LoadNearbyPromotions', () {
    const loc = LatLng(-31.4, -64.18);

    blocTest<PromotionsBloc, PromotionsState>(
      'emite [PromotionsLoading, PromotionsLoaded] con promos cercanas',
      build: () => PromotionsBloc(repository: repo),
      setUp: () {
        when(repo.getNearbyPromotions(location: loc, radiusKm: 5.0))
            .thenAnswer((_) async => Right([_fakePromotion()]));
      },
      act: (bloc) =>
          bloc.add(LoadNearbyPromotions(location: loc, radiusKm: 5.0)),
      expect: () => [
        PromotionsLoading(),
        isA<PromotionsLoaded>()
            .having((s) => s.promotions.length, 'count', 1),
      ],
    );

    blocTest<PromotionsBloc, PromotionsState>(
      'emite [PromotionsLoading, PromotionsError] si el repositorio falla',
      build: () => PromotionsBloc(repository: repo),
      setUp: () {
        when(repo.getNearbyPromotions(location: loc, radiusKm: 5.0))
            .thenAnswer(
              (_) async => const Left(ServerFailure(message: 'Sin red')),
            );
      },
      act: (bloc) =>
          bloc.add(LoadNearbyPromotions(location: loc, radiusKm: 5.0)),
      expect: () => [
        PromotionsLoading(),
        isA<PromotionsError>().having((s) => s.message, 'msg', 'Sin red'),
      ],
    );
  });

  group('UpdatePromotion', () {
    blocTest<PromotionsBloc, PromotionsState>(
      'emite [PromotionOperationLoading, PromotionUpdated] en éxito',
      build: () => PromotionsBloc(repository: repo),
      setUp: () {
        when(repo.updatePromotion(any))
            .thenAnswer((_) async => Right(_fakePromotion()));
      },
      act: (bloc) => bloc.add(UpdatePromotion(_fakePromotion())),
      expect: () => [
        PromotionOperationLoading(),
        isA<PromotionUpdated>()
            .having((s) => s.promotion.id, 'id', 'p1'),
      ],
    );

    blocTest<PromotionsBloc, PromotionsState>(
      'emite [PromotionOperationLoading, PromotionsError] si falla',
      build: () => PromotionsBloc(repository: repo),
      setUp: () {
        when(repo.updatePromotion(any)).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Error update')),
        );
      },
      act: (bloc) => bloc.add(UpdatePromotion(_fakePromotion())),
      expect: () => [
        PromotionOperationLoading(),
        isA<PromotionsError>(),
      ],
    );
  });

  group('WatchCommercePromotions', () {
    blocTest<PromotionsBloc, PromotionsState>(
      'emite PromotionsLoaded por cada evento del stream',
      build: () => PromotionsBloc(repository: repo),
      setUp: () {
        when(repo.watchCommercePromotions('c1')).thenAnswer(
          (_) => Stream.fromIterable([
            [_fakePromotion()],
            [_fakePromotion(), _fakePromotion()],
          ]),
        );
      },
      act: (bloc) => bloc.add(const WatchCommercePromotions('c1')),
      expect: () => [
        isA<PromotionsLoaded>().having((s) => s.promotions.length, 'first', 1),
        isA<PromotionsLoaded>().having((s) => s.promotions.length, 'second', 2),
      ],
    );

    blocTest<PromotionsBloc, PromotionsState>(
      'emite PromotionsError cuando el stream emite error',
      build: () => PromotionsBloc(repository: repo),
      setUp: () {
        when(repo.watchCommercePromotions('c1')).thenAnswer(
          (_) => Stream.error(Exception('Firestore error')),
        );
      },
      act: (bloc) => bloc.add(const WatchCommercePromotions('c1')),
      expect: () => [
        isA<PromotionsError>(),
      ],
    );
  });
}
