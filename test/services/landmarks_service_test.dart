import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shinra_city/services/landmarks_service.dart';

/// Responde según el servidor consultado (todos se consultan a la vez).
class _FakeAdapter implements HttpClientAdapter {
  /// parte del host -> respuesta; los que no están, fallan con 504
  final Map<String, ResponseBody Function()> byHost;
  final List<String> urls = [];
  _FakeAdapter(this.byHost);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    urls.add(url);
    for (final entry in byHost.entries) {
      if (url.contains(entry.key)) return entry.value();
    }
    return _json({}, 504);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryStore implements LandmarksStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

LandmarksService _service(_FakeAdapter adapter, {LandmarksStore? store}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return LandmarksService(dio: dio, store: store, persist: false);
}

const _plazaDorrego = {
  'elements': [
    {'type': 'node', 'id': 1, 'lat': -34.6, 'lon': -58.38,
     'tags': {'place': 'square', 'name': 'Plaza Dorrego'}},
  ],
};

void main() {
  const center = LatLng(-34.6037, -58.3816);

  test('clasifica plazas, parques, monumentos, museos e iglesias', () async {
    final adapter = _FakeAdapter({
      'overpass-api.de': () => _json({
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
    });

    final result = await _service(adapter).nearby(center);
    final byName = {for (final l in result) l.name: l.type};

    expect(result, hasLength(5));
    expect(byName['Plaza de Mayo'], LandmarkType.plaza);
    expect(byName['Parque Lezama'], LandmarkType.park);
    expect(byName['Monumento a San Martín'], LandmarkType.monument);
    expect(byName['Museo del Cabildo'], LandmarkType.museum);
    expect(byName['Catedral'], LandmarkType.church);
  });

  test('consulta todos los servidores y usa el que responde bien', () async {
    final adapter = _FakeAdapter({
      // saturado: 200 con remark y sin datos
      'overpass-api.de': () => _json({'elements': [], 'remark': 'runtime error: timeout'}),
      'mail.ru': () => _json(_plazaDorrego),
    });

    final result = await _service(adapter).nearby(center);
    expect(result.single.name, 'Plaza Dorrego');
    expect(adapter.urls, hasLength(LandmarksService.endpoints.length));
  });

  test('misma zona: no vuelve a consultar', () async {
    final adapter = _FakeAdapter({'mail.ru': () => _json(_plazaDorrego)});
    final service = _service(adapter);

    await service.nearby(center);
    final calls = adapter.urls.length;
    final again = await service.nearby(const LatLng(-34.6039, -58.3814));
    expect(again.single.name, 'Plaza Dorrego');
    expect(adapter.urls, hasLength(calls));
  });

  test('si todos los servidores fallan, lanza error (el mapa sigue sin lugares)', () async {
    final adapter = _FakeAdapter({});
    expect(_service(adapter).nearby(center), throwsA(anything));
  });

  test('lo guardado en el celular sirve aunque los servidores estén caídos', () async {
    final store = _MemoryStore();
    await _service(_FakeAdapter({'mail.ru': () => _json(_plazaDorrego)}), store: store)
        .nearby(center);

    // otra sesión de la app, todos los servidores caídos
    final offline = _FakeAdapter({});
    final result = await _service(offline, store: store).nearby(center);
    expect(result.single.name, 'Plaza Dorrego');
    expect(offline.urls, isEmpty);
  });

  test('lo guardado hace más de 7 días se vuelve a descargar', () async {
    final store = _MemoryStore();
    await _service(_FakeAdapter({'mail.ru': () => _json(_plazaDorrego)}), store: store)
        .nearby(center);
    final key = store.data.keys.single;
    final old = jsonDecode(store.data[key]!) as Map<String, dynamic>;
    old['t'] = DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch;
    store.data[key] = jsonEncode(old);

    final adapter = _FakeAdapter({'mail.ru': () => _json(_plazaDorrego)});
    await _service(adapter, store: store).nearby(center);
    expect(adapter.urls, isNotEmpty);
  });
}
