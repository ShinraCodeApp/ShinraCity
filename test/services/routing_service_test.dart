import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shinra_city/services/routing_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Object body;
  String? lastUrl;
  _FakeAdapter(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastUrl = options.uri.toString();
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

RoutingService _service(_FakeAdapter a) =>
    RoutingService(dio: Dio(BaseOptions(baseUrl: 'https://routing.test'))..httpClientAdapter = a);

// Respuesta real (recortada) de routed-foot en San Rafael
const _osrm = {
  'code': 'Ok',
  'routes': [
    {
      'distance': 871.2,
      'duration': 702.0,
      'geometry': {
        'coordinates': [[-68.3315, -34.6145], [-68.3320, -34.6150], [-68.3380, -34.6170]],
      },
      'legs': [
        {
          'steps': [
            {'name': 'Chile', 'distance': 42.0,
             'maneuver': {'type': 'depart', 'modifier': 'left', 'location': [-68.3315, -34.6145]}},
            {'name': 'Comandante Salas', 'distance': 122.0,
             'maneuver': {'type': 'turn', 'modifier': 'left', 'location': [-68.3320, -34.6150]}},
            {'name': '', 'distance': 0.0,
             'maneuver': {'type': 'arrive', 'location': [-68.3380, -34.6170]}},
          ],
        },
      ],
    },
  ],
};

void main() {
  const from = LatLng(-34.6145, -68.3315);
  const to = LatLng(-34.6170, -68.3380);

  test('lee la ruta: puntos (lat/lon invertidos en OSRM), distancia, tiempo y pasos', () async {
    final adapter = _FakeAdapter(_osrm);
    final r = await _service(adapter).route(from, to, RouteMode.walk);

    expect(adapter.lastUrl, contains('/routed-foot/route/v1/driving/-68.3315,-34.6145;-68.338,-34.617'));
    expect(r.points.first, const LatLng(-34.6145, -68.3315));
    expect(r.points, hasLength(3));
    expect(r.distanceMeters, 871.2);
    expect(r.steps.map((s) => s.instruction), [
      'Salí por Chile',
      'Doblá a la izquierda por Comandante Salas',
      'Llegaste a destino',
    ]);
  });

  test('en auto usa el perfil de auto', () async {
    final adapter = _FakeAdapter(_osrm);
    await _service(adapter).route(from, to, RouteMode.car);
    expect(adapter.lastUrl, contains('/routed-car/'));
  });

  test('sin ruta posible lanza error', () async {
    final adapter = _FakeAdapter({'code': 'NoRoute', 'routes': []});
    expect(_service(adapter).route(from, to, RouteMode.walk), throwsA(anything));
  });

  test('indicaciones en castellano', () {
    String i(String t, [String? m, String s = 'Mitre']) =>
        RoutingService.instructionFor(type: t, modifier: m, street: s);
    expect(i('turn', 'right'), 'Doblá a la derecha por Mitre');
    expect(i('turn', 'slight left'), 'Mantenete a la izquierda por Mitre');
    expect(i('new name', 'straight'), 'Seguí por Mitre');
    expect(i('roundabout', 'right'), 'Entrá a la rotonda por Mitre');
    expect(i('turn', 'uturn', ''), 'Pegá la vuelta');
  });

  test('formatos de distancia y tiempo', () {
    expect(formatDistance(871.2), '871 m');
    expect(formatDistance(2450), '2.5 km');
    expect(formatDuration(702), '12 min');
    expect(formatDuration(20), 'menos de 1 min');
    expect(formatDuration(4000), '1 h 7 min');
  });
}
