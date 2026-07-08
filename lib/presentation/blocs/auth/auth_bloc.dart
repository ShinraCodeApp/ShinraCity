import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../services/analytics_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class SignInWithEmailEvent extends AuthEvent {
  final String email;
  final String password;

  SignInWithEmailEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignUpWithEmailEvent extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  final String accountType; // 'user' | 'business'

  SignUpWithEmailEvent({
    required this.email,
    required this.password,
    required this.displayName,
    this.accountType = 'user',
  });

  @override
  List<Object?> get props => [email, displayName, accountType];
}

class SignInWithGoogleEvent extends AuthEvent {}

class SignInWithAppleEvent extends AuthEvent {}

class SignInWithFacebookEvent extends AuthEvent {}

class SignOutEvent extends AuthEvent {}

class DeleteAccountEvent extends AuthEvent {}

class SendPasswordResetEvent extends AuthEvent {
  final String email;
  SendPasswordResetEvent({required this.email});

  @override
  List<Object?> get props => [email];
}

class UpdateProfileEvent extends AuthEvent {
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;

  UpdateProfileEvent({this.displayName, this.photoUrl, this.phoneNumber});
}

class UpdateSettingsEvent extends AuthEvent {
  final bool? notificationsEnabled;
  final bool? locationEnabled;

  UpdateSettingsEvent({this.notificationsEnabled, this.locationEnabled});

  @override
  List<Object?> get props => [notificationsEnabled, locationEnabled];
}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthEmailVerificationSent extends AuthState {}

class AuthPasswordResetSent extends AuthState {}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final AnalyticsService? _analytics;

  AuthBloc({required AuthRepository authRepository, AnalyticsService? analytics})
      : _authRepository = authRepository,
        _analytics = analytics,
        super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<SignInWithEmailEvent>(_onSignInWithEmail);
    on<SignUpWithEmailEvent>(_onSignUpWithEmail);
    on<SignInWithGoogleEvent>(_onSignInWithGoogle);
    on<SignInWithAppleEvent>(_onSignInWithApple);
    on<SignInWithFacebookEvent>(_onSignInWithFacebook);
    on<SignOutEvent>(_onSignOut);
    on<SendPasswordResetEvent>(_onSendPasswordReset);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<UpdateSettingsEvent>(_onUpdateSettings);
    on<DeleteAccountEvent>(_onDeleteAccount);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final prefs = await SharedPreferences.getInstance();
    final keepLoggedIn = prefs.getBool('keep_logged_in') ?? true;
    if (!keepLoggedIn) {
      await _authRepository.signOut();
      await prefs.remove('keep_logged_in');
      emit(AuthUnauthenticated());
      return;
    }
    final result = await _authRepository.getCurrentUser();
    result.fold(
      (_) => emit(AuthUnauthenticated()),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onSignInWithEmail(
    SignInWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _authRepository.signInWithEmail(
      email: event.email,
      password: event.password,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) {
        _analytics?.logLogin(method: 'email');
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSignUpWithEmail(
    SignUpWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _authRepository.signUpWithEmail(
      email: event.email,
      password: event.password,
      displayName: event.displayName,
      accountType: event.accountType,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) {
        _analytics?.logSignUp(method: 'email');
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _authRepository.signInWithGoogle();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) {
        _analytics?.logLogin(method: 'google');
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSignInWithApple(
    SignInWithAppleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _authRepository.signInWithApple();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) {
        _analytics?.logLogin(method: 'apple');
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSignInWithFacebook(
    SignInWithFacebookEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _authRepository.signInWithFacebook();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onSignOut(SignOutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onSendPasswordReset(
    SendPasswordResetEvent event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _authRepository.sendPasswordResetEmail(event.email);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthPasswordResetSent()),
    );
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _authRepository.updateProfile(
      displayName: event.displayName,
      photoUrl: event.photoUrl,
      phoneNumber: event.phoneNumber,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onUpdateSettings(
    UpdateSettingsEvent event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _authRepository.updateSettings(
      notificationsEnabled: event.notificationsEnabled,
      locationEnabled: event.locationEnabled,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onDeleteAccount(
    DeleteAccountEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _authRepository.deleteAccount();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthUnauthenticated()),
    );
  }
}
