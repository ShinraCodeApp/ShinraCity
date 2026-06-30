import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../services/analytics_service.dart';

// Events
abstract class CommerceEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadBusinessDashboard extends CommerceEvent {}

class LoadCommerceDetail extends CommerceEvent {
  final String commerceId;
  LoadCommerceDetail(this.commerceId);

  @override
  List<Object?> get props => [commerceId];
}

class ToggleFavoriteEvent extends CommerceEvent {
  final String commerceId;
  ToggleFavoriteEvent(this.commerceId);

  @override
  List<Object?> get props => [commerceId];
}

class ToggleFollowEvent extends CommerceEvent {
  final String commerceId;
  ToggleFollowEvent(this.commerceId);

  @override
  List<Object?> get props => [commerceId];
}

class UpdateCommerceEvent extends CommerceEvent {
  final CommerceEntity commerce;
  UpdateCommerceEvent(this.commerce);

  @override
  List<Object?> get props => [commerce];
}

class UploadCommerceLogo extends CommerceEvent {
  final String commerceId;
  final String filePath;
  UploadCommerceLogo({required this.commerceId, required this.filePath});

  @override
  List<Object?> get props => [commerceId, filePath];
}

// States
abstract class CommerceState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CommerceInitial extends CommerceState {}

class CommerceLoading extends CommerceState {}

class NoCommerceRegistered extends CommerceState {}

class CommerceDashboardLoaded extends CommerceState {
  final CommerceEntity commerce;
  final Map<String, dynamic> stats;
  final List<int> chartData;
  final List<Map<String, dynamic>> recentActivity;
  final List<String> aiSuggestions;

  CommerceDashboardLoaded({
    required this.commerce,
    required this.stats,
    required this.chartData,
    required this.recentActivity,
    required this.aiSuggestions,
  });

  @override
  List<Object?> get props => [commerce, stats, commerce.logoUrl];
}

class CommerceDetailLoaded extends CommerceState {
  final CommerceEntity commerce;
  final bool isFavorite;
  final bool isFollowing;

  CommerceDetailLoaded({
    required this.commerce,
    this.isFavorite = false,
    this.isFollowing = false,
  });

  @override
  List<Object?> get props => [commerce, isFavorite, isFollowing];

  CommerceDetailLoaded copyWith({bool? isFavorite, bool? isFollowing}) {
    return CommerceDetailLoaded(
      commerce: commerce,
      isFavorite: isFavorite ?? this.isFavorite,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class CommerceError extends CommerceState {
  final String message;
  CommerceError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class CommerceBloc extends Bloc<CommerceEvent, CommerceState> {
  final CommerceRepository _commerceRepository;
  final AnalyticsService? _analytics;
  final String _userId;

  CommerceBloc({
    required CommerceRepository commerceRepository,
    required String userId,
    AnalyticsService? analytics,
  })  : _commerceRepository = commerceRepository,
        _analytics = analytics,
        _userId = userId,
        super(CommerceInitial()) {
    on<LoadBusinessDashboard>(_onLoadBusinessDashboard);
    on<LoadCommerceDetail>(_onLoadCommerceDetail);
    on<ToggleFavoriteEvent>(_onToggleFavorite);
    on<ToggleFollowEvent>(_onToggleFollow);
    on<UpdateCommerceEvent>(_onUpdateCommerce);
    on<UploadCommerceLogo>(_onUploadCommerceLogo);
  }

  Future<void> _onLoadBusinessDashboard(
    LoadBusinessDashboard event,
    Emitter<CommerceState> emit,
  ) async {
    emit(CommerceLoading());

    final result = await _commerceRepository.getCommerceByOwnerId(_userId);
    await result.fold(
      (_) async => emit(NoCommerceRegistered()),
      (commerce) async {
        // Start all secondary fetches in parallel
        final analyticsFuture = _commerceRepository.getCommerceAnalytics(
          commerceId: commerce.id,
        );
        final aiFuture = _commerceRepository.getAiSuggestions(
          commerceId: commerce.id,
        );
        final chartFuture = _commerceRepository.getDailyCouponCounts(
          commerceId: commerce.id,
        );
        final activityFuture = _commerceRepository.getRecentCouponActivity(
          commerceId: commerce.id,
        );

        final analyticsResult = await analyticsFuture;
        final aiResult = await aiFuture;
        final chartResult = await chartFuture;
        final activityResult = await activityFuture;

        final analytics = analyticsResult.fold(
          (_) => <String, dynamic>{},
          (a) => a,
        );
        final aiSuggestions = aiResult.fold((_) => <String>[], (s) => s);
        final chartData = chartResult.fold(
          (_) => List<int>.filled(30, 0),
          (c) => c,
        );
        final recentActivity = activityResult.fold(
          (_) => <Map<String, dynamic>>[],
          (a) => a,
        );

        emit(CommerceDashboardLoaded(
          commerce: commerce,
          stats: {
            'claimed': analytics['claimed'] ?? 0,
            'redeemed': analytics['redeemed'] ?? 0,
            'conversionRate': analytics['conversionRate'] ?? 0,
            'followerCount':
                analytics['followerCount'] ?? commerce.followerCount,
            'activePromotions':
                analytics['activePromotions'] ?? commerce.activePromotionsCount,
            'totalRedemptions': analytics['totalRedemptions'] ?? 0,
          },
          chartData: chartData,
          recentActivity: recentActivity,
          aiSuggestions: aiSuggestions,
        ));
      },
    );
  }

  Future<void> _onLoadCommerceDetail(
    LoadCommerceDetail event,
    Emitter<CommerceState> emit,
  ) async {
    emit(CommerceLoading());
    final result = await _commerceRepository.getCommerce(event.commerceId);
    await result.fold(
      (failure) async => emit(CommerceError(failure.message)),
      (commerce) async {
        bool isFavorite = false;
        bool isFollowing = false;
        if (_userId.isNotEmpty) {
          final favResult = await _commerceRepository.isUserFavorite(
            userId: _userId,
            commerceId: event.commerceId,
          );
          final followResult = await _commerceRepository.isUserFollowing(
            userId: _userId,
            commerceId: event.commerceId,
          );
          isFavorite = favResult.getOrElse(() => false);
          isFollowing = followResult.getOrElse(() => false);
        }
        _analytics?.logViewCommerce(
          commerceId: commerce.id,
          commerceName: commerce.name,
          category: commerce.category.name,
        );
        emit(CommerceDetailLoaded(
          commerce: commerce,
          isFavorite: isFavorite,
          isFollowing: isFollowing,
        ));
      },
    );
  }

  Future<void> _onToggleFavorite(
    ToggleFavoriteEvent event,
    Emitter<CommerceState> emit,
  ) async {
    await _commerceRepository.toggleFavorite(
      userId: _userId,
      commerceId: event.commerceId,
    );

    if (state is CommerceDetailLoaded) {
      final current = state as CommerceDetailLoaded;
      emit(current.copyWith(isFavorite: !current.isFavorite));
    }
  }

  Future<void> _onToggleFollow(
    ToggleFollowEvent event,
    Emitter<CommerceState> emit,
  ) async {
    await _commerceRepository.toggleFollow(
      userId: _userId,
      commerceId: event.commerceId,
    );

    if (state is CommerceDetailLoaded) {
      final current = state as CommerceDetailLoaded;
      final nowFollowing = !current.isFollowing;
      if (nowFollowing) {
        _analytics?.logFollowCommerce(commerceId: event.commerceId);
      }
      emit(current.copyWith(isFollowing: nowFollowing));
    }
  }

  Future<void> _onUpdateCommerce(
    UpdateCommerceEvent event,
    Emitter<CommerceState> emit,
  ) async {
    final result = await _commerceRepository.updateCommerce(event.commerce);
    result.fold(
      (failure) => emit(CommerceError(failure.message)),
      (_) {
        if (state is CommerceDashboardLoaded) {
          final s = state as CommerceDashboardLoaded;
          emit(CommerceDashboardLoaded(
            commerce: event.commerce,
            stats: s.stats,
            chartData: s.chartData,
            recentActivity: s.recentActivity,
            aiSuggestions: s.aiSuggestions,
          ));
        }
      },
    );
  }

  Future<void> _onUploadCommerceLogo(
    UploadCommerceLogo event,
    Emitter<CommerceState> emit,
  ) async {
    final result = await _commerceRepository.uploadLogo(
      commerceId: event.commerceId,
      filePath: event.filePath,
    );
    result.fold(
      (_) => null,
      (logoUrl) {
        if (state is CommerceDashboardLoaded) {
          final s = state as CommerceDashboardLoaded;
          emit(CommerceDashboardLoaded(
            commerce: s.commerce.copyWith(logoUrl: logoUrl),
            stats: s.stats,
            chartData: s.chartData,
            recentActivity: s.recentActivity,
            aiSuggestions: s.aiSuggestions,
          ));
        }
      },
    );
  }
}
