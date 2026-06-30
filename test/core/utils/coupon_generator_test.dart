import 'package:flutter_test/flutter_test.dart';
import 'package:shinra_city/core/utils/coupon_generator.dart';

void main() {
  group('CouponGenerator', () {
    const userId = 'user_abc_123';
    const promotionId = 'promo_xyz_456';
    const couponId = 'coupon_001';
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    group('generateToken', () {
      test('genera un token no vacío', () {
        final token = CouponGenerator.generateToken(
          couponId: couponId,
          userId: userId,
          promotionId: promotionId,
          expiresAt: expiresAt,
        );
        expect(token, isNotEmpty);
      });

      test('dos llamadas generan tokens distintos (IV aleatorio)', () {
        final token1 = CouponGenerator.generateToken(
          couponId: couponId,
          userId: userId,
          promotionId: promotionId,
          expiresAt: expiresAt,
        );
        final token2 = CouponGenerator.generateToken(
          couponId: couponId,
          userId: userId,
          promotionId: promotionId,
          expiresAt: expiresAt,
        );
        expect(token1, isNot(equals(token2)));
      });
    });

    group('validateToken', () {
      test('token válido retorna el payload con los datos correctos', () {
        final token = CouponGenerator.generateToken(
          couponId: couponId,
          userId: userId,
          promotionId: promotionId,
          expiresAt: expiresAt,
        );

        final result = CouponGenerator.validateToken(token);
        expect(result, isNotNull);
        expect(result!['cid'], equals(couponId));
        expect(result['uid'], equals(userId));
        expect(result['pid'], equals(promotionId));
      });

      test('token alterado retorna null', () {
        final result = CouponGenerator.validateToken('datos_invalidos_xyz');
        expect(result, isNull);
      });

      test('token expirado retorna null', () {
        final expiredToken = CouponGenerator.generateToken(
          couponId: couponId,
          userId: userId,
          promotionId: promotionId,
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        final result = CouponGenerator.validateToken(expiredToken);
        expect(result, isNull);
      });
    });

    group('generateQRData', () {
      test('genera JSON con los campos esperados', () {
        final token = CouponGenerator.generateToken(
          couponId: couponId,
          userId: userId,
          promotionId: promotionId,
          expiresAt: expiresAt,
        );
        final qrData = CouponGenerator.generateQRData(
          couponId: couponId,
          token: token,
        );
        expect(qrData, isNotEmpty);
        expect(qrData, contains('"shinra"'));
        expect(qrData, contains(couponId));
      });
    });

    group('generateChecksum / verifyChecksum', () {
      test('checksum es verificable', () {
        const data = 'test_data_string';
        final checksum = CouponGenerator.generateChecksum(data);
        expect(CouponGenerator.verifyChecksum(data, checksum), isTrue);
      });

      test('checksum falla con datos alterados', () {
        const data = 'test_data_string';
        final checksum = CouponGenerator.generateChecksum(data);
        expect(CouponGenerator.verifyChecksum('datos_alterados', checksum), isFalse);
      });
    });

    group('generateAntifraudFingerprint', () {
      test('genera un fingerprint no vacío', () {
        final fp = CouponGenerator.generateAntifraudFingerprint(
          userId: userId,
          deviceId: 'device_abc',
          promotionId: promotionId,
        );
        expect(fp, isNotEmpty);
      });

      test('mismo input siempre produce el mismo fingerprint', () {
        final fp1 = CouponGenerator.generateAntifraudFingerprint(
          userId: userId,
          deviceId: 'device_abc',
          promotionId: promotionId,
        );
        final fp2 = CouponGenerator.generateAntifraudFingerprint(
          userId: userId,
          deviceId: 'device_abc',
          promotionId: promotionId,
        );
        expect(fp1, equals(fp2));
      });

      test('distinto deviceId produce distinto fingerprint', () {
        final fp1 = CouponGenerator.generateAntifraudFingerprint(
          userId: userId,
          deviceId: 'device_abc',
          promotionId: promotionId,
        );
        final fp2 = CouponGenerator.generateAntifraudFingerprint(
          userId: userId,
          deviceId: 'device_xyz',
          promotionId: promotionId,
        );
        expect(fp1, isNot(equals(fp2)));
      });
    });
  });
}
