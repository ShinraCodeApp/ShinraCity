part of 'promotions_bloc.dart';

abstract class PromotionsState extends Equatable {
  const PromotionsState();
  @override
  List<Object?> get props => [];
}

class PromotionsInitial extends PromotionsState {}

class PromotionsLoading extends PromotionsState {}

class PromotionOperationLoading extends PromotionsState {}

class PromotionsLoaded extends PromotionsState {
  final List<PromotionEntity> promotions;
  const PromotionsLoaded(this.promotions);
  @override
  List<Object?> get props => [promotions];
}

class PromotionCreated extends PromotionsState {
  final PromotionEntity promotion;
  const PromotionCreated(this.promotion);
  @override
  List<Object?> get props => [promotion];
}

class PromotionUpdated extends PromotionsState {
  final PromotionEntity promotion;
  const PromotionUpdated(this.promotion);
  @override
  List<Object?> get props => [promotion];
}

class PromotionStatusChanged extends PromotionsState {
  final String promotionId;
  final PromotionStatus status;
  const PromotionStatusChanged(this.promotionId, this.status);
  @override
  List<Object?> get props => [promotionId, status];
}

class PromotionDeleted extends PromotionsState {
  final String promotionId;
  const PromotionDeleted(this.promotionId);
  @override
  List<Object?> get props => [promotionId];
}

class PromotionsError extends PromotionsState {
  final String message;
  const PromotionsError(this.message);
  @override
  List<Object?> get props => [message];
}
