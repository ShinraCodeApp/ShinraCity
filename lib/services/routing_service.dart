import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Rutas a pie o en auto dentro de la app, con el servidor OSRM gratuito de
/// FOSSGIS (routing.openstreetmap.de, el mismo que usa openstreetmap.org).
/// No pide clave.
enum RouteMode { walk, car }

extension RouteModeX on RouteMode {
  String get label => this == RouteMode.walk ? 'A pie' : 'En auto';
  String get _profile => this == RouteMode.walk ? 'routed-foot' : 'routed-car';
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final LatLng location;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.location,
  });
}

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });
}

class RoutingService {
  final Dio _dio;

  RoutingService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://routing.openstreetmap.de',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': 'ShinraCity/1.0 (com.shinracity.app)'},
            ));

  Future<RouteResult> route(LatLng from, LatLng to, RouteMode mode) async {
    final coords = '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final res = await _dio.get<Map<String, dynamic>>(
      '/${mode._profile}/route/v1/driving/$coords',
      queryParameters: {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'},
    );
    final data = res.data ?? const {};
    final routes = data['routes'] as List?;
    if (data['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw Exception('No se encontró una ruta');
    }
    final r = routes.first as Map<String, dynamic>;
    final coordsList = (r['geometry'] as Map)['coordinates'] as List;
    final legs = r['legs'] as List;
    final rawSteps = legs.isEmpty ? const [] : (legs.first as Map)['steps'] as List;

    return RouteResult(
      points: coordsList
          .map((c) => LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList(),
      distanceMeters: (r['distance'] as num).toDouble(),
      durationSeconds: (r['duration'] as num).toDouble(),
      steps: rawSteps.map((s) {
        final step = s as Map<String, dynamic>;
        final m = step['maneuver'] as Map<String, dynamic>;
        final loc = m['location'] as List;
        return RouteStep(
          instruction: instructionFor(
            type: m['type'] as String? ?? '',
            modifier: m['modifier'] as String?,
            street: step['name'] as String? ?? '',
          ),
          distanceMeters: (step['distance'] as num).toDouble(),
          location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
        );
      }).toList(),
    );
  }

  /// Indicación en castellano rioplatense a partir de una maniobra de OSRM.
  static String instructionFor({
    required String type,
    String? modifier,
    required String street,
  }) {
    final by = street.isEmpty ? '' : ' por $street';
    final dir = switch (modifier) {
      'left' => 'Doblá a la izquierda',
      'right' => 'Doblá a la derecha',
      'slight left' => 'Mantenete a la izquierda',
      'slight right' => 'Mantenete a la derecha',
      'sharp left' => 'Doblá bien a la izquierda',
      'sharp right' => 'Doblá bien a la derecha',
      'uturn' => 'Pegá la vuelta',
      _ => 'Seguí derecho',
    };
    switch (type) {
      case 'depart':
        return street.isEmpty ? 'Salí' : 'Salí por $street';
      case 'arrive':
        return 'Llegaste a destino';
      case 'roundabout':
      case 'rotary':
        return 'Entrá a la rotonda$by';
      case 'new name':
      case 'continue':
        return street.isEmpty ? 'Seguí derecho' : 'Seguí por $street';
      default: // turn, end of road, fork, merge, on/off ramp
        return '$dir$by';
    }
  }
}

String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

String formatDuration(double seconds) {
  final min = (seconds / 60).round();
  if (min < 1) return 'menos de 1 min';
  if (min < 60) return '$min min';
  return '${min ~/ 60} h ${min % 60} min';
}
