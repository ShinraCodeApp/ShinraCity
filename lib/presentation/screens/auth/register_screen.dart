import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/shinra_text_field.dart';
import '../../widgets/common/social_auth_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  String _accountType = 'user'; // 'user' | 'business'

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
                  const SizedBox(height: 24),
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  _buildAccountTypeSelector(),
                  const SizedBox(height: 24),
                  _buildForm(),
                  const SizedBox(height: 16),
                  _buildTerms(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 20),
                  _buildSocialAuth(),
                  const SizedBox(height: 24),
                  _buildLoginLink(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crear cuenta',
              style: AppTextStyles.headlineLarge.copyWith(color: Colors.white),
            ),
            Text(
              'Únete a la comunidad ShinraCity',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn().slideX(begin: -0.1, end: 0);
  }

  Widget _buildAccountTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          _buildTypeTab('user', Icons.person_outline, 'Usuario'),
          _buildTypeTab('business', Icons.storefront_outlined, 'Negocio'),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildTypeTab(String type, IconData icon, String label) {
    final isSelected = _accountType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _accountType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.backgroundDark : AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.titleMedium.copyWith(
                  color: isSelected ? AppColors.backgroundDark : AppColors.textSecondaryDark,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          ShinraTextField(
            controller: _nameController,
            label: _accountType == 'business' ? 'Nombre del negocio' : 'Nombre completo',
            prefixIcon: _accountType == 'business' ? Icons.storefront_outlined : Icons.person_outline,
            validator: (v) {
              if (v?.isEmpty ?? true) return 'Ingresá tu nombre';
              if ((v?.length ?? 0) < 2) return 'Mínimo 2 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 16),
          ShinraTextField(
            controller: _emailController,
            label: 'Email',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v?.isEmpty ?? true) return 'Ingresá tu email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)) {
                return 'Email inválido';
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
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondaryDark,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v?.isEmpty ?? true) return 'Ingresá una contraseña';
              if ((v?.length ?? 0) < 8) return 'Mínimo 8 caracteres';
              if (!RegExp(r'(?=.*[A-Z])').hasMatch(v!)) {
                return 'Debe tener al menos una mayúscula';
              }
              if (!RegExp(r'(?=.*[0-9])').hasMatch(v)) {
                return 'Debe tener al menos un número';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ShinraTextField(
            controller: _confirmController,
            label: 'Confirmar contraseña',
            prefixIcon: Icons.lock_outlined,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleRegister(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondaryDark,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v != _passwordController.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTerms() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptTerms,
            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: AppColors.textSecondaryDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
              children: [
                const TextSpan(text: 'Acepto los '),
                TextSpan(
                  text: 'Términos de Servicio',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ' y la '),
                TextSpan(
                  text: 'Política de Privacidad',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return GradientButton(
          onPressed: (state is AuthLoading || !_acceptTerms) ? null : _handleRegister,
          isLoading: state is AuthLoading,
          child: Text(
            _accountType == 'business' ? 'Registrar mi negocio' : 'Crear cuenta',
          ),
        );
      },
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'O registrarse con',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
      ],
    );
  }

  Widget _buildSocialAuth() {
    return Row(
      children: [
        Expanded(
          child: SocialAuthButton(
            provider: 'Google',
            iconPath: 'assets/icons/google.svg',
            onPressed: () => context.read<AuthBloc>().add(SignInWithGoogleEvent()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SocialAuthButton(
            provider: 'Apple',
            iconPath: 'assets/icons/apple.svg',
            onPressed: () => context.read<AuthBloc>().add(SignInWithAppleEvent()),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildLoginLink(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿Ya tenés cuenta? ',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
          ),
          GestureDetector(
            onTap: () => context.go('/login'),
            child: Text(
              'Iniciar sesión',
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

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debés aceptar los Términos de Servicio'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(SignUpWithEmailEvent(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
      accountType: _accountType,
    ));
  }
}
