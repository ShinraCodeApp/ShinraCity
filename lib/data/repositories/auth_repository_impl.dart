import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase/firebase_auth_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDatasource _datasource;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    required FirebaseAuthDatasource datasource,
    required FirebaseFirestore firestore,
  })  : _datasource = datasource,
        _firestore = firestore;

  @override
  Stream<UserEntity?> get authStateChanges => _datasource.authStateChanges;

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _datasource.signInWithEmail(
        email: email,
        password: password,
      );
      return Right(user);
    } on AuthFailure catch (e) {
      return Left(e);
    } on NotFoundFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String accountType = 'user',
  }) async {
    try {
      final user = await _datasource.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        accountType: accountType,
      );
      return Right(user);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      final user = await _datasource.signInWithGoogle();
      return Right(user);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithApple() async {
    try {
      final user = await _datasource.signInWithApple();
      return Right(user);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithFacebook() async {
    return const Left(ServerFailure(message: 'Facebook login no disponible'));
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _datasource.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      await _datasource.sendPasswordResetEmail(email);
      return const Right(null);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      await _datasource.sendEmailVerification();
      return const Right(null);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await _datasource.getCurrentUser();
      return Right(user);
    } on AuthFailure catch (e) {
      return Left(e);
    } on NotFoundFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
  }) async {
    try {
      final current = await _datasource.getCurrentUser();
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(current.id).update(updates);
      final updated = await _datasource.getCurrentUser();
      return Right(updated);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateFcmToken(String token) async {
    try {
      final current = await _datasource.getCurrentUser();
      await _datasource.updateFcmToken(current.id, token);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateSettings({
    bool? notificationsEnabled,
    bool? locationEnabled,
  }) async {
    try {
      final current = await _datasource.getCurrentUser();
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (notificationsEnabled != null) {
        updates['notificationsEnabled'] = notificationsEnabled;
      }
      if (locationEnabled != null) {
        updates['locationEnabled'] = locationEnabled;
      }
      await _firestore.collection('users').doc(current.id).update(updates);
      final updated = await _datasource.getCurrentUser();
      return Right(updated);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      final user = await _datasource.getCurrentUser();
      await _firestore.collection('users').doc(user.id).delete();
      await _datasource.deleteAuthUser();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getUserByEmail(String email) async {
    try {
      return Right(await _datasource.getUserByEmail(email));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getUserById(String userId) async {
    try {
      return Right(await _datasource.getUserById(userId));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
