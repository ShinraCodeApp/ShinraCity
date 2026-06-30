import 'dart:math';
import 'package:latlong2/latlong.dart';

class GeoUtils {
  GeoUtils._();

  static const double _earthRadius = 6371.0;

  static double calculateDistance(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final deltaLat = _toRadians(to.latitude - from.latitude);
    final deltaLon = _toRadians(to.longitude - from.longitude);

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadius * c;
  }

  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  static String encodeGeohash(double latitude, double longitude, int precision) {
    const base32Chars = '0123456789bcdefghjkmnpqrstuvwxyz';
    var minLat = -90.0;
    var maxLat = 90.0;
    var minLon = -180.0;
    var maxLon = 180.0;

    var hash = StringBuffer();
    var bits = 0;
    var hashValue = 0;
    var isEven = true;

    while (hash.length < precision) {
      double mid;
      if (isEven) {
        mid = (minLon + maxLon) / 2;
        if (longitude > mid) {
          hashValue = (hashValue << 1) + 1;
          minLon = mid;
        } else {
          hashValue = hashValue << 1;
          maxLon = mid;
        }
      } else {
        mid = (minLat + maxLat) / 2;
        if (latitude > mid) {
          hashValue = (hashValue << 1) + 1;
          minLat = mid;
        } else {
          hashValue = hashValue << 1;
          maxLat = mid;
        }
      }

      isEven = !isEven;
      bits++;

      if (bits == 5) {
        hash.write(base32Chars[hashValue]);
        bits = 0;
        hashValue = 0;
      }
    }

    return hash.toString();
  }

  static List<String> getNeighborGeohashes(String geohash) {
    return [geohash];
  }

  static bool isWithinRadius(LatLng center, LatLng point, double radiusKm) {
    return calculateDistance(center, point) <= radiusKm;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
