import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CouponGenerator {
  CouponGenerator._();

  static const _uuid = Uuid();
  static const String _secretKey = 'ShinraCity2024SecureKey32BytesXX';

  static String generateUniqueId() => _uuid.v4();

  static String generateToken({
    required String couponId,
    required String userId,
    required String promotionId,
    required DateTime expiresAt,
  }) {
    final payload = {
      'cid': couponId,
      'uid': userId,
      'pid': promotionId,
      'exp': expiresAt.millisecondsSinceEpoch,
      'iat': DateTime.now().millisecondsSinceEpoch,
      'jti': _uuid.v4(),
    };

    final payloadJson = jsonEncode(payload);
    final key = enc.Key.fromUtf8(_secretKey);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(payloadJson, iv: iv);

    return '${iv.base64}:${encrypted.base64}';
  }

  static Map<String, dynamic>? validateToken(String token) {
    try {
      final parts = token.split(':');
      if (parts.length != 2) return null;

      final key = enc.Key.fromUtf8(_secretKey);
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt64(parts[1], iv: iv);

      final payload = jsonDecode(decrypted) as Map<String, dynamic>;
      final exp = payload['exp'] as int;

      if (DateTime.fromMillisecondsSinceEpoch(exp).isBefore(DateTime.now())) {
        return null;
      }

      return payload;
    } catch (_) {
      return null;
    }
  }

  static String generateQRData({
    required String couponId,
    required String token,
  }) {
    final data = {
      'shinra': '1',
      'id': couponId,
      't': token,
      'v': 'v1',
    };
    return jsonEncode(data);
  }

  static String generateChecksum(String data) {
    final bytes = utf8.encode(data + _secretKey);
    return sha256.convert(bytes).toString();
  }

  static bool verifyChecksum(String data, String checksum) {
    return generateChecksum(data) == checksum;
  }

  static String generateAntifraudFingerprint({
    required String userId,
    required String deviceId,
    required String promotionId,
  }) {
    final raw = '$userId:$deviceId:$promotionId:${DateTime.now().day}';
    final bytes = utf8.encode(raw + _secretKey);
    return sha256.convert(bytes).toString().substring(0, 16);
  }
}
