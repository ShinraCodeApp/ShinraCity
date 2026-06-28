import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../../core/errors/failures.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;

  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String accountType = 'user',
  });

  Future<Either<Failure, UserEntity>> signInWithGoogle();

  Future<Either<Failure, UserEntity>> signInWithApple();

  Future<Either<Failure, UserEntity>> signInWithFacebook();

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, void>> sendPasswordResetEmail(String email);

  Future<Either<Failure, void>> sendEmailVerification();

  Future<Either<Failure, UserEntity>> getCurrentUser();

  Future<Either<Failure, UserEntity>> updateProfile({
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
  });

  Future<Either<Failure, void>> updateFcmToken(String token);

  Future<Either<Failure, UserEntity>> updateSettings({
    bool? notificationsEnabled,
    bool? locationEnabled,
  });

  Future<Either<Failure, void>> deleteAccount();

  Future<Either<Failure, UserEntity?>> getUserByEmail(String email);

  Future<Either<Failure, UserEntity?>> getUserById(String userId);
}
