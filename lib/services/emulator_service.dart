import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class EmulatorService {
  // Emulator host — use 10.0.2.2 on Android emulator (maps to host localhost)
  static const _host = 'localhost';
  static const _androidHost = '10.0.2.2';

  static bool get _useEmulators =>
      kDebugMode && const bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

  static String get _emulatorHost {
    // Android emulator uses 10.0.2.2 to reach the host machine
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      return _androidHost;
    }
    return _host;
  }

  static Future<void> connectToEmulators() async {
    if (!_useEmulators) return;

    final host = _emulatorHost;

    // Auth emulator — port 9099
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    // Firestore emulator — port 8080
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);

    // Storage emulator — port 9199
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);

    // Functions emulator — port 5001
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);

    debugPrint('🔧 Firebase emulators connected @ $host');
  }
}
