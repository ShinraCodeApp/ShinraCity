/// Integration-level test: claim a coupon, capture the QR data produced, and
/// use it to validate — simulating the real user flow without a running backend.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/coupon_entity.dart';
import 'package:shinra_city/domain/repositories/coupon_repository.dart';
import 'package:shinra_city/presentation/blocs/coupons/coupons_bloc.dart';

// ─── Mock ──────────────────────────────────────────────────────────────────

class MockCouponRepository extends Mock implements CouponRepository {
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
        returnValueForMissingStub: Future<Either<Failure, CouponEntity>>.value(
          Left(ServerFailure(message: 'error')),
        ),
      ) as Future<Either<Failure, CouponEntity>>;

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
        returnValueForMissingStub: Future<Either<Failure, CouponEntity>>.value(
          Left(ServerFailure(message: 'error')),
        ),
      ) as Future<Either<Failure, CouponEntity>>;

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
        returnValue: Future<Either<Failure, List<CouponEntity>>>.value(
          const Right([]),
        ),
        returnValueForMissingStub: Future<Either<Failure, List<CouponEntity>>>.value(
          const Right([]),
        ),
      ) as Future<Either<Failure, List<CouponEntity>>>;

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
        returnValueForMissingStub:
            Future<Either<Failure, void>>.value(const Right(null)),
      ) as Future<Either<Failure, void>>;
}

// ─── Helpers ───────────────────────────────────────────────────────────────

const _userId = 'u1';
const _employeeId = 'emp1';
const _commerceId = 'c1';
const _promotionId = 'p1';
const _deviceId = 'device_xyz';
const _qrData =
    '{"couponId":"cp1","token":"tok_abc123","commerceId":"c1","checksum":"cs123"}';

CouponEntity _claimedCoupon() => CouponEntity(
      id: 'cp1',
      userId: _userId,
      commerceId: _commerceId,
      commerceName: 'Café Centro',
      promotionId: _promotionId,
      promotionTitle: '2x1 en cafés',
      token: 'tok_abc123',
      qrData: _qrData,
      checksum: 'cs123',
      status: CouponStatus.available,
      issuedAt: DateTime(2025, 6, 1),
      expiresAt: DateTime(2025, 12, 31),
      deviceFingerprint: _deviceId,
    );

CouponEntity _redeemedCoupon() => _claimedCoupon().copyWith(
      status: CouponStatus.used,
      usedAt: DateTime(2025, 6, 1, 14, 30),
    );

// ─── Tests ─────────────────────────────────────────────────────────────────

void main() {
  late MockCouponRepository repo;

  setUp(() => repo = MockCouponRepository());

  group('Flujo completo cupón: claim → QR → validate', () {
    test('claim produce CouponClaimed con qrData; qrData válido para validate',
        () async {
      // Setup
      when(repo.claimCoupon(
        userId: _userId,
        promotionId: _promotionId,
        deviceId: _deviceId,
      )).thenAnswer((_) async => Right(_claimedCoupon()));

      when(repo.validateAndRedeemCoupon(
        qrData: _qrData,
        employeeId: _employeeId,
        commerceId: _commerceId,
      )).thenAnswer((_) async => Right(_redeemedCoupon()));

      // === PASO 1: USUARIO RECLAMA CUPÓN ===
      final userBloc = CouponsBloc(
        couponRepository: repo,
        userId: _userId,
      );

      userBloc.add(ClaimCouponEvent(
        promotionId: _promotionId,
        deviceId: _deviceId,
      ));

      // Espera a que el BLoC procese el evento
      final claimStates = await userBloc.stream
          .take(2)
          .toList()
          .timeout(const Duration(seconds: 5));

      expect(claimStates[0], isA<CouponsLoading>());
      expect(claimStates[1], isA<CouponClaimed>());

      final claimedState = claimStates[1] as CouponClaimed;
      expect(claimedState.coupon.id, 'cp1');
      expect(claimedState.coupon.status, CouponStatus.available);

      // Extrae el qrData del cupón reclamado (lo que se mostraría en pantalla)
      final qrDataFromClaim = claimedState.coupon.qrData;
      expect(qrDataFromClaim, isNotEmpty);

      await userBloc.close();

      // === PASO 2: EMPLEADO VALIDA EL QR ===
      final employeeBloc = CouponsBloc(
        couponRepository: repo,
        userId: _employeeId,
      );

      employeeBloc.add(ValidateCouponEvent(
        qrData: qrDataFromClaim, // usa el qrData del paso anterior
        commerceId: _commerceId,
      ));

      final validateStates = await employeeBloc.stream
          .take(2)
          .toList()
          .timeout(const Duration(seconds: 5));

      expect(validateStates[0], isA<CouponsLoading>());
      expect(validateStates[1], isA<CouponValidated>());

      final validatedState = validateStates[1] as CouponValidated;
      expect(validatedState.result['message'], '¡Cupón validado exitosamente!');

      final redeemedCoupon = validatedState.result['coupon'] as CouponEntity;
      expect(redeemedCoupon.status, CouponStatus.used);
      expect(redeemedCoupon.commerceId, _commerceId);

      await employeeBloc.close();
    });

    blocTest<CouponsBloc, CouponsState>(
      'claim falla si el usuario ya tiene un cupón activo de esa promoción',
      build: () => CouponsBloc(couponRepository: repo, userId: _userId),
      setUp: () {
        when(repo.claimCoupon(
          userId: _userId,
          promotionId: _promotionId,
          deviceId: _deviceId,
        )).thenAnswer(
          (_) async =>
              const Left(CouponFailure(message: 'Ya tenés un cupón activo')),
        );
      },
      act: (bloc) =>
          bloc.add(ClaimCouponEvent(promotionId: _promotionId, deviceId: _deviceId)),
      expect: () => [
        CouponsLoading(),
        isA<CouponsError>()
            .having((s) => s.message, 'message', 'Ya tenés un cupón activo'),
      ],
    );

    blocTest<CouponsBloc, CouponsState>(
      'validate falla si el QR pertenece a otro comercio',
      build: () =>
          CouponsBloc(couponRepository: repo, userId: _employeeId),
      setUp: () {
        when(repo.validateAndRedeemCoupon(
          qrData: _qrData,
          employeeId: _employeeId,
          commerceId: 'otro-comercio',
        )).thenAnswer(
          (_) async => const Left(
            UnauthorizedFailure(message: 'Cupón no válido para este comercio'),
          ),
        );
      },
      act: (bloc) => bloc.add(ValidateCouponEvent(
        qrData: _qrData,
        commerceId: 'otro-comercio',
      )),
      expect: () => [
        CouponsLoading(),
        isA<CouponsError>()
            .having((s) => s.message, 'message',
                'Cupón no válido para este comercio'),
      ],
    );

    blocTest<CouponsBloc, CouponsState>(
      'validate falla si el cupón ya fue usado (fraude)',
      build: () =>
          CouponsBloc(couponRepository: repo, userId: _employeeId),
      setUp: () {
        when(repo.validateAndRedeemCoupon(
          qrData: _qrData,
          employeeId: _employeeId,
          commerceId: _commerceId,
        )).thenAnswer(
          (_) async => const Left(
            FraudDetectedFailure(message: 'Cupón ya utilizado o fraudulento'),
          ),
        );
      },
      act: (bloc) => bloc.add(
          ValidateCouponEvent(qrData: _qrData, commerceId: _commerceId)),
      expect: () => [
        CouponsLoading(),
        isA<CouponsError>().having(
          (s) => s.message,
          'message',
          'Cupón ya utilizado o fraudulento',
        ),
      ],
    );
  });
}
