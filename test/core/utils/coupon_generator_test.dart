import 'package:flutter_test/flutter_test.dart';
import 'package:shinra_city/core/utils/coupon_generator.dart';

void main() {
  group('CouponGenerator', () {
    const userId = 'user_abc_123';
    const promotionId = 'promo_xyz_456';
    const commerceId = 'commerce_789';

    group('generateCouponCode', () {
      test('genera un código no vacío', () {
        final code = CouponGenerator.generateCouponCode(
          userId: userId,
          promotionId: promotionId,
          commerceId: commerceId,
        );
        expect(code, isNotEmpty);
      });

      test('dos llamadas con los mismos parámetros generan códigos distintos',
          () {
        final code1 = CouponGenerator.generateCouponCode(
          userId: userId,
          promotionId: promotionId,
          commerceId: commerceId,
        );
        final code2 = CouponGenerator.generateCouponCode(
          userId: userId,
          promotionId: promotionId,
          commerceId: commerceId,
        );
        // Cada generación tiene timestamp/uuid único
        expect(code1, isNot(equals(code2)));
      });
    });

    group('generateQRData / validateQRData', () {
      test('los datos generados son válidos al momento de la validación', () {
        final qrData = CouponGenerator.generateQRData(
          couponId: 'coupon_001',
          userId: userId,
          promotionId: promotionId,
          commerceId: commerceId,
        );
        expect(qrData, isNotEmpty);

        final result = CouponGenerator.validateQRData(qrData);
        expect(result, isNotNull);
        expect(result!['couponId'], equals('coupon_001'));
        expect(result['userId'], equals(userId));
        expect(result['promotionId'], equals(promotionId));
        expect(result['commerceId'], equals(commerceId));
      });

      test('datos QR alterados retornan null', () {
        const tampered = 'datos_invalidos_xyz';
        final result = CouponGenerator.validateQRData(tampered);
        expect(result, isNull);
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
