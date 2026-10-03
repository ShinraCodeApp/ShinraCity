import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/coupon_entity.dart';
import '../../../domain/repositories/coupon_repository.dart';
import '../../../services/analytics_service.dart';

// Events
abstract class CouponsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class WatchUserCouponsEvent extends CouponsEvent {}

class LoadUserCouponsEvent extends CouponsEvent {
  final CouponStatus? status;
  LoadUserCouponsEvent({this.status});
}

class ClaimCouponEvent extends CouponsEvent {
  final String promotionId;
  final String deviceId;
  ClaimCouponEvent({required this.promotionId, required this.deviceId});

  @override
  List<Object?> get props => [promotionId, deviceId];
}

class ValidateCouponEvent extends CouponsEvent {
  final String qrData;
  final String commerceId;
  final String? branchId;

  ValidateCouponEvent({
    required this.qrData,
    required this.commerceId,
    this.branchId,
  });

  @override
  List<Object?> get props => [qrData, commerceId];
}

class CancelCouponEvent extends CouponsEvent {
  final String couponId;
  CancelCouponEvent({required this.couponId});

  @override
  List<Object?> get props => [couponId];
}

class _CouponsStreamUpdated extends CouponsEvent {
  final List<CouponEntity> coupons;
  _CouponsStreamUpdated(this.coupons);

  @override
  List<Object?> get props => [coupons];
}

// States
abstract class CouponsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CouponsInitial extends CouponsState {}

class CouponsLoading extends CouponsState {}

class CouponsLoaded extends CouponsState {
  final List<CouponEntity> coupons;
  CouponsLoaded(this.coupons);

  @override
  List<Object?> get props => [coupons];
}

class CouponClaimed extends CouponsState {
  final CouponEntity coupon;
  CouponClaimed(this.coupon);

  @override
  List<Object?> get props => [coupon];
}

class CouponValidated extends CouponsState {
  final Map<String, dynamic> result;
  CouponValidated(this.result);

  @override
  List<Object?> get props => [result];
}

// Emitted when the business owner redeems a coupon externally (via QR scan)
class CouponRedeemedExternally extends CouponsState {
  final CouponEntity coupon;
  CouponRedeemedExternally(this.coupon);

  @override
  List<Object?> get props => [coupon];
}

class CouponsError extends CouponsState {
  final String message;
  CouponsError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class CouponsBloc extends Bloc<CouponsEvent, CouponsState> {
  final CouponRepository _couponRepository;
  final AnalyticsService? _analytics;
  final String _userId;

  StreamSubscription<List<CouponEntity>>? _couponsSub;
  List<CouponEntity> _lastCoupons = [];
  bool _initialLoad = true;

  CouponsBloc({
    required CouponRepository couponRepository,
    required String userId,
    AnalyticsService? analytics,
  })  : _couponRepository = couponRepository,
        _analytics = analytics,
        _userId = userId,
        super(CouponsInitial()) {
    on<WatchUserCouponsEvent>(_onWatchUserCoupons);
    on<LoadUserCouponsEvent>(_onLoadUserCoupons);
    on<ClaimCouponEvent>(_onClaimCoupon);
    on<ValidateCouponEvent>(_onValidateCoupon);
    on<CancelCouponEvent>(_onCancelCoupon);
    on<_CouponsStreamUpdated>(_onCouponsStreamUpdated);
  }

  Future<void> _onWatchUserCoupons(
    WatchUserCouponsEvent event,
    Emitter<CouponsState> emit,
  ) async {
    emit(CouponsLoading());
    _couponsSub?.cancel();
    _initialLoad = true;
    _couponsSub = _couponRepository.watchUserCoupons(_userId).listen(
      (coupons) => add(_CouponsStreamUpdated(coupons)),
      onError: (_) {},
    );
  }

  Future<void> _onCouponsStreamUpdated(
    _CouponsStreamUpdated event,
    Emitter<CouponsState> emit,
  ) async {
    if (!_initialLoad) {
      // Detect coupons that were available before and are now used (externally redeemed)
      final prevAvailableIds = _lastCoupons
          .where((c) => c.status == CouponStatus.available)
          .map((c) => c.id)
          .toSet();

      final externallyRedeemed = event.coupons.where(
        (c) => c.status == CouponStatus.used && prevAvailableIds.contains(c.id),
      );

      if (externallyRedeemed.isNotEmpty) {
        emit(CouponRedeemedExternally(externallyRedeemed.first));
      }
    }

    _lastCoupons = event.coupons;
    _initialLoad = false;
    emit(CouponsLoaded(event.coupons));
    _claimPointsForUsedCoupons(event.coupons);
  }

  /// Cupones canjeados por el comercio: cobrar sus puntos (una vez por
  /// sesión cada uno; si ya estaban cobrados no suma nada).
  final Set<String> _pointsChecked = {};
  void _claimPointsForUsedCoupons(List<CouponEntity> coupons) {
    final ids = coupons
        .where((c) => c.status == CouponStatus.used && _pointsChecked.add(c.id))
        .map((c) => c.id)
        .toList();
    if (ids.isEmpty) return;
    _couponRepository.claimRedemptionPoints(userId: _userId, couponIds: ids);
  }

  Future<void> _onLoadUserCoupons(
    LoadUserCouponsEvent event,
    Emitter<CouponsState> emit,
  ) async {
    emit(CouponsLoading());
    final result = await _couponRepository.getUserCoupons(
      userId: _userId,
      status: event.status,
    );
    result.fold(
      (failure) => emit(CouponsError(failure.message)),
      (coupons) => emit(CouponsLoaded(coupons)),
    );
  }

  Future<void> _onClaimCoupon(
    ClaimCouponEvent event,
    Emitter<CouponsState> emit,
  ) async {
    emit(CouponsLoading());
    final result = await _couponRepository.claimCoupon(
      userId: _userId,
      promotionId: event.promotionId,
      deviceId: event.deviceId,
    );
    result.fold(
      (failure) => emit(CouponsError(failure.message)),
      (coupon) {
        _analytics?.logClaimCoupon(
          promotionId: coupon.promotionId,
          commerceId: coupon.commerceId,
          promotionType: 'coupon',
        );
        emit(CouponClaimed(coupon));
      },
    );
  }

  Future<void> _onValidateCoupon(
    ValidateCouponEvent event,
    Emitter<CouponsState> emit,
  ) async {
    emit(CouponsLoading());
    final result = await _couponRepository.validateAndRedeemCoupon(
      qrData: event.qrData,
      employeeId: _userId,
      commerceId: event.commerceId,
      branchId: event.branchId,
    );
    result.fold(
      (failure) => emit(CouponsError(failure.message)),
      (coupon) {
        _analytics?.logRedeemCoupon(
          couponId: coupon.id,
          commerceId: coupon.commerceId,
        );
        emit(CouponValidated({
          'coupon': coupon,
          'message': '¡Cupón validado exitosamente!',
        }));
      },
    );
  }

  Future<void> _onCancelCoupon(
    CancelCouponEvent event,
    Emitter<CouponsState> emit,
  ) async {
    final result = await _couponRepository.cancelCoupon(
      couponId: event.couponId,
      userId: _userId,
    );
    result.fold(
      (failure) => emit(CouponsError(failure.message)),
      (_) => add(WatchUserCouponsEvent()),
    );
  }

  @override
  Future<void> close() {
    _couponsSub?.cancel();
    return super.close();
  }
}
