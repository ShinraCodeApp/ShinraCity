import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:shinra_city/core/errors/failures.dart';
import 'package:shinra_city/domain/entities/user_entity.dart';
import 'package:shinra_city/domain/repositories/auth_repository.dart';
import 'package:shinra_city/presentation/blocs/auth/auth_bloc.dart';

import 'auth_bloc_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late MockAuthRepository mockRepo;
  late AuthBloc bloc;

  final testUser = UserEntity(
    id: 'uid_1',
    email: 'test@test.com',
    displayName: 'Test User',
    role: UserRole.user,
    level: UserLevel.explorer,
    totalPoints: 0,
    availablePoints: 0,
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

  setUp(() {
    mockRepo = MockAuthRepository();
    // authStateChanges stream requerido en el constructor
    when(mockRepo.authStateChanges).thenAnswer((_) => const Stream.empty());
    bloc = AuthBloc(authRepository: mockRepo);
  });

  tearDown(() => bloc.close());

  group('AppStarted', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] cuando hay usuario activo',
      build: () {
        when(mockRepo.getCurrentUser())
            .thenAnswer((_) async => Right(testUser));
        return bloc;
      },
      act: (b) => b.add(AppStarted()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthUnauthenticated] cuando no hay sesión',
      build: () {
        when(mockRepo.getCurrentUser()).thenAnswer(
          (_) async => const Left(AuthFailure(message: 'Sin sesión')),
        );
        return bloc;
      },
      act: (b) => b.add(AppStarted()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );
  });

  group('SignUpWithEmailEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] con rol user',
      build: () {
        when(mockRepo.signUpWithEmail(
                email: anyNamed('email'),
                password: anyNamed('password'),
                displayName: anyNamed('displayName'),
                accountType: anyNamed('accountType')))
            .thenAnswer((_) async => Right(testUser));
        return bloc;
      },
      act: (b) => b.add(
        SignUpWithEmailEvent(
          email: 'nuevo@test.com',
          password: 'Pass123!',
          displayName: 'Nuevo Usuario',
          accountType: 'user',
        ),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] con rol business',
      build: () {
        final bizUser = testUser.copyWith(role: UserRole.businessOwner);
        when(mockRepo.signUpWithEmail(
                email: anyNamed('email'),
                password: anyNamed('password'),
                displayName: anyNamed('displayName'),
                accountType: anyNamed('accountType')))
            .thenAnswer((_) async => Right(bizUser));
        return bloc;
      },
      act: (b) => b.add(
        SignUpWithEmailEvent(
          email: 'negocio@test.com',
          password: 'Pass123!',
          displayName: 'Mi Negocio',
          accountType: 'business',
        ),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>().having(
          (s) => s.user.role,
          'role',
          UserRole.businessOwner,
        ),
      ],
    );
  });

  group('SignInWithEmailEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] con credenciales válidas',
      build: () {
        when(mockRepo.signInWithEmail(
                email: anyNamed('email'), password: anyNamed('password')))
            .thenAnswer((_) async => Right(testUser));
        return bloc;
      },
      act: (b) => b.add(
        SignInWithEmailEvent(email: 'test@test.com', password: 'Pass123!'),
      ),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthError] con credenciales inválidas',
      build: () {
        when(mockRepo.signInWithEmail(
                email: anyNamed('email'), password: anyNamed('password')))
            .thenAnswer((_) async =>
                const Left(AuthFailure(message: 'Contraseña incorrecta')));
        return bloc;
      },
      act: (b) => b.add(
        SignInWithEmailEvent(email: 'test@test.com', password: 'wrong'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having((s) => s.message, 'message', 'Contraseña incorrecta'),
      ],
    );
  });

  group('SignOutEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthUnauthenticated]',
      build: () {
        when(mockRepo.signOut())
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (b) => b.add(SignOutEvent()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );
  });

  group('UpdateProfileEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthAuthenticated] con el usuario actualizado',
      build: () {
        final updated = testUser.copyWith(displayName: 'Nuevo Nombre');
        when(mockRepo.updateProfile(
                displayName: anyNamed('displayName'),
                photoUrl: anyNamed('photoUrl'),
                phoneNumber: anyNamed('phoneNumber')))
            .thenAnswer((_) async => Right(updated));
        return bloc;
      },
      act: (b) =>
          b.add(UpdateProfileEvent(displayName: 'Nuevo Nombre')),
      expect: () => [
        isA<AuthAuthenticated>().having(
          (s) => s.user.displayName,
          'displayName',
          'Nuevo Nombre',
        ),
      ],
    );
  });

  group('UpdateSettingsEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthAuthenticated] con notificaciones desactivadas',
      build: () {
        final updated = testUser.copyWith(notificationsEnabled: false);
        when(mockRepo.updateSettings(
                notificationsEnabled: anyNamed('notificationsEnabled'),
                locationEnabled: anyNamed('locationEnabled')))
            .thenAnswer((_) async => Right(updated));
        return bloc;
      },
      act: (b) =>
          b.add(UpdateSettingsEvent(notificationsEnabled: false)),
      expect: () => [
        isA<AuthAuthenticated>().having(
          (s) => s.user.notificationsEnabled,
          'notificationsEnabled',
          false,
        ),
      ],
    );
  });

  group('DeleteAccountEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthUnauthenticated] al borrar cuenta',
      build: () {
        when(mockRepo.deleteAccount())
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (b) => b.add(DeleteAccountEvent()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthError] si falla el borrado',
      build: () {
        when(mockRepo.deleteAccount()).thenAnswer(
          (_) async =>
              const Left(ServerFailure(message: 'Error al eliminar')),
        );
        return bloc;
      },
      act: (b) => b.add(DeleteAccountEvent()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having(
            (s) => s.message, 'message', 'Error al eliminar'),
      ],
    );
  });

  group('SendPasswordResetEvent', () {
    blocTest<AuthBloc, AuthState>(
      'no emite ningún estado — solo llama sendPasswordResetEmail',
      build: () {
        when(mockRepo.sendPasswordResetEmail(any))
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (b) => b.add(SendPasswordResetEvent(email: 'test@test.com')),
      expect: () => [],
    );
  });

  group('SignInWithGoogleEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] en éxito',
      build: () {
        when(mockRepo.signInWithGoogle())
            .thenAnswer((_) async => Right(testUser));
        return bloc;
      },
      act: (b) => b.add(SignInWithGoogleEvent()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthError] en fallo',
      build: () {
        when(mockRepo.signInWithGoogle()).thenAnswer(
          (_) async =>
              const Left(AuthFailure(message: 'Cuenta Google cancelada')),
        );
        return bloc;
      },
      act: (b) => b.add(SignInWithGoogleEvent()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>()
            .having((s) => s.message, 'message', 'Cuenta Google cancelada'),
      ],
    );
  });

  group('SignInWithAppleEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] en éxito',
      build: () {
        when(mockRepo.signInWithApple())
            .thenAnswer((_) async => Right(testUser));
        return bloc;
      },
      act: (b) => b.add(SignInWithAppleEvent()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthError] en fallo',
      build: () {
        when(mockRepo.signInWithApple()).thenAnswer(
          (_) async =>
              const Left(AuthFailure(message: 'Sign in with Apple cancelado')),
        );
        return bloc;
      },
      act: (b) => b.add(SignInWithAppleEvent()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          'Sign in with Apple cancelado',
        ),
      ],
    );
  });

  group('SignInWithFacebookEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthAuthenticated] en éxito',
      build: () {
        when(mockRepo.signInWithFacebook())
            .thenAnswer((_) async => Right(testUser));
        return bloc;
      },
      act: (b) => b.add(SignInWithFacebookEvent()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emite [AuthLoading, AuthError] en fallo',
      build: () {
        when(mockRepo.signInWithFacebook()).thenAnswer(
          (_) async =>
              const Left(AuthFailure(message: 'Facebook login cancelado')),
        );
        return bloc;
      },
      act: (b) => b.add(SignInWithFacebookEvent()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          'Facebook login cancelado',
        ),
      ],
    );
  });
}
