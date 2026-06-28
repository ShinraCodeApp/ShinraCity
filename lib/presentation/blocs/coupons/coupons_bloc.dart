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

  CouponsBloc({
    required CouponRepository couponRepository,
    required String userId,
    AnalyticsService? analytics,
  })  : _couponRepository = couponRepository,
        _analytics = analytics,
        _userId = userId,
        super(CouponsInitial()) {
    on<LoadUserCouponsEvent>(_onLoadUserCoupons);
    on<ClaimCouponEvent>(_onClaimCoupon);
    on<ValidateCouponEvent>(_onValidateCoupon);
    on<CancelCouponEvent>(_onCancelCoupon);
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
      (_) => add(LoadUserCouponsEvent()),
    );
  }
}
