import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/commerce_entity.dart';
import 'package:shinra_city/presentation/blocs/commerce/commerce_bloc.dart';

import 'commerce_bloc_test.mocks.dart';

CommerceEntity _fakeCommerce() => CommerceEntity(
      id: 'c1',
      ownerId: 'user1',
      name: 'Café Centro',
      description: 'Café en el centro',
      category: CommerceCategory.cafes,
      location: const LatLng(-34.6037, -58.3816),
      geohash: 'p0qe',
      address: 'Av. Corrientes 123',
      city: 'Buenos Aires',
      createdAt: DateTime(2024),
    );

void main() {
  late MockCommerceRepository repo;

  setUp(() {
    repo = MockCommerceRepository();
  });

  group('LoadCommerceDetail', () {
    blocTest<CommerceBloc, CommerceState>(
      'emite CommerceDetailLoaded con isFavorite=false isFollowing=false para usuario vacío',
      build: () => CommerceBloc(commerceRepository: repo, userId: ''),
      act: (bloc) => bloc.add(LoadCommerceDetail('c1')),
      setUp: () {
        when(repo.getCommerce('c1'))
            .thenAnswer((_) async => Right(_fakeCommerce()));
      },
      expect: () => [
        CommerceLoading(),
        isA<CommerceDetailLoaded>()
            .having((s) => s.isFavorite, 'isFavorite', false)
            .having((s) => s.isFollowing, 'isFollowing', false),
      ],
    );

    blocTest<CommerceBloc, CommerceState>(
      'emite CommerceDetailLoaded con estado correcto de favorito/seguimiento',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(LoadCommerceDetail('c1')),
      setUp: () {
        when(repo.getCommerce('c1'))
            .thenAnswer((_) async => Right(_fakeCommerce()));
        when(repo.isUserFavorite(userId: 'u1', commerceId: 'c1'))
            .thenAnswer((_) async => const Right(true));
        when(repo.isUserFollowing(userId: 'u1', commerceId: 'c1'))
            .thenAnswer((_) async => const Right(false));
      },
      expect: () => [
        CommerceLoading(),
        isA<CommerceDetailLoaded>()
            .having((s) => s.isFavorite, 'isFavorite', true)
            .having((s) => s.isFollowing, 'isFollowing', false),
      ],
    );

    blocTest<CommerceBloc, CommerceState>(
      'emite CommerceError cuando getCommerce falla',
      build: () => CommerceBloc(commerceRepository: repo, userId: ''),
      act: (bloc) => bloc.add(LoadCommerceDetail('c1')),
      setUp: () {
        when(repo.getCommerce('c1')).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'No encontrado')),
        );
      },
      expect: () => [
        CommerceLoading(),
        isA<CommerceError>().having((s) => s.message, 'message', 'No encontrado'),
      ],
    );
  });

  group('ToggleFavoriteEvent', () {
    blocTest<CommerceBloc, CommerceState>(
      'invierte isFavorite en el estado actual',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      seed: () => CommerceDetailLoaded(commerce: _fakeCommerce(), isFavorite: false),
      act: (bloc) => bloc.add(ToggleFavoriteEvent('c1')),
      setUp: () {
        when(repo.toggleFavorite(userId: 'u1', commerceId: 'c1'))
            .thenAnswer((_) async => const Right(null));
      },
      expect: () => [
        isA<CommerceDetailLoaded>().having((s) => s.isFavorite, 'isFavorite', true),
      ],
    );

    blocTest<CommerceBloc, CommerceState>(
      'revierte isFavorite=true a false',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      seed: () => CommerceDetailLoaded(commerce: _fakeCommerce(), isFavorite: true),
      act: (bloc) => bloc.add(ToggleFavoriteEvent('c1')),
      setUp: () {
        when(repo.toggleFavorite(userId: 'u1', commerceId: 'c1'))
            .thenAnswer((_) async => const Right(null));
      },
      expect: () => [
        isA<CommerceDetailLoaded>().having((s) => s.isFavorite, 'isFavorite', false),
      ],
    );
  });

  group('ToggleFollowEvent', () {
    blocTest<CommerceBloc, CommerceState>(
      'invierte isFollowing en el estado actual',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      seed: () => CommerceDetailLoaded(commerce: _fakeCommerce(), isFollowing: false),
      act: (bloc) => bloc.add(ToggleFollowEvent('c1')),
      setUp: () {
        when(repo.toggleFollow(userId: 'u1', commerceId: 'c1'))
            .thenAnswer((_) async => const Right(null));
      },
      expect: () => [
        isA<CommerceDetailLoaded>().having((s) => s.isFollowing, 'isFollowing', true),
      ],
    );
  });

  group('UpdateCommerceEvent', () {
    blocTest<CommerceBloc, CommerceState>(
      'actualiza el comercio en CommerceDashboardLoaded',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      seed: () => CommerceDashboardLoaded(
        commerce: _fakeCommerce(),
        stats: const {},
        chartData: const [],
        recentActivity: const [],
        aiSuggestions: const [],
      ),
      act: (bloc) {
        final updated = _fakeCommerce();
        bloc.add(UpdateCommerceEvent(updated));
      },
      setUp: () {
        when(repo.updateCommerce(any))
            .thenAnswer((_) async => Right(_fakeCommerce()));
      },
      expect: () => [isA<CommerceDashboardLoaded>()],
    );

    blocTest<CommerceBloc, CommerceState>(
      'emite CommerceError cuando updateCommerce falla',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      seed: () => CommerceDashboardLoaded(
        commerce: _fakeCommerce(),
        stats: const {},
        chartData: const [],
        recentActivity: const [],
        aiSuggestions: const [],
      ),
      act: (bloc) => bloc.add(UpdateCommerceEvent(_fakeCommerce())),
      setUp: () {
        when(repo.updateCommerce(any)).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Error al guardar')),
        );
      },
      expect: () => [isA<CommerceError>()],
    );
  });

  group('UploadCommerceLogo', () {
    blocTest<CommerceBloc, CommerceState>(
      'actualiza logoUrl en CommerceDashboardLoaded cuando sube la imagen',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      seed: () => CommerceDashboardLoaded(
        commerce: _fakeCommerce(),
        stats: const {},
        chartData: const [],
        recentActivity: const [],
        aiSuggestions: const [],
      ),
      setUp: () {
        when(repo.uploadLogo(
          commerceId: 'c1',
          filePath: '/tmp/logo.png',
        )).thenAnswer((_) async => const Right('https://cdn.test/logo.png'));
      },
      act: (bloc) => bloc.add(
        UploadCommerceLogo(commerceId: 'c1', filePath: '/tmp/logo.png'),
      ),
      expect: () => [
        isA<CommerceDashboardLoaded>().having(
          (s) => s.commerce.logoUrl,
          'logoUrl',
          'https://cdn.test/logo.png',
        ),
      ],
    );

    blocTest<CommerceBloc, CommerceState>(
      'no emite estado si uploadLogo falla',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      seed: () => CommerceDashboardLoaded(
        commerce: _fakeCommerce(),
        stats: const {},
        chartData: const [],
        recentActivity: const [],
        aiSuggestions: const [],
      ),
      setUp: () {
        when(repo.uploadLogo(
          commerceId: 'c1',
          filePath: '/tmp/logo.png',
        )).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Upload falló')),
        );
      },
      act: (bloc) => bloc.add(
        UploadCommerceLogo(commerceId: 'c1', filePath: '/tmp/logo.png'),
      ),
      expect: () => [],
    );
  });

  group('LoadBusinessDashboard', () {
    blocTest<CommerceBloc, CommerceState>(
      'emite NoCommerceRegistered cuando no hay comercio del owner',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(LoadBusinessDashboard()),
      setUp: () {
        when(repo.getCommerceByOwnerId('u1')).thenAnswer(
          (_) async => const Left(NotFoundFailure()),
        );
      },
      expect: () => [CommerceLoading(), NoCommerceRegistered()],
    );

    blocTest<CommerceBloc, CommerceState>(
      'emite CommerceDashboardLoaded cuando hay comercio',
      build: () => CommerceBloc(commerceRepository: repo, userId: 'u1'),
      act: (bloc) => bloc.add(LoadBusinessDashboard()),
      setUp: () {
        when(repo.getCommerceByOwnerId('u1'))
            .thenAnswer((_) async => Right(_fakeCommerce()));
      },
      expect: () => [
        CommerceLoading(),
        isA<CommerceDashboardLoaded>()
            .having((s) => s.commerce.id, 'id', 'c1'),
      ],
    );
  });
}
