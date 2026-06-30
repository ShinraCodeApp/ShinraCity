import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/coupon_entity.dart';
import 'package:shinra_city/domain/repositories/coupon_repository.dart';
import 'package:shinra_city/presentation/blocs/coupons/coupons_bloc.dart';

// ─── Manual mock ───────────────────────────────────────────────────────────

class MockCouponRepository extends Mock implements CouponRepository {
  @override
  Future<Either<Failure, List<CouponEntity>>> getUserCoupons({
    required String? userId,
    CouponStatus? status,
    int limit = 20,
    String? lastCouponId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getUserCoupons, [], {
          #userId: userId,
          #status: status,
          #limit: limit,
          #lastCouponId: lastCouponId,
        }),
        returnValue: Future<Either<Failure, List<CouponEntity>>>.value(const Right([])),
      );

  @override
  Future<Either<Failure, CouponEntity>> claimCoupon({
    required String? userId,
    required String? promotionId,
    required String? deviceId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#claimCoupon, [], {
          #userId: userId,
          #promotionId: promotionId,
          #deviceId: deviceId,
        }),
        returnValue: Future<Either<Failure, CouponEntity>>.value(
          Left(ServerFailure(message: 'error')),
        ),
      );

  @override
  Future<Either<Failure, CouponEntity>> validateAndRedeemCoupon({
    required String? qrData,
    required String? employeeId,
    required String? commerceId,
    String? branchId,
  }) =>
      super.noSuchMethod(
        Invocation.method(#validateAndRedeemCoupon, [], {
          #qrData: qrData,
          #employeeId: employeeId,
          #commerceId: commerceId,
          #branchId: branchId,
        }),
        returnValue: Future<Either<Failure, CouponEntity>>.value(
          Left(ServerFailure(message: 'error')),
        ),
      );

  @override
  Future<Either<Failure, void>> cancelCoupon({
    required String? couponId,
    required String? userId,
    String? reason,
  }) =>
      super.noSuchMethod(
        Invocation.method(#cancelCoupon, [], {
          #couponId: couponId,
          #userId: userId,
          #reason: reason,
        }),
        returnValue: Future<Either<Failure, void>>.value(const Right(null)),
      );
}

// ─── Helpers ───────────────────────────────────────────────────────────────

CouponEntity _fakeCoupon({CouponStatus status = CouponStatus.available}) =>
    CouponEntity(
      id: 'cp1',
      userId: 'u1',
      commerceId: 'c1',
      commerceName: 'Comercio Test',
      promotionId: 'p1',
      promotionTitle: 'Promo Test',
      token: 'tok_abc123',
      qrData: '{"couponId":"cp1","token":"tok_abc123","commerceId":"c1"}',
      checksum: 'cs123',
      status: status,
      issuedAt: DateTime(2025),
      expiresAt: DateTime(2025, 12),
      deviceFingerprint: 'device_fp_xyz',
    );

CouponsBloc _buildBloc(MockCouponRepository repo) =>
    CouponsBloc(couponRepository: repo, userId: 'u1');

// ─── Tests ─────────────────────────────────────────────────────────────────

void main() {
  late MockCouponRepository repo;

  setUp(() => repo = MockCouponRepository());

  group('LoadUserCoupons', () {
    blocTest<CouponsBloc, CouponsState>(
      'emite CouponsLoaded con la lista de cupones',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.getUserCoupons(userId: 'u1')).thenAnswer(
          (_) async => Right([_fakeCoupon(), _fakeCoupon(status: CouponStatus.used)]),
        );
      },
      act: (bloc) => bloc.add(LoadUserCouponsEvent()),
      expect: () => [
        CouponsLoading(),
        isA<CouponsLoaded>()
            .having((s) => s.coupons.length, 'count', 2),
      ],
    );

    blocTest<CouponsBloc, CouponsState>(
      'emite CouponsError si el repositorio falla',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.getUserCoupons(userId: 'u1')).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Sin conexión')),
        );
      },
      act: (bloc) => bloc.add(LoadUserCouponsEvent()),
      expect: () => [
        CouponsLoading(),
        isA<CouponsError>()
            .having((s) => s.message, 'message', 'Sin conexión'),
      ],
    );

    blocTest<CouponsBloc, CouponsState>(
      'pasa filtro de status al repositorio',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.getUserCoupons(
          userId: 'u1',
          status: CouponStatus.used,
        )).thenAnswer((_) async => Right([_fakeCoupon(status: CouponStatus.used)]));
      },
      act: (bloc) =>
          bloc.add(LoadUserCouponsEvent(status: CouponStatus.used)),
      expect: () => [
        CouponsLoading(),
        isA<CouponsLoaded>()
            .having((s) => s.coupons.first.status, 'status', CouponStatus.used),
      ],
    );
  });

  group('ClaimCoupon', () {
    blocTest<CouponsBloc, CouponsState>(
      'emite CouponClaimed con el cupón generado',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.claimCoupon(
          userId: 'u1',
          promotionId: 'p1',
          deviceId: 'dev1',
        )).thenAnswer((_) async => Right(_fakeCoupon()));
      },
      act: (bloc) => bloc.add(
        ClaimCouponEvent(promotionId: 'p1', deviceId: 'dev1'),
      ),
      expect: () => [
        CouponsLoading(),
        isA<CouponClaimed>()
            .having((s) => s.coupon.promotionId, 'promotionId', 'p1'),
      ],
    );

    blocTest<CouponsBloc, CouponsState>(
      'emite CouponsError si la reclamación falla',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.claimCoupon(
          userId: 'u1',
          promotionId: 'p1',
          deviceId: 'dev1',
        )).thenAnswer(
          (_) async => const Left(
            ValidationFailure(message: 'Ya tenés un cupón activo'),
          ),
        );
      },
      act: (bloc) => bloc.add(
        ClaimCouponEvent(promotionId: 'p1', deviceId: 'dev1'),
      ),
      expect: () => [
        CouponsLoading(),
        isA<CouponsError>()
            .having((s) => s.message, 'message', 'Ya tenés un cupón activo'),
      ],
    );
  });

  group('ValidateCoupon', () {
    const qrData = '{"couponId":"cp1","token":"tok_abc123","commerceId":"c1"}';

    blocTest<CouponsBloc, CouponsState>(
      'emite CouponValidated con el resultado de validación',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.validateAndRedeemCoupon(
          qrData: qrData,
          employeeId: 'u1',
          commerceId: 'c1',
        )).thenAnswer(
          (_) async => Right(_fakeCoupon(status: CouponStatus.used)),
        );
      },
      act: (bloc) => bloc.add(
        ValidateCouponEvent(qrData: qrData, commerceId: 'c1'),
      ),
      expect: () => [
        CouponsLoading(),
        isA<CouponValidated>()
            .having(
              (s) => s.result['message'],
              'message',
              '¡Cupón validado exitosamente!',
            ),
      ],
    );

    blocTest<CouponsBloc, CouponsState>(
      'emite CouponsError si el QR es inválido',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.validateAndRedeemCoupon(
          qrData: qrData,
          employeeId: 'u1',
          commerceId: 'c1',
        )).thenAnswer(
          (_) async => const Left(
            ValidationFailure(message: 'QR inválido o expirado'),
          ),
        );
      },
      act: (bloc) => bloc.add(
        ValidateCouponEvent(qrData: qrData, commerceId: 'c1'),
      ),
      expect: () => [
        CouponsLoading(),
        isA<CouponsError>()
            .having((s) => s.message, 'message', 'QR inválido o expirado'),
      ],
    );

    blocTest<CouponsBloc, CouponsState>(
      'emite CouponsError si el cupón no pertenece al comercio',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.validateAndRedeemCoupon(
          qrData: qrData,
          employeeId: 'u1',
          commerceId: 'c1',
        )).thenAnswer(
          (_) async => const Left(
            ValidationFailure(message: 'Cupón no válido para este comercio'),
          ),
        );
      },
      act: (bloc) => bloc.add(
        ValidateCouponEvent(qrData: qrData, commerceId: 'c1'),
      ),
      expect: () => [
        CouponsLoading(),
        isA<CouponsError>().having(
          (s) => s.message,
          'message',
          'Cupón no válido para este comercio',
        ),
      ],
    );
  });

  group('CancelCouponEvent', () {
    blocTest<CouponsBloc, CouponsState>(
      'emite [CouponsLoading, CouponsLoaded] al cancelar exitosamente',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.cancelCoupon(couponId: 'cp1', userId: 'u1'))
            .thenAnswer((_) async => const Right(null));
        when(repo.getUserCoupons(userId: 'u1'))
            .thenAnswer((_) async => const Right([]));
      },
      act: (bloc) => bloc.add(CancelCouponEvent(couponId: 'cp1')),
      expect: () => [
        CouponsLoading(),
        isA<CouponsLoaded>(),
      ],
    );

    blocTest<CouponsBloc, CouponsState>(
      'emite CouponsError si la cancelación falla',
      build: () => _buildBloc(repo),
      setUp: () {
        when(repo.cancelCoupon(couponId: 'cp1', userId: 'u1')).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'No se pudo cancelar')),
        );
      },
      act: (bloc) => bloc.add(CancelCouponEvent(couponId: 'cp1')),
      expect: () => [
        isA<CouponsError>()
            .having((s) => s.message, 'msg', 'No se pudo cancelar'),
      ],
    );
  });
}
