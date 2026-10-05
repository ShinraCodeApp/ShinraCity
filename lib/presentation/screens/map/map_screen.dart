import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../domain/entities/promotion_entity.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/analytics_service.dart';
import '../../../services/landmarks_service.dart';
import '../../../services/routing_service.dart';
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
  Timer? _cameraDebounce;
  DateTime? _lastNearbyNotification;

  // Plazas, monumentos, museos, etc. (OpenStreetMap)
  final LandmarksService _landmarksService = LandmarksService();
  List<Landmark> _landmarks = [];
  bool _showLandmarks = true;
  LatLng? _lastLandmarksCenter;
  Timer? _landmarksRetry;
  int _landmarksRetries = 0;

  // "Cómo llegar" dentro del mapa (ruta de OpenStreetMap)
  final RoutingService _routing = RoutingService();
  LatLng? _routeTarget;
  String? _routeTargetName;
  RouteResult? _route;
  RouteMode _routeMode = RouteMode.walk;
  bool _routeLoading = false;
  bool _routeFailed = false;
  bool _showRouteSteps = false;
  LatLng? _routeFrom; // desde dónde se calculó (para recalcular si te desviás)

  // CARTO's free anonymous basemap tiles now require an API key, so dark
  // mode is faked with a color-inversion filter over plain OSM tiles —
  // no external key or paid service needed.
  static const _darkMapFilter = ColorFilter.matrix(<double>[
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  String get _tileUrl {
    if (_isSatellite) {
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

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
    _cameraDebounce?.cancel();
    _landmarksRetry?.cancel();
    _pulseController.dispose();
    _locationStream?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        context.read<MapBloc>().add(LoadNearbyCommerces(location: _currentPosition));
        _loadLandmarks(_currentPosition);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Activá la ubicación en Ajustes para ver comercios cerca tuyo'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Ajustes',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return;
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
      _loadLandmarks(_currentPosition);

      _locationStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).listen(_onLocationUpdate);
    } catch (e) {
      if (mounted) {
        context.read<MapBloc>().add(LoadNearbyCommerces(location: _currentPosition));
        _loadLandmarks(_currentPosition);
      }
    }
  }

  void _onLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);
    setState(() => _currentPosition = newLocation);
    _followRoute(newLocation);
    context.read<MapBloc>().add(UpdateUserLocation(location: newLocation));
    _triggerNearbyNotification(newLocation);
    GetIt.instance<AnalyticsService>()
        .logMapOpen(lat: position.latitude, lon: position.longitude);
  }

  void _triggerNearbyNotification(LatLng location) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final now = DateTime.now();
    if (_lastNearbyNotification != null &&
        now.difference(_lastNearbyNotification!).inMinutes <
            AppConstants.geofenceNotificationCooldownMinutes) return;
    _lastNearbyNotification = now;
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
          if (_routeTarget != null) _buildRoutePanel(),
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
        if (state is MapError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Reintentar',
                textColor: Colors.white,
                onPressed: () => context.read<MapBloc>().add(
                      LoadNearbyCommerces(location: _currentPosition),
                    ),
              ),
            ),
          );
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
          if (_isMapDark && !_isSatellite)
            ColorFiltered(
              colorFilter: _darkMapFilter,
              child: TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.shinracity.app',
              ),
            )
          else
            TileLayer(
              urlTemplate: _tileUrl,
              userAgentPackageName: 'com.shinracity.app',
            ),
          CircleLayer(circles: _circles),
          if (_route != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _route!.points,
                  strokeWidth: 6,
                  color: AppColors.primary,
                  borderStrokeWidth: 2,
                  borderColor: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          if (_routeTarget != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _routeTarget!,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_on, color: AppColors.primary, size: 40),
                ),
              ],
            ),
          // debajo de los comercios, para que no tapen sus marcadores
          if (_showLandmarks) MarkerLayer(markers: _buildLandmarkMarkers()),
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
                        color: Colors.blue.withValues(alpha: 0.4),
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
      bottom: _routeTarget != null
          ? (_showRouteSteps ? 440 : 230)
          : (_showNearbyPanel ? 300 : 100),
      child: Column(
        children: [
          _buildControlButton(
            icon: Icons.my_location,
            onTap: _centerOnLocation,
            tooltip: 'Mi ubicación',
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
            tooltip: _isSatellite ? 'Vista mapa' : 'Vista satélite',
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.account_balance_outlined,
            onTap: _toggleLandmarks,
            tooltip: _showLandmarks ? 'Ocultar lugares de interés' : 'Ver plazas y monumentos',
            isActive: _showLandmarks,
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
                color: Colors.black.withValues(alpha: 0.3),
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
        onDirections: _startRoute,
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
      case CommerceCategory.iceCream:      return const Color(0xFFF06292);
      case CommerceCategory.butcher:       return const Color(0xFFC62828);
      case CommerceCategory.greengrocer:   return const Color(0xFF7CB342);
      case CommerceCategory.kiosk:         return const Color(0xFFFBC02D);
      case CommerceCategory.pharmacies:    return const Color(0xFF43A047);
      case CommerceCategory.health:        return const Color(0xFFEF5350);
      case CommerceCategory.beauty:        return const Color(0xFFE91E63);
      case CommerceCategory.veterinary:    return const Color(0xFF26A69A);
      case CommerceCategory.opticians:     return const Color(0xFF5C6BC0);
      case CommerceCategory.gym:           return const Color(0xFFEF6C00);
      case CommerceCategory.clothing:      return const Color(0xFF9C27B0);
      case CommerceCategory.supermarket:   return const Color(0xFF388E3C);
      case CommerceCategory.hardware:      return const Color(0xFF78909C);
      case CommerceCategory.jewelry:       return const Color(0xFFFFD600);
      case CommerceCategory.market:        return const Color(0xFF66BB6A);
      case CommerceCategory.furniture:     return const Color(0xFF795548);
      case CommerceCategory.electronics:   return const Color(0xFF3949AB);
      case CommerceCategory.bookstore:     return const Color(0xFF6D4C41);
      case CommerceCategory.toyStore:      return const Color(0xFFFFA726);
      case CommerceCategory.babyStore:     return const Color(0xFF4FC3F7);
      case CommerceCategory.florist:       return const Color(0xFFEC407A);
      case CommerceCategory.constructionMaterials: return const Color(0xFFA1887F);
      case CommerceCategory.automotive:    return const Color(0xFFFF5722);
      case CommerceCategory.autoPartsRepair: return const Color(0xFFBF360C);
      case CommerceCategory.tireShop:      return const Color(0xFF424242);
      case CommerceCategory.carWash:       return const Color(0xFF03A9F4);
      case CommerceCategory.bikeShop:      return const Color(0xFF8BC34A);
      case CommerceCategory.streetVendor:  return const Color(0xFFFF9800);
      case CommerceCategory.entrepreneur:  return const Color(0xFF00E5FF);
      case CommerceCategory.artisans:      return const Color(0xFFD4A853);
      case CommerceCategory.services:      return const Color(0xFF607D8B);
      case CommerceCategory.laundry:       return const Color(0xFF81D4FA);
      case CommerceCategory.realEstate:    return const Color(0xFF00695C);
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
      final isAmbulant = commerce.isAmbulant;
      final size = hasPromo ? 50.0 : (isAmbulant ? 44.0 : 38.0);

      // Ambulant vendors walk around, so customers see them move in real time.
      // Fixed businesses always stay at the location the owner set.
      final markerPoint = (isAmbulant && commerce.liveLocation != null)
          ? commerce.liveLocation!
          : commerce.location;

      newMarkers.add(Marker(
        point: markerPoint,
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
              // Ambulant: always-pulsing outer ring
              if (isAmbulant)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: size + 14 + (_pulseController.value * 10),
                    height: size + 14 + (_pulseController.value * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF9800)
                            .withValues(alpha: (1 - _pulseController.value) * 0.75),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              // Fixed business with active promo: golden glow ring
              if (hasPromo && !isAmbulant)
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              // AMBULANT: diamond (rotated square) background
              if (isAmbulant)
                Transform.rotate(
                  angle: pi / 4,
                  child: Container(
                    width: size - 10,
                    height: size - 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: isOpen ? 0.8 : 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              // FIXED BUSINESS: circle with category color
              if (!isAmbulant)
                Container(
                  width: size - (hasPromo ? 8 : 0),
                  height: size - (hasPromo ? 8 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor.withValues(alpha: opacity),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isOpen ? 0.65 : 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              // Icon — always upright regardless of shape rotation
              Icon(
                isAmbulant
                    ? Icons.directions_walk
                    : (hasPromo
                        ? Icons.local_offer
                        : _getCategoryIcon(commerce.category)),
                color: Colors.white.withValues(alpha: isOpen ? 0.92 : 0.5),
                size: isAmbulant ? 15 : 14,
              ),
            ],
          ),
        ),
      ));

      if (hasPromo) {
        newCircles.add(CircleMarker(
          point: markerPoint,
          radius: AppConstants.geofenceRadiusMeters,
          useRadiusInMeter: true,
          color: baseColor.withValues(alpha: 0.08),
          borderColor: baseColor.withValues(alpha: 0.4),
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
      case CommerceCategory.iceCream:      return Icons.icecream;
      case CommerceCategory.butcher:       return Icons.kebab_dining;
      case CommerceCategory.greengrocer:   return Icons.eco;
      case CommerceCategory.kiosk:         return Icons.store;
      case CommerceCategory.pharmacies:    return Icons.local_pharmacy;
      case CommerceCategory.health:        return Icons.health_and_safety;
      case CommerceCategory.beauty:        return Icons.face_retouching_natural;
      case CommerceCategory.veterinary:    return Icons.medical_services;
      case CommerceCategory.opticians:     return Icons.visibility;
      case CommerceCategory.gym:           return Icons.fitness_center;
      case CommerceCategory.clothing:      return Icons.checkroom;
      case CommerceCategory.supermarket:   return Icons.shopping_cart;
      case CommerceCategory.hardware:      return Icons.construction;
      case CommerceCategory.jewelry:       return Icons.diamond;
      case CommerceCategory.market:        return Icons.storefront;
      case CommerceCategory.furniture:     return Icons.chair;
      case CommerceCategory.electronics:   return Icons.kitchen;
      case CommerceCategory.bookstore:     return Icons.menu_book;
      case CommerceCategory.toyStore:      return Icons.toys;
      case CommerceCategory.babyStore:     return Icons.child_friendly;
      case CommerceCategory.florist:       return Icons.local_florist;
      case CommerceCategory.constructionMaterials: return Icons.foundation;
      case CommerceCategory.automotive:    return Icons.directions_car;
      case CommerceCategory.autoPartsRepair: return Icons.car_repair;
      case CommerceCategory.tireShop:      return Icons.album;
      case CommerceCategory.carWash:       return Icons.local_car_wash;
      case CommerceCategory.bikeShop:      return Icons.pedal_bike;
      case CommerceCategory.streetVendor:  return Icons.shopping_bag;
      case CommerceCategory.entrepreneur:  return Icons.rocket_launch;
      case CommerceCategory.artisans:      return Icons.palette;
      case CommerceCategory.services:      return Icons.build;
      case CommerceCategory.laundry:       return Icons.local_laundry_service;
      case CommerceCategory.realEstate:    return Icons.home_work;
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
      _cameraDebounce?.cancel();
      _cameraDebounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        context.read<MapBloc>().add(LoadNearbyCommerces(
          location: camera.center,
          radiusKm: AppConstants.nearbyRadiusKm * (20 - camera.zoom) / 10,
        ));
        if (camera.zoom >= 13) _loadLandmarks(camera.center);
      });
    }
  }

  // ─── Lugares de interés ───────────────────────────────────────────────────

  Future<void> _loadLandmarks(LatLng center) async {
    if (!_showLandmarks) return;
    // no repetir la consulta si el mapa se movió poco
    final last = _lastLandmarksCenter;
    if (last != null && const Distance().as(LengthUnit.Meter, last, center) < 800) return;
    _lastLandmarksCenter = center;
    try {
      final found = await _landmarksService.nearby(center);
      if (!mounted) return;
      setState(() {
        final byId = {for (final l in _landmarks) l.id: l};
        for (final l in found) {
          byId[l.id] = l;
        }
        _landmarks = byId.values.toList();
      });
      _landmarksRetries = 0;
    } catch (_) {
      // sin internet o todos los servidores saturados: el mapa sigue andando
      // sin lugares y se reintenta solo un par de veces
      _lastLandmarksCenter = null;
      if (_landmarksRetries < 3 && mounted) {
        _landmarksRetries++;
        _landmarksRetry?.cancel();
        _landmarksRetry = Timer(const Duration(seconds: 20), () {
          if (mounted) _loadLandmarks(_mapController.camera.center);
        });
      }
    }
  }

  // ─── Ruta dentro del mapa ─────────────────────────────────────────────────

  void _startRoute(LatLng target, String name) {
    setState(() {
      _routeTarget = target;
      _routeTargetName = name;
      _route = null;
      _showRouteSteps = false;
      _selectedCommerceId = null;
      _showNearbyPanel = false;
    });
    _calculateRoute(fitCamera: true);
  }

  Future<void> _calculateRoute({bool fitCamera = false}) async {
    final target = _routeTarget;
    if (target == null) return;
    final from = _currentPosition;
    setState(() {
      _routeLoading = true;
      _routeFailed = false;
    });
    try {
      final route = await _routing.route(from, target, _routeMode);
      if (!mounted || _routeTarget != target) return;
      setState(() {
        _route = route;
        _routeFrom = from;
        _routeLoading = false;
      });
      if (fitCamera && route.points.length > 1) {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([...route.points, from]),
          padding: const EdgeInsets.fromLTRB(40, 200, 90, 300),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _routeFailed = true;
      });
    }
  }

  void _setRouteMode(RouteMode mode) {
    if (mode == _routeMode) return;
    setState(() => _routeMode = mode);
    _calculateRoute(fitCamera: true);
  }

  void _endRoute() {
    setState(() {
      _routeTarget = null;
      _routeTargetName = null;
      _route = null;
      _routeFrom = null;
      _routeFailed = false;
      _showRouteSteps = false;
    });
  }

  /// Con la ruta activa: avisa al llegar y recalcula si te desviaste.
  void _followRoute(LatLng position) {
    final target = _routeTarget;
    if (target == null) return;
    const d = Distance();
    if (d.as(LengthUnit.Meter, position, target) < 25) {
      final name = _routeTargetName ?? 'destino';
      _endRoute();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('¡Llegaste a $name!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ));
      return;
    }
    final from = _routeFrom;
    if (!_routeLoading && from != null && d.as(LengthUnit.Meter, position, from) > 60) {
      _calculateRoute();
    }
  }

  Widget _buildRoutePanel() {
    final route = _route;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _routeTargetName ?? 'Destino',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Terminar ruta',
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: _endRoute,
                ),
              ],
            ),
            Row(
              children: [
                for (final mode in RouteMode.values) ...[
                  ChoiceChip(
                    label: Text(mode.label),
                    avatar: Icon(
                      mode == RouteMode.walk ? Icons.directions_walk : Icons.directions_car,
                      size: 18,
                      color: _routeMode == mode ? AppColors.backgroundDark : Colors.white70,
                    ),
                    selected: _routeMode == mode,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.backgroundDark,
                    labelStyle: TextStyle(
                      color: _routeMode == mode ? AppColors.backgroundDark : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => _setRouteMode(mode),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (_routeLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (route != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDuration(route.durationSeconds),
                        style: AppTextStyles.titleMedium
                            .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        formatDistance(route.distanceMeters),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondaryDark),
                      ),
                    ],
                  ),
              ],
            ),
            if (_routeFailed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'No se pudo calcular la ruta.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                    ),
                  ),
                  TextButton(onPressed: _calculateRoute, child: const Text('Reintentar')),
                  TextButton(
                    onPressed: () => _openInGoogleMaps(_routeTarget!),
                    child: const Text('Google Maps'),
                  ),
                ],
              ),
            ],
            if (route != null && route.steps.isNotEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setState(() => _showRouteSteps = !_showRouteSteps),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.turn_right, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          // la primera indicación que no sea "Salí"
                          route.steps.length > 1
                              ? route.steps[1].instruction
                              : route.steps.first.instruction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                        ),
                      ),
                      Text(
                        _showRouteSteps ? 'Ocultar' : 'Ver pasos',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showRouteSteps)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: route.steps.length,
                    itemBuilder: (_, i) {
                      final s = route.steps[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          child: Text('${i + 1}',
                              style: const TextStyle(color: AppColors.primary, fontSize: 11)),
                        ),
                        title: Text(s.instruction,
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                        trailing: s.distanceMeters > 0
                            ? Text(formatDistance(s.distanceMeters),
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondaryDark))
                            : null,
                        onTap: () => _mapController.move(s.location, 18),
                      );
                    },
                  ),
                ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Rutas: © colaboradores de OpenStreetMap',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondaryDark, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInGoogleMaps(LatLng target) {
    launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1'
          '&destination=${target.latitude},${target.longitude}'
          '&travelmode=${_routeMode == RouteMode.walk ? 'walking' : 'driving'}'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _toggleLandmarks() {
    setState(() => _showLandmarks = !_showLandmarks);
    if (_showLandmarks) {
      _lastLandmarksCenter = null;
      _loadLandmarks(_mapController.camera.center);
    }
  }

  List<Marker> _buildLandmarkMarkers() {
    return _landmarks.map((l) {
      return Marker(
        point: l.location,
        width: 30,
        height: 30,
        child: GestureDetector(
          onTap: () => _showLandmarkSheet(l),
          child: Container(
            decoration: BoxDecoration(
              color: l.type.color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
              ],
            ),
            child: Icon(l.type.icon, color: Colors.white, size: 16),
          ),
        ),
      );
    }).toList();
  }

  void _showLandmarkSheet(Landmark l) {
    final distance = const Distance().as(LengthUnit.Meter, _currentPosition, l.location);
    final distanceText = distance < 1000
        ? '${distance.round()} m'
        : '${(distance / 1000).toStringAsFixed(1)} km';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: l.type.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(l.type.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.name,
                          style: AppTextStyles.titleMedium
                              .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${l.type.label} · a $distanceText',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (l.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  l.description!,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.directions),
                  label: const Text('Cómo llegar'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _startRoute(l.location, l.name);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Datos: © colaboradores de OpenStreetMap',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondaryDark, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    CommerceCategory.iceCream: 'Heladeria',
    CommerceCategory.butcher: 'Carniceria',
    CommerceCategory.greengrocer: 'Verduleria',
    CommerceCategory.kiosk: 'Kiosco',
    CommerceCategory.pharmacies: 'Farmacias',
    CommerceCategory.health: 'Salud',
    CommerceCategory.beauty: 'Belleza',
    CommerceCategory.veterinary: 'Veterinaria',
    CommerceCategory.opticians: 'Optica',
    CommerceCategory.gym: 'Gimnasio',
    CommerceCategory.clothing: 'Indumentaria',
    CommerceCategory.supermarket: 'Supermercados',
    CommerceCategory.hardware: 'Ferreteria',
    CommerceCategory.jewelry: 'Joyeria',
    CommerceCategory.market: 'Feria / Mercado',
    CommerceCategory.furniture: 'Muebleria / Hogar',
    CommerceCategory.electronics: 'Electrodomesticos',
    CommerceCategory.bookstore: 'Libreria',
    CommerceCategory.toyStore: 'Jugueteria',
    CommerceCategory.babyStore: 'Bebes y Maternidad',
    CommerceCategory.florist: 'Floreria',
    CommerceCategory.constructionMaterials: 'Materiales de Construccion',
    CommerceCategory.automotive: 'Automotriz',
    CommerceCategory.autoPartsRepair: 'Repuestos Auto/Moto',
    CommerceCategory.tireShop: 'Gomeria',
    CommerceCategory.carWash: 'Lavadero',
    CommerceCategory.bikeShop: 'Bicicleteria',
    CommerceCategory.streetVendor: 'Vendedores Ambulantes',
    CommerceCategory.entrepreneur: 'Emprendimientos',
    CommerceCategory.artisans: 'Artesanos',
    CommerceCategory.services: 'Servicios',
    CommerceCategory.laundry: 'Lavanderia / Tintoreria',
    CommerceCategory.realEstate: 'Inmobiliaria',
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
          Text('Categorías', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondaryDark)),
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
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
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
