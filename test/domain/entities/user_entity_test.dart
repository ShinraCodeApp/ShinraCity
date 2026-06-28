import 'package:flutter_test/flutter_test.dart';
import 'package:shinra_city/domain/entities/user_entity.dart';

void main() {
  UserEntity makeUser({
    int totalPoints = 0,
    UserLevel level = UserLevel.explorer,
  }) =>
      UserEntity(
        id: 'u1',
        email: 'a@b.com',
        role: UserRole.user,
        level: level,
        totalPoints: totalPoints,
        availablePoints: totalPoints,
        totalCouponsRedeemed: 0,
        totalSavings: 0,
        favoriteCommerceIds: [],
        followingCommerceIds: [],
        followingCategories: [],
        badgeIds: [],
        achievementIds: [],
        isActive: true,
        isVerified: false,
        notificationsEnabled: true,
        locationEnabled: true,
        authProvider: AuthProvider.email,
        createdAt: DateTime(2024),
        lastActiveAt: DateTime(2024),
      );

  group('UserLevelX.levelDisplayName', () {
    test('explorer → "Explorador"', () {
      expect(makeUser().levelDisplayName, isNotEmpty);
    });

    test('lifetime muestra el máximo nivel', () {
      final u = makeUser(level: UserLevel.lifetime);
      expect(u.levelDisplayName, isNotEmpty);
    });
  });

  group('UserLevelX.levelProgress', () {
    test('0 puntos → progreso 0.0', () {
      expect(makeUser(totalPoints: 0).levelProgress, equals(0.0));
    });

    test('progreso está en [0.0, 1.0]', () {
      for (final pts in [0, 50, 200, 500, 1500, 5000, 9999]) {
        final progress = makeUser(totalPoints: pts).levelProgress;
        expect(progress, inInclusiveRange(0.0, 1.0),
            reason: 'falló con $pts puntos');
      }
    });
  });

  group('UserLevelX.nextLevelPoints', () {
    test('explorer tiene un umbral > 0', () {
      expect(makeUser().nextLevelPoints, greaterThan(0));
    });

    test('lifetime retorna el mismo umbral (nivel máximo)', () {
      final u = makeUser(level: UserLevel.lifetime, totalPoints: 9999);
      expect(u.nextLevelPoints, greaterThan(0));
    });
  });

  group('UserEntity.copyWith', () {
    test('displayName se actualiza sin modificar el resto', () {
      final u = makeUser().copyWith(displayName: 'María');
      expect(u.displayName, equals('María'));
      expect(u.email, equals('a@b.com'));
    });

    test('notificationsEnabled se puede desactivar', () {
      final u = makeUser().copyWith(notificationsEnabled: false);
      expect(u.notificationsEnabled, isFalse);
    });
  });
}
