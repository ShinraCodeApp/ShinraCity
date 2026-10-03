import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/biometric_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/social_auth_button.dart';
import '../../widgets/common/shinra_text_field.dart';
import '../../../services/injection_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _biometricService = sl<BiometricService>();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _usedEmailLogin = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await _biometricService.isAvailable();
    final enabled = available ? await _biometricService.isEnabled() : false;
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthAuthenticated) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('keep_logged_in', _rememberMe);

            // Si el login fue con email/password y biometría no está habilitada aún, ofrecer
            if (_usedEmailLogin && _biometricAvailable && !_biometricEnabled && context.mounted) {
              final enabled = await _showEnableBiometricDialog(context);
              if (enabled && context.mounted) {
                await _biometricService.saveCredentials(
                  email: _identifierController.text.trim(),
                  password: _passwordController.text,
                );
              }
            }

            if (context.mounted) context.go('/map');
          } else if (state is AuthPasswordResetSent) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.backgroundCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Email enviado', style: TextStyle(color: Colors.white)),
                content: Text(
                  'Revisá tu bandeja de entrada en ${_identifierController.text.trim()} para restablecer tu contraseña.',
                  style: TextStyle(color: AppColors.textSecondaryDark),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Aceptar', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0E1A), Color(0xFF0D1B2A)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  _buildLogo(),
                  const SizedBox(height: 48),
                  _buildTitle(),
                  const SizedBox(height: 32),
                  _buildForm(),
                  const SizedBox(height: 24),
                  if (_biometricEnabled) _buildBiometricButton(),
                  _buildSocialAuth(),
                  const SizedBox(height: 32),
                  _buildRegisterLink(),
                  const SizedBox(height: 20),
                  _buildPrivacyNotice(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.location_city, size: 44, color: Colors.white),
          )
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
            child: const Text(
              'ShinraCity',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenido de vuelta',
          style: AppTextStyles.headlineLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Descubrí las mejores promociones cerca de vos',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          ShinraTextField(
            controller: _identifierController,
            label: 'Email',
            hint: 'juan@mail.com',
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.text,
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Ingresá tu email, nombre de usuario o negocio';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ShinraTextField(
            controller: _passwordController,
            label: 'Contraseña',
            prefixIcon: Icons.lock_outlined,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondaryDark,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Ingresá tu contraseña';
              if ((value?.length ?? 0) < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? true),
                activeColor: AppColors.primary,
                side: const BorderSide(color: AppColors.textSecondaryDark),
              ),
              Text('Mantenerme conectado',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark)),
              const Spacer(),
              TextButton(
                onPressed: _handleForgotPassword,
                child: Text('¿Olvidaste tu contraseña?',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              return GradientButton(
                onPressed: state is AuthLoading ? null : _handleLogin,
                isLoading: state is AuthLoading,
                child: const Text('Iniciar Sesión'),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildBiometricButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: Column(
          children: [
            GestureDetector(
              onTap: _handleBiometricLogin,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresar con huella',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 450.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildSocialAuth() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'O continuar con',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SocialAuthButton(
                provider: 'Google',
                iconPath: 'assets/icons/google.svg',
                onPressed: _handleGoogleLogin,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SocialAuthButton(
                provider: 'Apple',
                iconPath: 'assets/icons/apple.svg',
                onPressed: _handleAppleLogin,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildRegisterLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿No tenés cuenta? ',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
          ),
          GestureDetector(
            onTap: () => context.push('/register'),
            child: Text(
              'Registrate',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildPrivacyNotice() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
          children: [
            const TextSpan(text: 'Al ingresar aceptás nuestra '),
            TextSpan(
              text: 'Política de Privacidad',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(
                      Uri.parse('https://shinra-city.web.app/privacy'),
                      mode: LaunchMode.externalApplication,
                    ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 650.ms);
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    _usedEmailLogin = true;
    context.read<AuthBloc>().add(SignInWithEmailEvent(
      email: _identifierController.text.trim(),
      password: _passwordController.text,
    ));
  }

  Future<void> _handleBiometricLogin() async {
    final authenticated = await _biometricService.authenticate();
    if (!authenticated || !mounted) return;

    final credentials = await _biometricService.getCredentials();
    if (credentials == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron credenciales guardadas'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _usedEmailLogin = false; // ya tiene huella habilitada, no ofrecer de nuevo
    context.read<AuthBloc>().add(SignInWithEmailEvent(
      email: credentials['email']!,
      password: credentials['password']!,
    ));
  }

  void _handleGoogleLogin() {
    _usedEmailLogin = false;
    context.read<AuthBloc>().add(SignInWithGoogleEvent());
  }

  void _handleAppleLogin() {
    _usedEmailLogin = false;
    context.read<AuthBloc>().add(SignInWithAppleEvent());
  }

  void _handleForgotPassword() {
    final id = _identifierController.text.trim();
    if (id.isNotEmpty && id.contains('@')) {
      context.read<AuthBloc>().add(SendPasswordResetEvent(email: id));
      return;
    }
    final emailCtrl = TextEditingController(text: id.contains('@') ? id : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recuperar contraseña', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ingresá el email de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
                style: TextStyle(color: AppColors.textSecondaryDark)),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'tu@email.com',
                hintStyle: TextStyle(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: AppColors.backgroundSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () {
              final email = emailCtrl.text.trim();
              if (email.contains('@')) {
                Navigator.pop(ctx);
                _identifierController.text = email;
                context.read<AuthBloc>().add(SendPasswordResetEvent(email: email));
              }
            },
            child: const Text('Enviar', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<bool> _showEnableBiometricDialog(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(Icons.fingerprint, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Activar acceso con huella',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'La próxima vez que abras la app podés ingresar directamente con tu huella digital, sin escribir tu contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.fingerprint, color: Colors.white),
                label: const Text('Activar huella digital'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Ahora no',
                  style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}
