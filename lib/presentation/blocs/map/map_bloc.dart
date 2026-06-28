import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../domain/repositories/promotion_repository.dart';
import '../../../core/constants/app_constants.dart';

// Events
abstract class MapEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadNearbyCommerces extends MapEvent {
  final LatLng location;
  final double radiusKm;
  final CommerceCategory? category;

  LoadNearbyCommerces({
    required this.location,
    this.radiusKm = AppConstants.nearbyRadiusKm,
    this.category,
  });

  @override
  List<Object?> get props => [location, radiusKm, category];
}

class LoadNearbyPromotions extends MapEvent {
  final LatLng location;
  final double radiusKm;

  LoadNearbyPromotions({
    required this.location,
    this.radiusKm = AppConstants.nearbyRadiusKm,
  });

  @override
  List<Object?> get props => [location, radiusKm];
}

class UpdateUserLocation extends MapEvent {
  final LatLng location;
  UpdateUserLocation({required this.location});

  @override
  List<Object?> get props => [location];
}

class SearchCommerces extends MapEvent {
  final String query;
  SearchCommerces({required this.query});

  @override
  List<Object?> get props => [query];
}

class FilterByCategory extends MapEvent {
  final LatLng location;
  final CommerceCategory? category;

  FilterByCategory({required this.location, this.category});

  @override
  List<Object?> get props => [location, category];
}

class SelectCommerce extends MapEvent {
  final String commerceId;
  SelectCommerce({required this.commerceId});

  @override
  List<Object?> get props => [commerceId];
}

class ClearSelection extends MapEvent {}

// States
abstract class MapState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MapInitial extends MapState {}

class MapLoading extends MapState {}

class MapLoaded extends MapState {
  final List<CommerceEntity> commerces;
  final List<PromotionEntity> promotions;
  final LatLng userLocation;
  final CommerceEntity? selectedCommerce;
  final CommerceCategory? activeCategory;

  MapLoaded({
    required this.commerces,
    required this.promotions,
    required this.userLocation,
    this.selectedCommerce,
    this.activeCategory,
  });

  @override
  List<Object?> get props => [commerces, promotions, userLocation, selectedCommerce];

  MapLoaded copyWith({
    List<CommerceEntity>? commerces,
    List<PromotionEntity>? promotions,
    LatLng? userLocation,
    CommerceEntity? selectedCommerce,
    CommerceCategory? activeCategory,
  }) {
    return MapLoaded(
      commerces: commerces ?? this.commerces,
      promotions: promotions ?? this.promotions,
      userLocation: userLocation ?? this.userLocation,
      selectedCommerce: selectedCommerce ?? this.selectedCommerce,
      activeCategory: activeCategory ?? this.activeCategory,
    );
  }
}

class MapError extends MapState {
  final String message;
  MapError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class MapBloc extends Bloc<MapEvent, MapState> {
  final CommerceRepository _commerceRepository;
  final PromotionRepository _promotionRepository;

  List<CommerceEntity> _allCommerces = [];
  List<PromotionEntity> _allPromotions = [];
  LatLng _currentLocation = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  MapBloc({
    required CommerceRepository commerceRepository,
    required PromotionRepository promotionRepository,
  })  : _commerceRepository = commerceRepository,
        _promotionRepository = promotionRepository,
        super(MapInitial()) {
    on<LoadNearbyCommerces>(_onLoadNearbyCommerces);
    on<LoadNearbyPromotions>(_onLoadNearbyPromotions);
    on<UpdateUserLocation>(_onUpdateUserLocation);
    on<SearchCommerces>(_onSearchCommerces);
    on<FilterByCategory>(_onFilterByCategory);
    on<SelectCommerce>(_onSelectCommerce);
    on<ClearSelection>(_onClearSelection);
  }

  Future<void> _onLoadNearbyCommerces(
    LoadNearbyCommerces event,
    Emitter<MapState> emit,
  ) async {
    _currentLocation = event.location;

    final result = await _commerceRepository.getNearbyCommerces(
      location: event.location,
      radiusKm: event.radiusKm,
      category: event.category,
    );

    result.fold(
      (failure) => emit(MapError(failure.message)),
      (commerces) {
        _allCommerces = commerces;
        emit(MapLoaded(
          commerces: commerces,
          promotions: _allPromotions,
          userLocation: event.location,
          activeCategory: event.category,
        ));
      },
    );
  }

  Future<void> _onLoadNearbyPromotions(
    LoadNearbyPromotions event,
    Emitter<MapState> emit,
  ) async {
    final result = await _promotionRepository.getNearbyPromotions(
      location: event.location,
      radiusKm: event.radiusKm,
    );

    result.fold(
      (_) {},
      (promotions) {
        _allPromotions = promotions;
        if (state is MapLoaded) {
          emit((state as MapLoaded).copyWith(promotions: promotions));
        }
      },
    );
  }

  Future<void> _onUpdateUserLocation(
    UpdateUserLocation event,
    Emitter<MapState> emit,
  ) async {
    _currentLocation = event.location;
    add(LoadNearbyCommerces(location: event.location));
    add(LoadNearbyPromotions(location: event.location));
  }

  Future<void> _onSearchCommerces(
    SearchCommerces event,
    Emitter<MapState> emit,
  ) async {
    if (event.query.isEmpty) {
      add(LoadNearbyCommerces(location: _currentLocation));
      return;
    }

    final result = await _commerceRepository.searchCommerces(
      query: event.query,
      location: _currentLocation,
    );

    result.fold(
      (failure) => emit(MapError(failure.message)),
      (commerces) {
        if (state is MapLoaded) {
          emit((state as MapLoaded).copyWith(commerces: commerces));
        }
      },
    );
  }

  Future<void> _onFilterByCategory(
    FilterByCategory event,
    Emitter<MapState> emit,
  ) async {
    if (event.category == null) {
      add(LoadNearbyCommerces(location: event.location));
      return;
    }

    final filtered = _allCommerces
        .where((c) => c.category == event.category)
        .toList();

    if (state is MapLoaded) {
      emit((state as MapLoaded).copyWith(
        commerces: filtered,
        activeCategory: event.category,
      ));
    }
  }

  Future<void> _onSelectCommerce(
    SelectCommerce event,
    Emitter<MapState> emit,
  ) async {
    final result = await _commerceRepository.getCommerce(event.commerceId);
    result.fold(
      (_) {},
      (commerce) {
        if (state is MapLoaded) {
          emit((state as MapLoaded).copyWith(selectedCommerce: commerce));
        }
      },
    );
  }

  void _onClearSelection(ClearSelection event, Emitter<MapState> emit) {
    if (state is MapLoaded) {
      final current = state as MapLoaded;
      emit(MapLoaded(
        commerces: current.commerces,
        promotions: current.promotions,
        userLocation: current.userLocation,
        activeCategory: current.activeCategory,
      ));
    }
  }
}
