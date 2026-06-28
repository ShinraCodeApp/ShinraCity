part of 'promotions_bloc.dart';

abstract class PromotionsEvent extends Equatable {
  const PromotionsEvent();
  @override
  List<Object?> get props => [];
}

class LoadCommercePromotions extends PromotionsEvent {
  final String commerceId;
  final PromotionStatus? status;
  const LoadCommercePromotions({required this.commerceId, this.status});
  @override
  List<Object?> get props => [commerceId, status];
}

class LoadNearbyPromotions extends PromotionsEvent {
  final LatLng location;
  final double radiusKm;
  final List<String>? categories;
  const LoadNearbyPromotions({
    required this.location,
    required this.radiusKm,
    this.categories,
  });
  @override
  List<Object?> get props => [location, radiusKm, categories];
}

class CreatePromotion extends PromotionsEvent {
  final PromotionEntity promotion;
  const CreatePromotion(this.promotion);
  @override
  List<Object?> get props => [promotion];
}

class UpdatePromotion extends PromotionsEvent {
  final PromotionEntity promotion;
  const UpdatePromotion(this.promotion);
  @override
  List<Object?> get props => [promotion];
}

class ChangePromotionStatus extends PromotionsEvent {
  final String promotionId;
  final PromotionStatus status;
  const ChangePromotionStatus({required this.promotionId, required this.status});
  @override
  List<Object?> get props => [promotionId, status];
}

class DeletePromotion extends PromotionsEvent {
  final String promotionId;
  const DeletePromotion(this.promotionId);
  @override
  List<Object?> get props => [promotionId];
}

class WatchCommercePromotions extends PromotionsEvent {
  final String commerceId;
  const WatchCommercePromotions(this.commerceId);
  @override
  List<Object?> get props => [commerceId];
}
