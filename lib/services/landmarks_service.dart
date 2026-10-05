import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plazas, parques, monumentos, museos y otros lugares de interés cercanos,
/// tomados de OpenStreetMap con la API pública de Overpass (gratis, sin key).
enum LandmarkType { plaza, park, monument, museum, church, attraction, viewpoint }

extension LandmarkTypeX on LandmarkType {
  String get label {
    switch (this) {
      case LandmarkType.plaza: return 'Plaza';
      case LandmarkType.park: return 'Parque';
      case LandmarkType.monument: return 'Monumento';
      case LandmarkType.museum: return 'Museo';
      case LandmarkType.church: return 'Iglesia histórica';
      case LandmarkType.attraction: return 'Lugar de interés';
      case LandmarkType.viewpoint: return 'Mirador';
    }
  }

  IconData get icon {
    switch (this) {
      case LandmarkType.plaza: return Icons.deck;
      case LandmarkType.park: return Icons.park;
      case LandmarkType.monument: return Icons.account_balance;
      case LandmarkType.museum: return Icons.museum;
      case LandmarkType.church: return Icons.church;
      case LandmarkType.attraction: return Icons.star;
      case LandmarkType.viewpoint: return Icons.landscape;
    }
  }

  Color get color {
    switch (this) {
      case LandmarkType.plaza:
      case LandmarkType.park: return const Color(0xFF2E7D32);
      case LandmarkType.monument:
      case LandmarkType.church: return const Color(0xFF8D6E63);
      case LandmarkType.museum: return const Color(0xFF6A1B9A);
      case LandmarkType.attraction:
      case LandmarkType.viewpoint: return const Color(0xFF00838F);
    }
  }
}

class Landmark {
  final String id;
  final String name;
  final LandmarkType type;
  final LatLng location;
  final String? description;
  final String? wikipedia;

  const Landmark({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    this.description,
    this.wikipedia,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        't': type.name,
        'la': location.latitude,
        'lo': location.longitude,
        if (description != null) 'd': description,
        if (wikipedia != null) 'w': wikipedia,
      };

  factory Landmark.fromJson(Map<String, dynamic> j) => Landmark(
        id: j['id'] as String,
        name: j['n'] as String,
        type: LandmarkType.values.byName(j['t'] as String),
        location: LatLng((j['la'] as num).toDouble(), (j['lo'] as num).toDouble()),
        description: j['d'] as String?,
        wikipedia: j['w'] as String?,
      );
}

/// Dónde se guardan los lugares entre sesiones (por defecto SharedPreferences).
abstract class LandmarksStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPrefsLandmarksStore implements LandmarksStore {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class LandmarksService {
  // Servidores públicos de Overpass. Suelen estar saturados, así que se
  // consultan todos a la vez y gana el primero que responde bien.
  static const endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  // Las plazas y monumentos casi no cambian: lo descargado sirve una semana.
  static const cacheTtl = Duration(days: 7);

  final Dio _dio;
  final LandmarksStore? _store;

  LandmarksService({Dio? dio, LandmarksStore? store, bool persist = true})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 35),
              headers: {'User-Agent': 'ShinraCity/1.0 (com.shinracity.app)'},
            )),
        _store = store ?? (persist ? SharedPrefsLandmarksStore() : null);

  // Caché en memoria por zona (~1 km) para no repetir la consulta al mover el mapa.
  final Map<String, List<Landmark>> _cache = {};

  Future<List<Landmark>> nearby(LatLng center, {int radiusMeters = 2000}) async {
    final key = '${center.latitude.toStringAsFixed(2)},${center.longitude.toStringAsFixed(2)}';
    final cached = _cache[key] ?? await _readStored(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    // Recuadro alrededor del centro: Overpass lo resuelve mucho más rápido
    // que "around". 1° de latitud ≈ 111 km.
    final dLat = radiusMeters / 111000;
    final dLon = dLat / cos(center.latitude * pi / 180).abs().clamp(0.1, 1.0);
    final bbox = '${center.latitude - dLat},${center.longitude - dLon},'
        '${center.latitude + dLat},${center.longitude + dLon}';
    // Solo lugares con nombre; "out center" da un punto para plazas/parques
    // que en OSM son polígonos.
    final query = '''
[out:json][timeout:25][bbox:$bbox];
(
  nwr["place"="square"]["name"];
  nwr["leisure"="park"]["name"];
  nwr["historic"~"^(monument|memorial|statue|castle|ruins|fort|building)\$"]["name"];
  nwr["tourism"~"^(museum|attraction|viewpoint)\$"]["name"];
  nwr["amenity"="place_of_worship"]["historic"]["name"];
  nwr["building"="cathedral"]["name"];
);
out center 150;
''';

    final result = await _firstSuccessful(query);
    _cache[key] = result;
    await _writeStored(key, result);
    return result;
  }

  /// Consulta todos los servidores a la vez; devuelve la primera respuesta
  /// válida y solo falla si fallan todos.
  Future<List<Landmark>> _firstSuccessful(String query) {
    final done = Completer<List<Landmark>>();
    var failures = 0;
    Object? lastError;
    for (final url in endpoints) {
      _fetch(url, query).then((result) {
        if (!done.isCompleted) done.complete(result);
      }).catchError((Object e) {
        lastError = e;
        if (++failures == endpoints.length && !done.isCompleted) {
          done.completeError(lastError ?? Exception('No se pudieron cargar los lugares'));
        }
      });
    }
    return done.future;
  }

  Future<List<Landmark>> _fetch(String url, String query) async {
    final res = await _dio.post<Map<String, dynamic>>(
      url,
      data: {'data': query},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final elements = res.data?['elements'] as List? ?? const [];
    // saturado: a veces responde 200 con un "remark" de error y sin datos
    if (elements.isEmpty && res.data?['remark'] != null) {
      throw Exception('Overpass: ${res.data!['remark']}');
    }
    return _parse(elements);
  }

  Future<List<Landmark>?> _readStored(String key) async {
    try {
      final raw = await _store?.read('landmarks_v1_$key');
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(json['t'] as int);
      if (DateTime.now().difference(savedAt) > cacheTtl) return null;
      return (json['items'] as List)
          .map((e) => Landmark.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null; // caché corrupta: se vuelve a descargar
    }
  }

  Future<void> _writeStored(String key, List<Landmark> items) async {
    try {
      await _store?.write(
        'landmarks_v1_$key',
        jsonEncode({
          't': DateTime.now().millisecondsSinceEpoch,
          'items': items.map((l) => l.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  List<Landmark> _parse(List elements) {
    final seen = <String>{};
    final out = <Landmark>[];
    for (final raw in elements) {
      final e = raw as Map<String, dynamic>;
      final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final name = (tags['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;

      final lat = (e['lat'] ?? (e['center'] as Map?)?['lat']) as num?;
      final lon = (e['lon'] ?? (e['center'] as Map?)?['lon']) as num?;
      if (lat == null || lon == null) continue;

      final type = _typeFor(tags);
      if (type == null) continue;
      // el mismo lugar suele venir como nodo y como polígono
      if (!seen.add('${type.name}:$name')) continue;

      out.add(Landmark(
        id: '${e['type']}/${e['id']}',
        name: name,
        type: type,
        location: LatLng(lat.toDouble(), lon.toDouble()),
        description: tags['description'] as String?,
        wikipedia: tags['wikipedia'] as String?,
      ));
    }
    return out;
  }

  static LandmarkType? _typeFor(Map<String, dynamic> t) {
    if (t['place'] == 'square') return LandmarkType.plaza;
    final name = (t['name'] as String? ?? '').toLowerCase();
    if (t['leisure'] == 'park') {
      return name.startsWith('plaza') ? LandmarkType.plaza : LandmarkType.park;
    }
    if (t['tourism'] == 'museum') return LandmarkType.museum;
    if (t['amenity'] == 'place_of_worship' || t['building'] == 'cathedral') {
      return LandmarkType.church;
    }
    if (t['historic'] != null) return LandmarkType.monument;
    if (t['tourism'] == 'viewpoint') return LandmarkType.viewpoint;
    if (t['tourism'] == 'attraction') {
      return LandmarkType.attraction;
    }
    return null;
  }
}
