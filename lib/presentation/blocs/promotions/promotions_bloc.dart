import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../../domain/repositories/promotion_repository.dart';
import '../../../services/analytics_service.dart';

part 'promotions_event.dart';
part 'promotions_state.dart';

class PromotionsBloc extends Bloc<PromotionsEvent, PromotionsState> {
  final PromotionRepository _repository;
  final AnalyticsService? _analytics;

  PromotionsBloc({
    required PromotionRepository repository,
    AnalyticsService? analytics,
  })  : _repository = repository,
        _analytics = analytics,
        super(PromotionsInitial()) {
    on<LoadCommercePromotions>(_onLoadCommercePromotions);
    on<LoadNearbyPromotions>(_onLoadNearbyPromotions);
    on<CreatePromotion>(_onCreatePromotion);
    on<UpdatePromotion>(_onUpdatePromotion);
    on<ChangePromotionStatus>(_onChangePromotionStatus);
    on<DeletePromotion>(_onDeletePromotion);
    on<WatchCommercePromotions>(_onWatchCommercePromotions);
  }

  Future<void> _onLoadCommercePromotions(
    LoadCommercePromotions event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(PromotionsLoading());
    final result = await _repository.getCommercePromotions(
      commerceId: event.commerceId,
      status: event.status,
    );
    result.fold(
      (failure) => emit(PromotionsError(failure.message)),
      (promotions) => emit(PromotionsLoaded(promotions)),
    );
  }

  Future<void> _onLoadNearbyPromotions(
    LoadNearbyPromotions event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(PromotionsLoading());
    final result = await _repository.getNearbyPromotions(
      location: event.location,
      radiusKm: event.radiusKm,
      categories: event.categories,
    );
    result.fold(
      (failure) => emit(PromotionsError(failure.message)),
      (promotions) => emit(PromotionsLoaded(promotions)),
    );
  }

  Future<void> _onCreatePromotion(
    CreatePromotion event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(PromotionOperationLoading());
    final result = await _repository.createPromotion(event.promotion);
    result.fold(
      (failure) => emit(PromotionsError(failure.message)),
      (created) {
        _analytics?.logCreatePromotion(
          commerceId: created.commerceId,
          type: created.type.name,
          discountValue: created.discountValue,
        );
        emit(PromotionCreated(created));
      },
    );
  }

  Future<void> _onUpdatePromotion(
    UpdatePromotion event,
    Emitter<PromotionsState> emit,
  ) async {
    emit(PromotionOperationLoading());
    final result = await _repository.updatePromotion(event.promotion);
    result.fold(
      (failure) => emit(PromotionsError(failure.message)),
      (updated) => emit(PromotionUpdated(updated)),
    );
  }

  Future<void> _onChangePromotionStatus(
    ChangePromotionStatus event,
    Emitter<PromotionsState> emit,
  ) async {
    final result = await _repository.changePromotionStatus(
      promotionId: event.promotionId,
      status: event.status,
    );
    result.fold(
      (failure) => emit(PromotionsError(failure.message)),
      (_) => emit(PromotionStatusChanged(event.promotionId, event.status)),
    );
  }

  Future<void> _onDeletePromotion(
    DeletePromotion event,
    Emitter<PromotionsState> emit,
  ) async {
    final result = await _repository.deletePromotion(event.promotionId);
    result.fold(
      (failure) => emit(PromotionsError(failure.message)),
      (_) => emit(PromotionDeleted(event.promotionId)),
    );
  }

  Future<void> _onWatchCommercePromotions(
    WatchCommercePromotions event,
    Emitter<PromotionsState> emit,
  ) async {
    await emit.forEach(
      _repository.watchCommercePromotions(event.commerceId),
      onData: (promotions) => PromotionsLoaded(promotions),
      onError: (_, __) => const PromotionsError('Error al cargar promociones'),
    );
  }
}
