import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../blocs/auth/auth_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Configuración',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state is AuthAuthenticated ? state.user : null;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSection('Cuenta', [
                _buildNavTile(
                  icon: Icons.person_outline,
                  label: 'Editar perfil',
                  onTap: () => context.push('/profile/edit'),
                ),
                _buildNavTile(
                  icon: Icons.lock_outline,
                  label: 'Cambiar contraseña',
                  onTap: () => _sendPasswordReset(context, user?.email),
                  enabled: user?.authProvider == AuthProvider.email,
                  note: user?.authProvider != AuthProvider.email
                      ? 'Usás ${_providerLabel(user?.authProvider)}'
                      : null,
                ),
              ]).animate().fadeIn().slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),

              _buildSection('Notificaciones', [
                _buildSwitchTile(
                  icon: Icons.local_offer_outlined,
                  label: 'Promociones cercanas',
                  subtitle: 'Alertas cuando hay promos a tu alrededor',
                  value: user?.notificationsEnabled ?? true,
                  onChanged: (v) => context
                      .read<AuthBloc>()
                      .add(UpdateSettingsEvent(notificationsEnabled: v)),
                ),
                _buildSwitchTile(
                  icon: Icons.confirmation_num_outlined,
                  label: 'Cupones por vencer',
                  subtitle: 'Recordatorio 24hs antes del vencimiento',
                  value: user?.notificationsEnabled ?? true,
                  onChanged: (v) => context
                      .read<AuthBloc>()
                      .add(UpdateSettingsEvent(notificationsEnabled: v)),
                ),
                _buildSwitchTile(
                  icon: Icons.emoji_events_outlined,
                  label: 'Logros y nivel',
                  subtitle: 'Cuando desbloqueás un logro o subís de nivel',
                  value: user?.notificationsEnabled ?? true,
                  onChanged: (v) => context
                      .read<AuthBloc>()
                      .add(UpdateSettingsEvent(notificationsEnabled: v)),
                ),
              ]).animate(delay: 80.ms).fadeIn().slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),

              _buildSection('Privacidad', [
                _buildSwitchTile(
                  icon: Icons.location_on_outlined,
                  label: 'Compartir ubicación',
                  subtitle: 'Necesario para mostrar comercios cercanos',
                  value: user?.locationEnabled ?? true,
                  onChanged: (v) => context
                      .read<AuthBloc>()
                      .add(UpdateSettingsEvent(locationEnabled: v)),
                ),
                _buildNavTile(
                  icon: Icons.shield_outlined,
                  label: 'Política de privacidad',
                  onTap: () => _launchUrl('https://shinracity.app/privacy'),
                ),
                _buildNavTile(
                  icon: Icons.description_outlined,
                  label: 'Términos y condiciones',
                  onTap: () => _launchUrl('https://shinracity.app/terms'),
                ),
              ]).animate(delay: 160.ms).fadeIn().slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),

              _buildSection('Soporte', [
                _buildNavTile(
                  icon: Icons.help_outline,
                  label: 'Centro de ayuda',
                  onTap: () => _launchUrl('https://shinracity.app/help'),
                ),
                _buildNavTile(
                  icon: Icons.bug_report_outlined,
                  label: 'Reportar un problema',
                  onTap: () => _launchUrl('mailto:soporte@shinracity.app'),
                ),
                _buildNavTile(
                  icon: Icons.star_outline,
                  label: 'Calificar la app',
                  onTap: () => _launchUrl('https://shinracity.app/rate'),
                ),
              ]).animate(delay: 240.ms).fadeIn().slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),

              _buildSection('Zona peligrosa', [
                _buildNavTile(
                  icon: Icons.logout,
                  label: 'Cerrar sesión',
                  labelColor: AppColors.error,
                  iconColor: AppColors.error,
                  onTap: () => _confirmSignOut(context),
                ),
                _buildNavTile(
                  icon: Icons.delete_forever_outlined,
                  label: 'Eliminar cuenta',
                  labelColor: AppColors.error,
                  iconColor: AppColors.error,
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ]).animate(delay: 320.ms).fadeIn().slideY(begin: 0.05, end: 0),

              const SizedBox(height: 32),

              Center(
                child: Column(
                  children: [
                    Text(
                      'ShinraCity',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textSecondaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Versión $_appVersion',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondaryDark,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(children: content),
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? note,
    Color? labelColor,
    Color? iconColor,
    bool enabled = true,
  }) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      title: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: enabled
              ? (labelColor ?? Colors.white)
              : AppColors.textSecondaryDark,
        ),
      ),
      subtitle: note != null
          ? Text(note,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondaryDark))
          : null,
      trailing: const Icon(Icons.arrow_forward_ios,
          color: AppColors.textSecondaryDark, size: 14),
      onTap: enabled ? onTap : null,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(label,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
      subtitle: Text(subtitle,
          style: AppTextStyles.labelSmall
              .copyWith(color: AppColors.textSecondaryDark)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
    );
  }

  Future<void> _sendPasswordReset(BuildContext ctx, String? email) async {
    if (email == null) return;
    ctx.read<AuthBloc>().add(SendPasswordResetEvent(email: email));
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('Email de recuperación enviado a $email'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmSignOut(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text('Cerrar sesión',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
        content: Text('¿Estás seguro?',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondaryDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancelar',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ctx.read<AuthBloc>().add(SignOutEvent());
            },
            child: Text('Salir',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text('Eliminar cuenta',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
        content: Text(
          'Esta acción es irreversible. Se eliminarán todos tus datos, cupones y puntos.',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancelar',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ctx.read<AuthBloc>().add(DeleteAccountEvent());
            },
            child: Text('Eliminar',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _providerLabel(AuthProvider? provider) {
    switch (provider) {
      case AuthProvider.google:
        return 'Google';
      case AuthProvider.apple:
        return 'Apple';
      case AuthProvider.facebook:
        return 'Facebook';
      default:
        return 'OAuth';
    }
  }
}
