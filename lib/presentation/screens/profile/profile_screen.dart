import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user_entity.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../admin/admin_panel_screen.dart';
import '../../widgets/profile/my_businesses_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) return const SizedBox.shrink();
          return _buildProfile(context, state.user);
        },
      ),
    );
  }

  Widget _buildProfile(BuildContext context, UserEntity user) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, user),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLevelCard(user),
                const SizedBox(height: 20),
                _buildStatsRow(user),
                const SizedBox(height: 20),
                _buildAchievementsSection(user),
                const SizedBox(height: 20),
                _buildMenuSection(context, user),
                const SizedBox(height: 20),
                MyBusinessesSection(user: user),
                const SizedBox(height: 20),
                _buildShareSection(context),
                const SizedBox(height: 20),
                _buildAboutSection(),
                const SizedBox(height: 32),
                _buildFooter(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context, UserEntity user) {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.backgroundCard,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          tooltip: 'Editar perfil',
          onPressed: () => context.push('/profile/edit'),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1B2A), AppColors.backgroundCard],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: user.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: user.photoUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.backgroundSurface,
                              child: Center(
                                child: Text(
                                  (user.displayName ?? user.email)[0].toUpperCase(),
                                  style: AppTextStyles.displayMedium.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _getLevelColor(user.level),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.backgroundCard, width: 2),
                      ),
                      child: const Icon(Icons.star, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName ?? 'Usuario',
                style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getLevelColor(user.level).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getLevelColor(user.level).withOpacity(0.3)),
                ),
                child: Text(
                  user.levelDisplayName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _getLevelColor(user.level),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(UserEntity user) {
    final progress = user.levelProgress;
    final nextLevelPoints = user.nextLevelPoints;
    final currentPoints = user.totalPoints;
    final levelColor = _getLevelColor(user.level);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            levelColor.withOpacity(0.15),
            levelColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: levelColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user.levelDisplayName,
                style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
              ),
              Row(
                children: [
                  Icon(Icons.stars, color: levelColor, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${currentPoints.toString()} pts',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: levelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          StepProgressIndicator(
            totalSteps: 100,
            currentStep: (progress * 100).toInt().clamp(0, 100),
            size: 8,
            padding: 0,
            selectedColor: levelColor,
            unselectedColor: levelColor.withOpacity(0.2),
            roundedEdges: const Radius.circular(4),
          ),
          const SizedBox(height: 8),
          if (user.level != UserLevel.lifetime)
            Text(
              '${(nextLevelPoints - currentPoints).clamp(0, nextLevelPoints)} pts para el siguiente nivel',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
            )
          else
            Text(
              '¡Nivel máximo alcanzado!',
              style: AppTextStyles.bodySmall.copyWith(color: levelColor),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildStatsRow(UserEntity user) {
    return Row(
      children: [
        _buildStatCard('Cupones', user.totalCouponsRedeemed.toString(), Icons.confirmation_num),
        const SizedBox(width: 12),
        _buildStatCard('Ahorros', '\$${user.totalSavings}', Icons.savings),
        const SizedBox(width: 12),
        _buildStatCard('Puntos', user.availablePoints.toString(), Icons.stars),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(UserEntity user) {
    if (user.achievementIds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logros recientes',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: user.achievementIds.take(5).length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildAchievementBadge(user.achievementIds[index]);
            },
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildAchievementBadge(String achievementId) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.emoji_events, color: Colors.white, size: 32),
    );
  }

  Widget _buildMenuSection(BuildContext context, UserEntity user) {
    final menuItems = [
      (Icons.favorite_outline, 'Favoritos', '/favorites'),
      (Icons.storefront_outlined, 'Comercios seguidos', '/following'),
      (Icons.history, 'Historial de cupones', '/coupon-history'),
      (Icons.card_giftcard_outlined, 'Mis recompensas', '/rewards'),
      (Icons.leaderboard_outlined, 'Ranking', '/leaderboard'),
      (Icons.settings_outlined, 'Configuración', '/settings'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mi cuenta',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            children: [
              // Notifications tile with unread badge
              _buildNotificationsTile(context, user.id),
              const Divider(color: Color(0xFF1E293B), height: 1, indent: 56),
              ...menuItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(item.$1, color: AppColors.primary, size: 22),
                      title: Text(
                        item.$2,
                        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.textSecondaryDark,
                        size: 14,
                      ),
                      onTap: () => context.push(item.$3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    ),
                    if (i < menuItems.length - 1)
                      Divider(
                        color: const Color(0xFF1E293B),
                        height: 1,
                        indent: 56,
                      ),
                  ],
                );
              }),
              if (user.role == UserRole.admin || user.role == UserRole.superAdmin) ...[
                const Divider(color: Color(0xFF1E293B), height: 1, indent: 0),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: AppColors.error, size: 18),
                  ),
                  title: Text(
                    'Panel de Administración',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ADMIN',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                ),
              ],
              const Divider(color: Color(0xFF1E293B), height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error, size: 22),
                title: Text(
                  'Cerrar sesión',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                ),
                onTap: () {
                  context.read<AuthBloc>().add(SignOutEvent());
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  static const _appUrl = 'https://shinra-city.web.app';

  Widget _buildShareSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compartir app',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: _appUrl,
                      version: QrVersions.auto,
                      size: 120,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escaneá el QR',
                          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Compartí ShinraCity con tus amigos y descubran juntos las mejores ofertas.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Share.share(
                                  '¡Descubrí ShinraCity! La app de ofertas y comercios cerca tuyo.\n$_appUrl',
                                  subject: 'ShinraCity - Ofertas cerca tuyo',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.share, color: Colors.black, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Compartir',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(const ClipboardData(text: _appUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enlace copiado al portapapeles'),
                                    backgroundColor: AppColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF1E293B)),
                                ),
                                child: const Icon(Icons.copy, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 450.ms);
  }

  Widget _buildAboutSection() {
    const items = [
      (Icons.map_outlined, 'Mapa en tiempo real',
          'Explorá el mapa y encontrá comercios activos cerca de tu ubicación. Los marcadores anaranjados indican ofertas activas.'),
      (Icons.local_offer_outlined, 'Cupones de descuento',
          'Al acercarte a un comercio, podés reclamar cupones exclusivos con descuentos y beneficios especiales.'),
      (Icons.stars_outlined, 'Sistema de puntos',
          'Ganás puntos por cada cupón que usás. Acumulalos para subir de nivel: Explorador → Frecuente → Ejemplar → Embajador → Vitalicio.'),
      (Icons.card_giftcard_outlined, 'Recompensas',
          'Canjeá tus puntos por recompensas en los comercios: descuentos, productos gratis, y beneficios exclusivos.'),
      (Icons.notifications_active_outlined, 'Alertas de proximidad',
          'Recibís notificaciones automáticas cuando hay ofertas activas cerca tuyo. Activá el GPS para no perderte ninguna.'),
      (Icons.business_outlined, '¿Tenés un negocio?',
          'Registrá tu comercio, creá promociones y llegá a clientes que estén cerca. Gestionalo desde el panel de negocios.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cómo funciona',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.$1, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.$3,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondaryDark,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < items.length - 1)
                    const Divider(color: Color(0xFF1E293B), height: 1, indent: 74),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Color(0xFF1E293B)),
        const SizedBox(height: 24),
        Image.asset(
          'assets/ShinraCodeLogo1.png',
          height: 80,
        ),
        const SizedBox(height: 12),
        Text(
          'Programador: Yami.D.Rueda.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryDark,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ShinraCity v1.0.0',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryDark.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildNotificationsTile(BuildContext context, String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unread = snapshot.data?.docs.length ?? 0;
        return ListTile(
          leading: const Icon(Icons.notifications_outlined,
              color: AppColors.primary, size: 22),
          title: Text(
            'Notificaciones',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios,
                  color: AppColors.textSecondaryDark, size: 14),
            ],
          ),
          onTap: () => context.push('/notifications'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        );
      },
    );
  }

  Color _getLevelColor(UserLevel level) {
    switch (level) {
      case UserLevel.explorer: return AppColors.levelExplorer;
      case UserLevel.frequent: return AppColors.levelFrequent;
      case UserLevel.exemplary: return AppColors.levelExemplary;
      case UserLevel.ambassador: return AppColors.levelAmbassador;
      case UserLevel.lifetime: return AppColors.levelLifetime;
    }
  }
}
