import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mockito/mockito.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/commerce_entity.dart';
import 'package:shinra_city/domain/entities/promotion_entity.dart';
import 'package:shinra_city/domain/repositories/commerce_repository.dart';
import 'package:shinra_city/domain/repositories/promotion_repository.dart';
import 'package:shinra_city/presentation/blocs/map/map_bloc.dart';

// ─── Manual mocks ──────────────────────────────────────────────────────────

class MockCommerceRepository extends Mock implements CommerceRepository {
  @override
  Future<Either<Failure, List<CommerceEntity>>> getNearbyCommerces({
    required LatLng? location,
    required double? radiusKm,
    CommerceCategory? category,
    String? searchQuery,
    bool onlyOpen = false,
    bool onlyWithPromotions = false,
    CommercePlan? minPlan,
    int limit = 50,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getNearbyCommerces, [], {
          #location: location,
          #radiusKm: radiusKm,
          #category: category,
          #searchQuery: searchQuery,
          #onlyOpen: onlyOpen,
          #onlyWithPromotions: onlyWithPromotions,
          #minPlan: minPlan,
          #limit: limit,
        }),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, List<CommerceEntity>>> searchCommerces({
    required String? query,
    CommerceCategory? category,
    LatLng? location,
    double? radiusKm,
    int limit = 20,
  }) =>
      super.noSuchMethod(
        Invocation.method(#searchCommerces, [], {
          #query: query,
          #category: category,
          #location: location,
          #radiusKm: radiusKm,
          #limit: limit,
        }),
        returnValue: Future.value(const Right([])),
      );

  @override
  Future<Either<Failure, CommerceEntity>> getCommerce(String? id) =>
      super.noSuchMethod(
        Invocation.method(#getCommerce, [id]),
        returnValue: Future.value(Left(ServerFailure(message: 'error'))),
      );
}

class MockPromotionRepository extends Mock implements PromotionRepository {
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
        returnValue: Future.value(const Right([])),
      );

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
        returnValue: Future.value(const Right([])),
      );
}

// ─── Helpers ───────────────────────────────────────────────────────────────

const _loc = LatLng(-31.4, -64.18);

CommerceEntity _fakeCommerce({String id = 'c1', CommerceCategory category = CommerceCategory.restaurants}) =>
    CommerceEntity(
      id: id,
      ownerId: 'o1',
      name: 'Comercio Test',
      description: 'Desc',
      category: category,
      location: _loc,
      geohash: 'abc123',
      address: 'Calle Falsa 123',
      city: 'Córdoba',
      createdAt: DateTime(2025),
    );

PromotionEntity _fakePromotion() => PromotionEntity(
      id: 'p1',
      commerceId: 'c1',
      commerceName: 'Comercio Test',
      title: 'Promo Test',
      description: 'Desc',
      type: PromotionType.daily,
      status: PromotionStatus.active,
      discountType: DiscountType.percentage,
      discountValue: 20,
      startDate: DateTime(2025),
      endDate: DateTime(2025, 12),
      originalPrice: 100,
      createdAt: DateTime(2025),
    );

MapBloc _buildBloc(
  MockCommerceRepository commerceRepo,
  MockPromotionRepository promotionRepo,
) =>
    MapBloc(
      commerceRepository: commerceRepo,
      promotionRepository: promotionRepo,
    );

// ─── Tests ─────────────────────────────────────────────────────────────────

void main() {
  late MockCommerceRepository commerceRepo;
  late MockPromotionRepository promotionRepo;

  setUp(() {
    commerceRepo = MockCommerceRepository();
    promotionRepo = MockPromotionRepository();
  });

  group('LoadNearbyCommerces', () {
    blocTest<MapBloc, MapState>(
      'emite MapLoaded con comercios cercanos',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      setUp: () {
        when(commerceRepo.getNearbyCommerces(
          location: _loc,
          radiusKm: 5.0,
        )).thenAnswer((_) async => Right([_fakeCommerce()]));
      },
      act: (bloc) => bloc.add(LoadNearbyCommerces(location: _loc)),
      expect: () => [
        MapLoading(),
        isA<MapLoaded>()
            .having((s) => s.commerces.length, 'commerces', 1)
            .having((s) => s.userLocation, 'location', _loc),
      ],
    );

    blocTest<MapBloc, MapState>(
      'emite MapError si el repositorio falla',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      setUp: () {
        when(commerceRepo.getNearbyCommerces(
          location: _loc,
          radiusKm: 5.0,
        )).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Sin conexión')),
        );
      },
      act: (bloc) => bloc.add(LoadNearbyCommerces(location: _loc)),
      expect: () => [
        MapLoading(),
        isA<MapError>().having((s) => s.message, 'message', 'Sin conexión'),
      ],
    );

    blocTest<MapBloc, MapState>(
      'emite MapLoaded con categoría activa al filtrar',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      setUp: () {
        when(commerceRepo.getNearbyCommerces(
          location: _loc,
          radiusKm: 5.0,
          category: CommerceCategory.restaurants,
        )).thenAnswer((_) async => Right([_fakeCommerce()]));
      },
      act: (bloc) => bloc.add(
        LoadNearbyCommerces(location: _loc, category: CommerceCategory.restaurants),
      ),
      expect: () => [
        MapLoading(),
        isA<MapLoaded>()
            .having((s) => s.activeCategory, 'category', CommerceCategory.restaurants),
      ],
    );
  });

  group('LoadNearbyPromotions', () {
    blocTest<MapBloc, MapState>(
      'actualiza promotions en MapLoaded existente',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      seed: () => MapLoaded(
        commerces: [_fakeCommerce()],
        promotions: const [],
        userLocation: _loc,
      ),
      setUp: () {
        when(promotionRepo.getNearbyPromotions(
          location: _loc,
          radiusKm: 5.0,
        )).thenAnswer((_) async => Right([_fakePromotion()]));
      },
      act: (bloc) => bloc.add(LoadNearbyPromotions(location: _loc)),
      expect: () => [
        isA<MapLoaded>()
            .having((s) => s.promotions.length, 'promotions', 1),
      ],
    );

    blocTest<MapBloc, MapState>(
      'ignora el error sin emitir (fallo silencioso)',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      seed: () => MapLoaded(
        commerces: const [],
        promotions: const [],
        userLocation: _loc,
      ),
      setUp: () {
        when(promotionRepo.getNearbyPromotions(
          location: _loc,
          radiusKm: 5.0,
        )).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'error')),
        );
      },
      act: (bloc) => bloc.add(LoadNearbyPromotions(location: _loc)),
      expect: () => [],
    );
  });

  group('SearchCommerces', () {
    blocTest<MapBloc, MapState>(
      'filtra comercios por query y actualiza MapLoaded',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      seed: () => MapLoaded(
        commerces: [_fakeCommerce()],
        promotions: const [],
        userLocation: _loc,
      ),
      setUp: () {
        when(commerceRepo.searchCommerces(query: 'pizza'))
            .thenAnswer((_) async => Right([_fakeCommerce(id: 'c2')]));
      },
      act: (bloc) => bloc.add(SearchCommerces(query: 'pizza')),
      expect: () => [
        isA<MapLoaded>()
            .having((s) => s.commerces.first.id, 'id', 'c2'),
      ],
    );

    blocTest<MapBloc, MapState>(
      'emite MapError si la búsqueda falla',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      seed: () => MapLoaded(
        commerces: const [],
        promotions: const [],
        userLocation: _loc,
      ),
      setUp: () {
        when(commerceRepo.searchCommerces(query: 'pizza')).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Error búsqueda')),
        );
      },
      act: (bloc) => bloc.add(SearchCommerces(query: 'pizza')),
      expect: () => [
        isA<MapError>().having((s) => s.message, 'message', 'Error búsqueda'),
      ],
    );
  });

  group('FilterByCategory', () {
    blocTest<MapBloc, MapState>(
      'filtra en memoria por categoría',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      setUp: () {
        when(commerceRepo.getNearbyCommerces(
          location: _loc,
          radiusKm: 5.0,
        )).thenAnswer((_) async => Right([
              _fakeCommerce(id: 'c1', category: CommerceCategory.restaurants),
              _fakeCommerce(id: 'c2', category: CommerceCategory.cafes),
            ]));
      },
      act: (bloc) async {
        bloc.add(LoadNearbyCommerces(location: _loc));
        await Future.delayed(Duration.zero);
        bloc.add(
          FilterByCategory(location: _loc, category: CommerceCategory.restaurants),
        );
      },
      expect: () => [
        MapLoading(),
        isA<MapLoaded>().having((s) => s.commerces.length, 'all', 2),
        isA<MapLoaded>()
            .having((s) => s.commerces.length, 'filtered', 1)
            .having((s) => s.activeCategory, 'cat', CommerceCategory.restaurants),
      ],
    );
  });

  group('SelectCommerce', () {
    blocTest<MapBloc, MapState>(
      'emite MapLoaded con selectedCommerce',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      seed: () => MapLoaded(
        commerces: [_fakeCommerce()],
        promotions: const [],
        userLocation: _loc,
      ),
      setUp: () {
        when(commerceRepo.getCommerce('c1'))
            .thenAnswer((_) async => Right(_fakeCommerce()));
      },
      act: (bloc) => bloc.add(SelectCommerce(commerceId: 'c1')),
      expect: () => [
        isA<MapLoaded>()
            .having((s) => s.selectedCommerce?.id, 'selected', 'c1'),
      ],
    );
  });

  group('ClearSelection', () {
    blocTest<MapBloc, MapState>(
      'emite MapLoaded sin selectedCommerce',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      seed: () => MapLoaded(
        commerces: [_fakeCommerce()],
        promotions: const [],
        userLocation: _loc,
        selectedCommerce: _fakeCommerce(),
      ),
      act: (bloc) => bloc.add(ClearSelection()),
      expect: () => [
        isA<MapLoaded>()
            .having((s) => s.selectedCommerce, 'selected', isNull),
      ],
    );
  });

  group('UpdateUserLocation', () {
    blocTest<MapBloc, MapState>(
      'desencadena LoadNearbyCommerces y actualiza la ubicación',
      build: () => _buildBloc(commerceRepo, promotionRepo),
      setUp: () {
        when(commerceRepo.getNearbyCommerces(
          location: _loc,
          radiusKm: 5.0,
        )).thenAnswer((_) async => Right([_fakeCommerce()]));
        when(promotionRepo.getNearbyPromotions(
          location: _loc,
          radiusKm: 5.0,
        )).thenAnswer((_) async => const Right([]));
      },
      act: (bloc) => bloc.add(UpdateUserLocation(location: _loc)),
      expect: () => [
        MapLoading(),
        isA<MapLoaded>()
            .having((s) => s.userLocation, 'location', _loc)
            .having((s) => s.commerces.length, 'commerces', 1),
      ],
    );
  });
}
