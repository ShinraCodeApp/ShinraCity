import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Broadcasts the live location of an ambulant vendor to Firestore.
/// Start it when the vendor opens the app; it stops automatically on dispose.
class AmbulantLocationService {
  AmbulantLocationService._();
  static final AmbulantLocationService instance = AmbulantLocationService._();

  StreamSubscription<Position>? _sub;
  String? _commerceId;

  bool get isRunning => _sub != null;

  Future<void> start(String commerceId) async {
    if (_sub != null) return;
    _commerceId = commerceId;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen(_onPosition, onError: (_) => stop());
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
  }

  void _onPosition(Position pos) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _commerceId == null) return;

    FirebaseFirestore.instance.collection('commerces').doc(_commerceId!).update({
      'liveLocation': GeoPoint(pos.latitude, pos.longitude),
      'liveLocationUpdatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }
}
