import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../../services/analytics_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/map/map_bloc.dart';
import '../../widgets/map/commerce_bottom_sheet.dart';
import '../../widgets/map/map_search_bar.dart';
import '../../widgets/map/category_filter_bar.dart';
import '../../widgets/map/nearby_promotions_panel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  final List<CircleMarker> _circles = [];
  LatLng _currentPosition = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  bool _isMapDark = true;
  bool _isSatellite = false;
  bool _showNearbyPanel = false;
  String? _selectedCommerceId;
  late AnimationController _pulseController;
  StreamSubscription<Position>? _locationStream;
  CommerceCategory? _activeCategory;

  String get _tileUrl {
    if (_isSatellite) {
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
    return _isMapDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  List<String> get _subdomains =>
      (_isMapDark && !_isSatellite) ? const ['a', 'b', 'c', 'd'] : const [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initializeLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationStream?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentPosition, AppConstants.defaultZoom);
      context.read<MapBloc>().add(LoadNearbyCommerces(location: _currentPosition));
      context.read<MapBloc>().add(LoadNearbyPromotions(location: _currentPosition));

      _locationStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).listen(_onLocationUpdate);
    } catch (e) {
      if (mounted) {
        context.read<MapBloc>().add(LoadNearbyCommerces(location: _currentPosition));
      }
    }
  }

  void _onLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);
    setState(() => _currentPosition = newLocation);
    context.read<MapBloc>().add(UpdateUserLocation(location: newLocation));
    _triggerNearbyNotification(newLocation);
    GetIt.instance<AnalyticsService>()
        .logMapOpen(lat: position.latitude, lon: position.longitude);
  }

  void _triggerNearbyNotification(LatLng location) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    FirebaseFunctions.instance
        .httpsCallable('sendNearbyPromoNotification')
        .call({
          'latitude': location.latitude,
          'longitude': location.longitude,
          'userId': authState.user.id,
        })
        .then((_) {})
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildSearchBar(),
          _buildCategoryFilter(),
          _buildMapControls(),
          _buildNearbyPanel(),
          if (_selectedCommerceId != null) _buildCommerceSheet(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return BlocListener<MapBloc, MapState>(
      listener: (context, state) {
        if (state is MapLoaded) {
          _updateMarkers(state.commerces, state.promotions);
        }
      },
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentPosition,
          initialZoom: AppConstants.defaultZoom,
          onTap: (_, __) => setState(() {
            _selectedCommerceId = null;
            _showNearbyPanel = false;
          }),
          onPositionChanged: _onCameraMove,
        ),
        children: [
          TileLayer(
            urlTemplate: _tileUrl,
            subdomains: _subdomains,
            userAgentPackageName: 'com.shinracity.app',
          ),
          CircleLayer(circles: _circles),
          MarkerLayer(markers: _markers),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition,
                width: 22,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: MapSearchBar(
        onSearch: (query) {
          context.read<MapBloc>().add(SearchCommerces(query: query));
        },
        onFilterTap: _showFilters,
      ).animate().fadeIn().slideY(begin: -0.3, end: 0),
    );
  }

  Widget _buildCategoryFilter() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 0,
      right: 0,
      child: CategoryFilterBar(
        selectedCategory: _activeCategory,
        onCategorySelected: (category) {
          setState(() => _activeCategory = category);
          context.read<MapBloc>().add(FilterByCategory(
            location: _currentPosition,
            category: category,
          ));
        },
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: _showNearbyPanel ? 300 : 100,
      child: Column(
        children: [
          _buildControlButton(
            icon: Icons.my_location,
            onTap: _centerOnLocation,
            tooltip: 'Mi ubicaciÃ³n',
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: _isMapDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
            onTap: _toggleMapStyle,
            tooltip: _isMapDark ? 'Modo claro' : 'Modo oscuro',
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: _isSatellite ? Icons.map : Icons.satellite,
            onTap: _toggleMapType,
            tooltip: _isSatellite ? 'Vista mapa' : 'Vista satÃ©lite',
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.local_offer_outlined,
            onTap: () => setState(() => _showNearbyPanel = !_showNearbyPanel),
            tooltip: 'Ofertas cercanas',
            isActive: _showNearbyPanel,
          ),
        ],
      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.3, end: 0),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isActive ? AppColors.primary : const Color(0xFF1E293B),
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? AppColors.backgroundDark : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyPanel() {
    if (!_showNearbyPanel) return const SizedBox.shrink();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: NearbyPromotionsPanel(
        onClose: () => setState(() => _showNearbyPanel = false),
        onPromotionTap: (commerceId) {
          setState(() {
            _selectedCommerceId = commerceId;
            _showNearbyPanel = false;
          });
        },
      ),
    );
  }

  Widget _buildCommerceSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: CommerceBottomSheet(
        commerceId: _selectedCommerceId!,
        userLocation: _currentPosition,
        onClose: () => setState(() => _selectedCommerceId = null),
      ),
    );
  }

  static Color _getCategoryColor(CommerceCategory category) {
    switch (category) {
      case CommerceCategory.restaurants:   return const Color(0xFFFF6B35);
      case CommerceCategory.cafes:         return const Color(0xFF8D6E63);
      case CommerceCategory.fastFood:      return const Color(0xFFFF8F00);
      case CommerceCategory.bar:           return const Color(0xFF5D4037);
      case CommerceCategory.bakery:        return const Color(0xFFFFB300);
      case CommerceCategory.pharmacies:    return const Color(0xFF43A047);
      case CommerceCategory.health:        return const Color(0xFFEF5350);
      case CommerceCategory.beauty:        return const Color(0xFFE91E63);
      case CommerceCategory.clothing:      return const Color(0xFF9C27B0);
      case CommerceCategory.supermarket:   return const Color(0xFF388E3C);
      case CommerceCategory.hardware:      return const Color(0xFF78909C);
      case CommerceCategory.jewelry:       return const Color(0xFFFFD600);
      case CommerceCategory.market:        return const Color(0xFF66BB6A);
      case CommerceCategory.streetVendor:  return const Color(0xFFFF9800);
      case CommerceCategory.entrepreneur:  return const Color(0xFF00E5FF);
      case CommerceCategory.artisans:      return const Color(0xFFD4A853);
      case CommerceCategory.services:      return const Color(0xFF607D8B);
      case CommerceCategory.automotive:    return const Color(0xFFFF5722);
      case CommerceCategory.education:     return const Color(0xFF3F51B5);
      case CommerceCategory.technology:    return const Color(0xFF2196F3);
      case CommerceCategory.entertainment: return const Color(0xFF673AB7);
      case CommerceCategory.sports:        return const Color(0xFF009688);
      case CommerceCategory.tourism:       return const Color(0xFF00BCD4);
      case CommerceCategory.pets:          return const Color(0xFFFFC107);
      case CommerceCategory.other:         return const Color(0xFF9E9E9E);
    }
  }

  void _updateMarkers(
    List<CommerceEntity> commerces,
    List<PromotionEntity> promotions,
  ) {
    final newMarkers = <Marker>[];
    final newCircles = <CircleMarker>[];

    for (final commerce in commerces) {
      final baseColor = _getCategoryColor(commerce.category);
      final hasPromo = commerce.hasActivePromotion;
      final isOpen = commerce.isCurrentlyOpen;
      final opacity = isOpen ? 0.9 : 0.45;
      final size = hasPromo ? 50.0 : 38.0;

      newMarkers.add(Marker(
        point: commerce.location,
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedCommerceId = commerce.id);
            context.read<MapBloc>().add(SelectCommerce(commerceId: commerce.id));
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Aro exterior si tiene promoción activa
              if (hasPromo)
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.8),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              // Círculo de categoría
              Container(
                width: size - (hasPromo ? 8 : 0),
                height: size - (hasPromo ? 8 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: baseColor.withOpacity(opacity),
                  border: Border.all(
                    color: Colors.white.withOpacity(isOpen ? 0.6 : 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: hasPromo
                    ? const Icon(Icons.local_offer, color: Colors.white, size: 16)
                    : Icon(
                        _getCategoryIcon(commerce.category),
                        color: Colors.white.withOpacity(isOpen ? 0.9 : 0.5),
                        size: 14,
                      ),
              ),
            ],
          ),
        ),
      ));

      if (hasPromo) {
        newCircles.add(CircleMarker(
          point: commerce.location,
          radius: AppConstants.geofenceRadiusMeters,
          useRadiusInMeter: true,
          color: baseColor.withOpacity(0.08),
          borderColor: baseColor.withOpacity(0.4),
          borderStrokeWidth: 1,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _circles
          ..clear()
          ..addAll(newCircles);
      });
    }
  }

  static IconData _getCategoryIcon(CommerceCategory category) {
    switch (category) {
      case CommerceCategory.restaurants:   return Icons.restaurant;
      case CommerceCategory.cafes:         return Icons.coffee;
      case CommerceCategory.fastFood:      return Icons.fastfood;
      case CommerceCategory.bar:           return Icons.sports_bar;
      case CommerceCategory.bakery:        return Icons.bakery_dining;
      case CommerceCategory.pharmacies:    return Icons.local_pharmacy;
      case CommerceCategory.health:        return Icons.health_and_safety;
      case CommerceCategory.beauty:        return Icons.face_retouching_natural;
      case CommerceCategory.clothing:      return Icons.checkroom;
      case CommerceCategory.supermarket:   return Icons.shopping_cart;
      case CommerceCategory.hardware:      return Icons.construction;
      case CommerceCategory.jewelry:       return Icons.diamond;
      case CommerceCategory.market:        return Icons.storefront;
      case CommerceCategory.streetVendor:  return Icons.shopping_bag;
      case CommerceCategory.entrepreneur:  return Icons.rocket_launch;
      case CommerceCategory.artisans:      return Icons.palette;
      case CommerceCategory.services:      return Icons.build;
      case CommerceCategory.automotive:    return Icons.directions_car;
      case CommerceCategory.education:     return Icons.school;
      case CommerceCategory.technology:    return Icons.devices;
      case CommerceCategory.entertainment: return Icons.theater_comedy;
      case CommerceCategory.sports:        return Icons.sports_soccer;
      case CommerceCategory.tourism:       return Icons.flight;
      case CommerceCategory.pets:          return Icons.pets;
      case CommerceCategory.other:         return Icons.category;
    }
  }

  void _onCameraMove(MapCamera camera, bool hasGesture) {
    if (camera.zoom > 12) {
      context.read<MapBloc>().add(LoadNearbyCommerces(
        location: camera.center,
        radiusKm: AppConstants.nearbyRadiusKm * (20 - camera.zoom) / 10,
      ));
    }
  }

  void _centerOnLocation() {
    _mapController.move(_currentPosition, AppConstants.defaultZoom);
  }

  void _toggleMapStyle() {
    setState(() {
      _isMapDark = !_isMapDark;
      _isSatellite = false;
    });
  }

  void _toggleMapType() {
    setState(() => _isSatellite = !_isSatellite);
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: context.read<MapBloc>(),
        child: _FiltersSheet(location: _currentPosition),
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  final LatLng location;

  const _FiltersSheet({required this.location});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  CommerceCategory? _selected;

  static const _names = {
    CommerceCategory.restaurants: 'Restaurantes',
    CommerceCategory.cafes: 'Cafeterias',
    CommerceCategory.fastFood: 'Comida Rapida',
    CommerceCategory.bar: 'Bar / Pub',
    CommerceCategory.bakery: 'Panaderia',
    CommerceCategory.pharmacies: 'Farmacias',
    CommerceCategory.health: 'Salud',
    CommerceCategory.beauty: 'Belleza',
    CommerceCategory.clothing: 'Indumentaria',
    CommerceCategory.supermarket: 'Supermercados',
    CommerceCategory.hardware: 'Ferreteria',
    CommerceCategory.jewelry: 'Joyeria',
    CommerceCategory.market: 'Feria / Mercado',
    CommerceCategory.streetVendor: 'Vendedores Ambulantes',
    CommerceCategory.entrepreneur: 'Emprendimientos',
    CommerceCategory.artisans: 'Artesanos',
    CommerceCategory.services: 'Servicios',
    CommerceCategory.automotive: 'Automotriz',
    CommerceCategory.education: 'Educacion',
    CommerceCategory.technology: 'Tecnologia',
    CommerceCategory.entertainment: 'Entretenimiento',
    CommerceCategory.sports: 'Deportes',
    CommerceCategory.tourism: 'Turismo',
    CommerceCategory.pets: 'Mascotas',
    CommerceCategory.other: 'Otros',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filtros', style: AppTextStyles.headlineSmall.copyWith(color: Colors.white)),
              if (_selected != null)
                TextButton(
                  onPressed: _clearFilter,
                  child: Text(
                    'Limpiar',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('CategorÃ­as', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondaryDark)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CommerceCategory.values.map((cat) {
                  return FilterChip(
                    label: Text(_names[cat] ?? cat.name),
                    selected: _selected == cat,
                    onSelected: (_) => _applyFilter(context, cat),
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: AppTextStyles.bodySmall.copyWith(
                      color: _selected == cat ? AppColors.primary : Colors.white,
                    ),
                    backgroundColor: AppColors.backgroundSurface,
                    side: BorderSide(
                      color: _selected == cat ? AppColors.primary : const Color(0xFF1E293B),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilter(BuildContext context, CommerceCategory cat) {
    final next = _selected == cat ? null : cat;
    setState(() => _selected = next);
    context.read<MapBloc>().add(FilterByCategory(
      location: widget.location,
      category: next,
    ));
    Navigator.of(context).pop();
  }

  void _clearFilter() {
    setState(() => _selected = null);
    context.read<MapBloc>().add(FilterByCategory(
      location: widget.location,
      category: null,
    ));
    Navigator.of(context).pop();
  }
}
