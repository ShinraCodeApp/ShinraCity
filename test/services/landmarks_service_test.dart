import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shinra_city/services/landmarks_service.dart';

/// Responde las requests con una lista de respuestas armadas a mano.
class _FakeAdapter implements HttpClientAdapter {
  final List<ResponseBody Function()> responses;
  final List<String> urls = [];
  _FakeAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri.toString());
    return responses.removeAt(0)();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

LandmarksService _service(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return LandmarksService(dio: dio);
}

void main() {
  const center = LatLng(-34.6037, -58.3816);

  test('clasifica plazas, parques, monumentos, museos e iglesias', () async {
    final adapter = _FakeAdapter([
      () => _json({
            'elements': [
              {'type': 'way', 'id': 1, 'center': {'lat': -34.60, 'lon': -58.38},
               'tags': {'leisure': 'park', 'name': 'Plaza de Mayo'}},
              {'type': 'way', 'id': 2, 'center': {'lat': -34.61, 'lon': -58.39},
               'tags': {'leisure': 'park', 'name': 'Parque Lezama'}},
              {'type': 'node', 'id': 3, 'lat': -34.60, 'lon': -58.37,
               'tags': {'historic': 'monument', 'name': 'Monumento a San Martín'}},
              {'type': 'node', 'id': 4, 'lat': -34.60, 'lon': -58.37,
               'tags': {'tourism': 'museum', 'name': 'Museo del Cabildo'}},
              {'type': 'way', 'id': 5, 'center': {'lat': -34.60, 'lon': -58.37},
               'tags': {'amenity': 'place_of_worship', 'historic': 'yes', 'name': 'Catedral'}},
              // sin nombre: se descarta
              {'type': 'node', 'id': 6, 'lat': -34.60, 'lon': -58.37,
               'tags': {'historic': 'memorial'}},
              // duplicado nodo/polígono del mismo lugar
              {'type': 'node', 'id': 7, 'lat': -34.60, 'lon': -58.38,
               'tags': {'leisure': 'park', 'name': 'Plaza de Mayo'}},
            ],
          }),
    ]);

    final result = await _service(adapter).nearby(center);
    final byName = {for (final l in result) l.name: l.type};

    expect(result, hasLength(5));
    expect(byName['Plaza de Mayo'], LandmarkType.plaza);
    expect(byName['Parque Lezama'], LandmarkType.park);
    expect(byName['Monumento a San Martín'], LandmarkType.monument);
    expect(byName['Museo del Cabildo'], LandmarkType.museum);
    expect(byName['Catedral'], LandmarkType.church);
  });

  test('si el primer servidor falla usa el segundo, y guarda en caché', () async {
    final adapter = _FakeAdapter([
      () => _json({'elements': [], 'remark': 'runtime error: timeout'}),
      () => _json({
            'elements': [
              {'type': 'node', 'id': 1, 'lat': -34.6, 'lon': -58.38,
               'tags': {'place': 'square', 'name': 'Plaza Dorrego'}},
            ],
          }),
    ]);
    final service = _service(adapter);

    final first = await service.nearby(center);
    expect(first.single.name, 'Plaza Dorrego');
    expect(adapter.urls, hasLength(2));
    expect(adapter.urls[1], contains('kumi'));

    // misma zona: no vuelve a consultar
    final again = await service.nearby(const LatLng(-34.6039, -58.3814));
    expect(again.single.name, 'Plaza Dorrego');
    expect(adapter.urls, hasLength(2));
  });

  test('si todos los servidores fallan, lanza error (el mapa sigue sin lugares)', () async {
    final adapter = _FakeAdapter([
      () => _json({}, 504),
      () => _json({}, 504),
    ]);
    expect(_service(adapter).nearby(center), throwsA(anything));
  });
}
