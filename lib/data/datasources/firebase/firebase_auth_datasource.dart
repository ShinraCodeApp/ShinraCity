import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../models/user_model.dart';
import '../../../domain/entities/user_entity.dart';

class FirebaseAuthDatasource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthDatasource({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
  })  : _auth = auth,
        _firestore = firestore,
        _googleSignIn = googleSignIn;

  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _getUserFromFirestore(user.uid);
    });
  }

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final resolvedEmail = await _resolveIdentifier(email);
      final credential = await _auth.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      );
      return _getUserFromFirestore(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(message: _mapAuthError(e.code), code: e.code);
    } on AuthFailure {
      rethrow;
    }
  }

  /// Accepts email, display name, or business name — returns the Firebase Auth email.
  Future<String> _resolveIdentifier(String input) async {
    if (input.contains('@')) return input;

    // Search by displayName in users collection
    final byName = await _firestore
        .collection(AppConstants.usersCollection)
        .where('displayName', isEqualTo: input)
        .limit(1)
        .get();
    if (byName.docs.isNotEmpty) {
      final email = byName.docs.first.data()['email'] as String? ?? '';
      if (email.isNotEmpty) return email;
    }

    // Search by business name in commerces collection → get owner email
    final byBiz = await _firestore
        .collection(AppConstants.commercesCollection)
        .where('name', isEqualTo: input)
        .limit(1)
        .get();
    if (byBiz.docs.isNotEmpty) {
      final ownerId = byBiz.docs.first.data()['ownerId'] as String? ?? '';
      if (ownerId.isNotEmpty) {
        final ownerDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(ownerId)
            .get();
        final ownerEmail = ownerDoc.data()?['email'] as String? ?? '';
        if (ownerEmail.isNotEmpty) return ownerEmail;
      }
    }

    throw const AuthFailure(
      message: 'No encontramos una cuenta con ese usuario o negocio',
    );
  }

  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String accountType = 'user',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user!.updateDisplayName(displayName);
      await credential.user!.sendEmailVerification();

      final role = accountType == 'business'
          ? UserRole.businessOwner
          : UserRole.user;

      final user = UserModel(
        id: credential.user!.uid,
        email: email,
        displayName: displayName,
        role: role,
        level: UserLevel.explorer,
        authProvider: AuthProvider.email,
        createdAt: DateTime.now(),
        referralCode: _generateReferralCode(credential.user!.uid),
      );

      await _createUserDocument(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(message: _mapAuthError(e.code), code: e.code);
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw const AuthFailure(message: 'Inicio de sesión cancelado');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNew) {
        final user = UserModel(
          id: userCredential.user!.uid,
          email: userCredential.user!.email!,
          displayName: userCredential.user!.displayName,
          photoUrl: userCredential.user!.photoURL,
          role: UserRole.user,
          level: UserLevel.explorer,
          authProvider: AuthProvider.google,
          createdAt: DateTime.now(),
          referralCode: _generateReferralCode(userCredential.user!.uid),
        );
        await _createUserDocument(user);
        return user;
      }

      return _getUserFromFirestore(userCredential.user!.uid);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure(message: 'Error al iniciar con Google: ${e.toString()}');
    }
  }

  Future<UserModel> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNew) {
        final displayName = appleCredential.givenName != null
            ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
            : null;

        final user = UserModel(
          id: userCredential.user!.uid,
          email: userCredential.user!.email ?? appleCredential.email ?? '',
          displayName: displayName,
          role: UserRole.user,
          level: UserLevel.explorer,
          authProvider: AuthProvider.apple,
          createdAt: DateTime.now(),
          referralCode: _generateReferralCode(userCredential.user!.uid),
        );
        await _createUserDocument(user);
        return user;
      }

      return _getUserFromFirestore(userCredential.user!.uid);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure(message: 'Error al iniciar con Apple: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(message: _mapAuthError(e.code), code: e.code);
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(message: 'No hay sesión activa');
    if (user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(message: _mapAuthError(e.code), code: e.code);
    }
  }

  Future<UserModel> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(message: 'No hay sesión activa');
    return _getUserFromFirestore(user.uid);
  }

  Future<void> deleteAuthUser() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure(message: 'No hay sesión activa');
    await user.delete();
  }

  Future<void> updateFcmToken(String userId, String token) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final snap = await _firestore
        .collection(AppConstants.usersCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromFirestore(snap.docs.first);
  }

  Future<UserModel> _getUserFromFirestore(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists) throw const NotFoundFailure(message: 'Usuario no encontrado');
    final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    if ((data['email'] as String? ?? '').isEmpty) {
      data['email'] = _auth.currentUser?.email ?? '';
    }
    return UserModel.fromMap(data, uid);
  }

  Future<void> _createUserDocument(UserModel user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.id)
        .set(user.toFirestore());
  }

  String _generateReferralCode(String uid) {
    return uid.substring(0, 8).toUpperCase();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found': return 'No existe una cuenta con este email';
      case 'wrong-password': return 'Contraseña incorrecta';
      case 'email-already-in-use': return 'Este email ya está registrado';
      case 'weak-password': return 'La contraseña debe tener al menos 6 caracteres';
      case 'invalid-email': return 'Email inválido';
      case 'too-many-requests': return 'Demasiados intentos. Intenta más tarde';
      case 'network-request-failed': return 'Sin conexión a internet';
      default: return 'Error de autenticación. Intenta de nuevo';
    }
  }
}
