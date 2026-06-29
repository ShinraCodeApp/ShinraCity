import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/social_auth_button.dart';
import '../../widgets/common/shinra_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

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
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/map');
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
                  _buildSocialAuth(),
                  const SizedBox(height: 32),
                  _buildRegisterLink(),
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
                  color: AppColors.primary.withOpacity(0.4),
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
            label: 'Email, usuario o negocio',
            hint: 'juan@mail.com · Juan Pérez · Mi Tienda',
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),
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

  Widget _buildSocialAuth() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'O continuar con',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
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

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(SignInWithEmailEvent(
      email: _identifierController.text.trim(),
      password: _passwordController.text,
    ));
  }

  void _handleGoogleLogin() {
    context.read<AuthBloc>().add(SignInWithGoogleEvent());
  }

  void _handleAppleLogin() {
    context.read<AuthBloc>().add(SignInWithAppleEvent());
  }

  void _handleForgotPassword() {
    final id = _identifierController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá tu email primero')),
      );
      return;
    }
    if (!id.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Para recuperar la contraseña ingresá tu email')),
      );
      return;
    }
    context.read<AuthBloc>().add(SendPasswordResetEvent(email: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email de recuperación enviado'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
