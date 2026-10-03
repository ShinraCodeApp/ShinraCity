import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum AmbulantLocationStatus { stopped, denied, deniedForever, active }

/// Broadcasts the live location of an ambulant vendor to Firestore.
/// Start it when the vendor opens the app; it stops automatically on dispose.
class AmbulantLocationService {
  AmbulantLocationService._();
  static final AmbulantLocationService instance = AmbulantLocationService._();

  StreamSubscription<Position>? _sub;
  String? _commerceId;

  final ValueNotifier<AmbulantLocationStatus> status =
      ValueNotifier(AmbulantLocationStatus.stopped);
  final ValueNotifier<DateTime?> lastUpdatedAt = ValueNotifier(null);

  bool get isRunning => _sub != null;

  Future<void> start(String commerceId) async {
    if (_sub != null && _commerceId == commerceId) return;
    if (_sub != null) stop();
    _commerceId = commerceId;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      status.value = AmbulantLocationStatus.denied;
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      status.value = AmbulantLocationStatus.deniedForever;
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      status.value = AmbulantLocationStatus.denied;
      return;
    }

    status.value = AmbulantLocationStatus.active;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen(_onPosition, onError: (_) => stop());
  }

  /// Re-attempts start(), useful for a manual "Activar ubicación" retry button.
  Future<void> retry() async {
    final commerceId = _commerceId;
    if (commerceId == null) return;
    _commerceId = null;
    await start(commerceId);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    if (_commerceId != null) {
      FirebaseFirestore.instance
          .collection('commerces')
          .doc(_commerceId)
          .update({'liveLocation': FieldValue.delete(), 'liveLocationUpdatedAt': FieldValue.delete()})
          .catchError((_) {});
    }
    _commerceId = null;
    status.value = AmbulantLocationStatus.stopped;
    lastUpdatedAt.value = null;
  }

  void _onPosition(Position pos) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _commerceId == null) return;

    FirebaseFirestore.instance.collection('commerces').doc(_commerceId!).update({
      'liveLocation': GeoPoint(pos.latitude, pos.longitude),
      'liveLocationUpdatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
    lastUpdatedAt.value = DateTime.now();
  }
}
