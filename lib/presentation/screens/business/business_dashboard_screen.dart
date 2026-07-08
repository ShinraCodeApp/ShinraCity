import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../services/ambulant_location_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../blocs/commerce/commerce_bloc.dart';
import '../../blocs/promotions/promotions_bloc.dart';
import '../../widgets/common/gradient_button.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  int _selectedPeriod = 7;
  File? _pendingLogoFile;

  @override
  void dispose() {
    AmbulantLocationService.instance.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    context.read<CommerceBloc>().add(LoadBusinessDashboard());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Mi Negocio'),
        backgroundColor: AppColors.backgroundCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<CommerceBloc, CommerceState>(
            listener: (context, state) {
              if (state is CommerceDashboardLoaded) {
                if (_pendingLogoFile != null) setState(() => _pendingLogoFile = null);
                context.read<PromotionsBloc>().add(
                  LoadCommercePromotions(commerceId: state.commerce.id),
                );
                if (state.commerce.isAmbulant) {
                  AmbulantLocationService.instance.start(state.commerce.id);
                } else {
                  AmbulantLocationService.instance.stop();
                }
              }
            },
          ),
          BlocListener<PromotionsBloc, PromotionsState>(
            listener: (context, state) {
              if (state is PromotionStatusChanged || state is PromotionDeleted) {
                final commerceState = context.read<CommerceBloc>().state;
                if (commerceState is CommerceDashboardLoaded) {
                  context.read<PromotionsBloc>().add(
                    LoadCommercePromotions(commerceId: commerceState.commerce.id),
                  );
                }
              }
              if (state is PromotionsError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
        child: BlocBuilder<CommerceBloc, CommerceState>(
          builder: (context, state) {
            if (state is CommerceLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (state is NoCommerceRegistered) {
              return _buildNoCommerceState(context);
            }
            if (state is CommerceDashboardLoaded) {
              return _buildDashboard(context, state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildNoCommerceState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront, size: 50, color: Colors.white),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              '¡Registrá tu negocio!',
              style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Conectá con miles de clientes cerca de tu local. Publicá ofertas, gestioná cupones y hacé crecer tu negocio.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GradientButton(
              onPressed: () => _showRegisterDialog(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_business, size: 20),
                  SizedBox(width: 8),
                  Text('Registrar mi comercio'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, CommerceDashboardLoaded state) {
    final commerce = state.commerce;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CommerceBloc>().add(LoadBusinessDashboard());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommerceHeader(commerce),
            const SizedBox(height: 20),
            _buildPlanBanner(commerce),
            const SizedBox(height: 20),
            _buildStatsOverview(state),
            const SizedBox(height: 20),
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildCouponsChart(state),
            const SizedBox(height: 20),
            _buildQuickActions(context, commerce),
            const SizedBox(height: 20),
            _buildRecentActivity(state),
            const SizedBox(height: 20),
            _buildAISuggestions(state),
            const SizedBox(height: 20),
            _buildPromotionsSection(context, state.commerce.id),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCommerceHeader(CommerceEntity commerce) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: GestureDetector(
            onTap: () => _pickLogo(commerce.id),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _pendingLogoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.file(_pendingLogoFile!, fit: BoxFit.cover),
                      )
                    : commerce.logoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child:
                                Image.network(commerce.logoUrl!, fit: BoxFit.cover),
                          )
                        : Center(
                            child: Text(
                              commerce.name[0],
                              style: AppTextStyles.headlineMedium
                                  .copyWith(color: AppColors.primary),
                            ),
                          ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    commerce.name,
                    style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  if (commerce.isVerified)
                    const Icon(Icons.verified, color: AppColors.primary, size: 16),
                ],
              ),
              Text(
                commerce.categoryDisplayName,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: commerce.isCurrentlyOpen
                ? AppColors.success.withValues(alpha: 0.15)
                : AppColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: commerce.isCurrentlyOpen ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                commerce.isCurrentlyOpen ? 'Abierto' : 'Cerrado',
                style: AppTextStyles.bodySmall.copyWith(
                  color: commerce.isCurrentlyOpen ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildPlanBanner(CommerceEntity commerce) {
    if (commerce.plan == CommercePlan.enterprise || commerce.plan == CommercePlan.premium) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mejorá tu plan',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Más visibilidad, estadísticas avanzadas y sin límites',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push(
              '/business/upgrade',
              extra: {
                'currentPlan': commerce.plan,
                'commerceId': commerce.id,
              },
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFFA500),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text('Mejorar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildStatsOverview(CommerceDashboardLoaded state) {
    final stats = state.stats;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatTile(
          '${stats['claimed'] ?? 0}',
          'Reclamados',
          Icons.confirmation_num,
          AppColors.primary,
          0,
        ),
        _buildStatTile(
          '${stats['redeemed'] ?? 0}',
          'Canjeados',
          Icons.check_circle_outline,
          AppColors.success,
          0,
        ),
        _buildStatTile(
          '${stats['conversionRate'] ?? 0}%',
          'Conversión',
          Icons.trending_up,
          AppColors.accent,
          0,
        ),
        _buildStatTile(
          '${stats['followerCount'] ?? 0}',
          'Seguidores',
          Icons.people,
          AppColors.accentGreen,
          0,
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildStatTile(
    String value,
    String label,
    IconData icon,
    Color color,
    double change,
  ) {
    final isPositive = change >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                    Text(
                      '${change.abs().toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: isPositive ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
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
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        Text(
          'Actividad',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        const Spacer(),
        ...([7, 14, 30]).map((days) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPeriod = days),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selectedPeriod == days
                        ? AppColors.primary
                        : AppColors.backgroundSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${days}d',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _selectedPeriod == days ? AppColors.backgroundDark : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildCouponsChart(CommerceDashboardLoaded state) {
    final allData = state.chartData;
    // Take the last _selectedPeriod days from the 30-day dataset
    final chartData = allData.length >= _selectedPeriod
        ? allData.sublist(allData.length - _selectedPeriod)
        : allData;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cupones canjeados',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFF1E293B),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'D${value.toInt() + 1}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondaryDark,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondaryDark,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      chartData.length,
                      (i) => FlSpot(i.toDouble(), chartData[i].toDouble()),
                    ),
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildQuickActions(BuildContext context, CommerceEntity commerce) {
    final actions = [
      (Icons.add_circle_outline, 'Nueva\npromoción', AppColors.primary,
          () => context.push('/commerce/${commerce.id}/create-promotion')),
      (Icons.qr_code_scanner, 'Escanear\ncupón', AppColors.secondary,
          () => context.push('/scan/${commerce.id}')),
      (Icons.bar_chart, 'Estadísticas\ncompletas', AppColors.accentGreen,
          () => context.push(
                '/commerce/${commerce.id}/stats',
                extra: {'commerceName': commerce.name},
              )),
      (Icons.people_outline, 'Empleados', AppColors.accent,
          () => context.push('/commerce/${commerce.id}/employees')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones rápidas',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.map((action) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: action.$4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: action.$3.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: action.$3.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(action.$1, color: action.$3, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          action.$2,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildRecentActivity(CommerceDashboardLoaded state) {
    final activity = state.recentActivity;
    if (activity.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actividad reciente',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activity.take(5).length,
            separatorBuilder: (_, __) => const Divider(
              color: Color(0xFF1E293B),
              height: 1,
              indent: 56,
            ),
            itemBuilder: (context, index) {
              final item = activity[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.confirmation_num, color: AppColors.primary, size: 18),
                ),
                title: Text(
                  item['title'] as String? ?? '',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
                subtitle: Text(
                  item['time'] as String? ?? '',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildAISuggestions(CommerceDashboardLoaded state) {
    final suggestions = state.aiSuggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Sugerencias IA',
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...suggestions.map((suggestion) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildPromotionsSection(BuildContext context, String commerceId) {
    return BlocBuilder<PromotionsBloc, PromotionsState>(
      builder: (context, state) {
        final promotions = state is PromotionsLoaded ? state.promotions : <PromotionEntity>[];
        final isLoading = state is PromotionsLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mis promociones',
                  style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/commerce/$commerceId/create-promotion'),
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: Text(
                    'Nueva',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (promotions.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.local_offer_outlined,
                          size: 40, color: AppColors.textSecondaryDark),
                      const SizedBox(height: 8),
                      Text(
                        'Sin promociones activas',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondaryDark),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: promotions.take(5).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _buildPromotionTile(context, promotions[i], commerceId),
              ),
            if (promotions.length > 5)
              TextButton(
                onPressed: () => context.push('/commerce/$commerceId/promotions'),
                child: Text(
                  'Ver todas (${promotions.length})',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                ),
              ),
          ],
        ).animate().fadeIn(delay: 650.ms);
      },
    );
  }

  Widget _buildPromotionTile(
    BuildContext context,
    PromotionEntity promotion,
    String commerceId,
  ) {
    final isActive = promotion.status == PromotionStatus.active;
    final isPaused = promotion.status == PromotionStatus.paused;
    final statusColor = isActive
        ? AppColors.success
        : isPaused
            ? AppColors.accent
            : AppColors.textSecondaryDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_offer, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _promotionStatusLabel(promotion.status),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${promotion.usedSlots}/${promotion.totalSlots ?? '∞'} usos',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryDark,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondaryDark, size: 20),
            color: AppColors.backgroundSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (action) => _handlePromotionAction(context, action, promotion, commerceId),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Editar', style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
                ]),
              ),
              PopupMenuItem(
                value: isActive ? 'pause' : 'activate',
                child: Row(children: [
                  Icon(
                    isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Pausar' : 'Activar',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                  ),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Eliminar', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handlePromotionAction(
    BuildContext context,
    String action,
    PromotionEntity promotion,
    String commerceId,
  ) {
    switch (action) {
      case 'edit':
        context.push(
          '/commerce/$commerceId/edit-promotion/${promotion.id}',
          extra: promotion,
        );
      case 'pause':
        context.read<PromotionsBloc>().add(ChangePromotionStatus(
          promotionId: promotion.id,
          status: PromotionStatus.paused,
        ));
      case 'activate':
        context.read<PromotionsBloc>().add(ChangePromotionStatus(
          promotionId: promotion.id,
          status: PromotionStatus.active,
        ));
      case 'delete':
        _confirmDeletePromotion(context, promotion);
    }
  }

  void _confirmDeletePromotion(BuildContext context, PromotionEntity promotion) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar promoción',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        content: Text(
          '¿Querés eliminar "${promotion.title}"? Esta acción no se puede deshacer.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PromotionsBloc>().add(DeletePromotion(promotion.id));
            },
            child: Text('Eliminar',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _promotionStatusLabel(PromotionStatus status) {
    switch (status) {
      case PromotionStatus.active: return 'Activa';
      case PromotionStatus.paused: return 'Pausada';
      case PromotionStatus.scheduled: return 'Programada';
      case PromotionStatus.expired: return 'Expirada';
      case PromotionStatus.cancelled: return 'Cancelada';
      case PromotionStatus.draft: return 'Borrador';
    }
  }

  Future<void> _pickLogo(String commerceId) async {
    final svc = GetIt.instance<ImageUploadService>();
    File? file;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: Text('Cámara',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
              onTap: () async {
                file = await svc.pickFromCamera(maxDim: 400);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('Galería',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
              onTap: () async {
                file = await svc.pickFromGallery(maxDim: 400);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );

    if (file == null || !mounted) return;
    setState(() => _pendingLogoFile = file);

    // Dispatch via BLoC — repository handles upload + Firestore update
    context.read<CommerceBloc>().add(
          UploadCommerceLogo(
            commerceId: commerceId,
            filePath: file!.path,
          ),
        );
  }

  Future<void> _showRegisterDialog(BuildContext context) async {
    final authState = context.read<AuthBloc>().state;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final isAdmin = authState is AuthAuthenticated &&
        (authState.user.role == UserRole.admin ||
            authState.user.role == UserRole.superAdmin);

    if (!isAdmin) {
      final existing = await FirebaseFirestore.instance
          .collection('commerces')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty && context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.backgroundCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Límite alcanzado',
                style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
            content: Text(
              'Tu cuenta ya tiene un negocio registrado. Para agregar un segundo local necesitás el plan Enterprise.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/plan-upgrade');
                },
                child: Text('Ver planes',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Registrar comercio',
            style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
        content: Text(
          'Para registrar tu comercio completá el formulario a continuación. '
          'Tu solicitud será revisada en un plazo de 24-48 horas.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/register-business');
            },
            child: Text('Solicitar registro',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
