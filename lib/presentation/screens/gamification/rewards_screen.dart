import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/achievement_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../blocs/points/points_bloc.dart';
import '../../widgets/achievement_unlocked_dialog.dart';
import '../../widgets/common/gradient_button.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _userPoints = 0;
  List<RewardEntity>? _availableRewards;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<PointsBloc>().add(const LoadUserPoints());
    context.read<PointsBloc>().add(const LoadAvailableRewards());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: BlocListener<PointsBloc, PointsState>(
        listener: (context, state) {
          if (state is PointsDashboardLoaded) {
            setState(() => _userPoints = state.points);
          }
          if (state is RewardsListLoaded) {
            setState(() => _availableRewards = state.rewards);
          }
          if (state is RewardRedeemed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Recompensa canjeada con éxito!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<PointsBloc>().add(const LoadUserPoints());
            context.read<PointsBloc>().add(const LoadAvailableRewards());
          }
          if (state is AchievementUnlocked) {
            AchievementUnlockedDialog.show(context, state.achievement);
          }
          if (state is PointsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            _buildHeader(),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildRewardsTab(),
              _buildHistoryTab(),
              _buildAchievementsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      flexibleSpace: FlexibleSpaceBar(
        background: BlocBuilder<PointsBloc, PointsState>(
          builder: (context, state) {
            int points = _userPoints;
            String levelName = 'Explorador';
            double progress = 0.0;
            int nextLevel = 500;

            if (state is PointsDashboardLoaded) {
              points = state.points;
              levelName = state.level.levelDisplayName;
              progress = state.level.levelProgress(points);
              nextLevel = state.level.nextLevelPoints ?? points;
            }

            return Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Mis Puntos',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$points pts',
                        style: AppTextStyles.displayMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            levelName,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          if (nextLevel > points)
                            Text(
                              '${nextLevel - points} pts para el siguiente nivel',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Recompensas'),
          Tab(text: 'Historial'),
          Tab(text: 'Logros'),
        ],
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondaryDark,
        labelStyle: AppTextStyles.titleSmall,
      ),
    );
  }

  Widget _buildRewardsTab() {
    if (_availableRewards == null) return _buildShimmer();
    if (_availableRewards!.isEmpty) {
      return _buildEmpty('Sin recompensas disponibles', Icons.card_giftcard_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _availableRewards!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildRewardCard(_availableRewards![i]),
    );
  }

  Widget _buildRewardCard(RewardEntity reward) {
    final canAfford = _userPoints >= reward.pointsCost;
    final isAvailable = reward.isAvailable;
    final commerceName =
        reward.metadata['commerceName'] as String? ?? 'Comercio';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canAfford && isAvailable
              ? AppColors.gold.withValues(alpha: 0.3)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: reward.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(reward.imageUrl!, fit: BoxFit.cover),
                  )
                : Icon(
                    Icons.card_giftcard,
                    color: AppColors.gold.withValues(alpha: 0.6),
                    size: 32,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  commerceName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      '${reward.pointsCost} pts',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: canAfford
                            ? AppColors.gold
                            : AppColors.textSecondaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isAvailable) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Agotado',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            height: 36,
            child: GradientButton(
              onPressed: canAfford && isAvailable
                  ? () => _showRedeemConfirm(reward)
                  : null,
              height: 36,
              child: const Text('Canjear', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildHistoryTab() {
    return BlocBuilder<PointsBloc, PointsState>(
      builder: (context, state) {
        if (state is PointsHistoryLoading) return _buildShimmer();
        if (state is PointsHistoryLoaded) {
          if (state.history.isEmpty) {
            return _buildEmpty('Sin transacciones aún', Icons.history);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.history.length,
            itemBuilder: (_, i) => _buildHistoryTile(state.history[i]),
          );
        }
        return _buildEmpty('Sin historial', Icons.history);
      },
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> tx) {
    final isEarned = (tx['type'] as String?) == 'earned';
    final points = (tx['points'] as int?) ?? 0;
    final createdAt = tx['createdAt'];
    String dateStr = '';
    if (createdAt != null) {
      final dt = createdAt is DateTime ? createdAt : DateTime.now();
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isEarned ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEarned ? Icons.add : Icons.remove,
              color: isEarned ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['reason'] as String? ?? 'Transacción',
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
                Text(
                  dateStr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isEarned ? '+' : ''}$points pts',
            style: AppTextStyles.titleSmall.copyWith(
              color: isEarned ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab() {
    return BlocBuilder<PointsBloc, PointsState>(
      builder: (context, state) {
        if (state is PointsLoading) return _buildShimmer();

        List<dynamic> all = [];
        Set<String> unlocked = {};

        if (state is AchievementsLoaded) {
          all = state.all;
          unlocked = state.unlocked.map((u) => u.achievementId).toSet();
        }

        if (all.isEmpty) {
          return _buildEmpty(
              'Sin logros disponibles', Icons.emoji_events_outlined);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: all.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final a = all[i];
            final isUnlocked = unlocked.contains(a.id);
            return _buildAchievementTile(a, isUnlocked);
          },
        );
      },
    );
  }

  Widget _buildAchievementTile(dynamic achievement, bool isUnlocked) {
    final rarityColors = {
      'common': Colors.grey,
      'uncommon': AppColors.success,
      'rare': AppColors.primary,
      'epic': AppColors.secondary,
      'legendary': AppColors.gold,
    };
    final rarityName = achievement.rarity?.name ?? 'common';
    final color = rarityColors[rarityName] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isUnlocked ? color.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: 300.ms,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? color.withValues(alpha: 0.15)
                  : AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(12),
              border: isUnlocked ? Border.all(color: color) : null,
            ),
            child: Icon(
              Icons.emoji_events,
              color: isUnlocked
                  ? color
                  : AppColors.textSecondaryDark.withValues(alpha: 0.5),
              size: 24,
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
                      achievement.title ?? '',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: isUnlocked
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rarityName,
                        style:
                            AppTextStyles.labelSmall.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            const Icon(Icons.check_circle, color: AppColors.success, size: 20)
          else if (achievement.pointsReward != null &&
              achievement.pointsReward > 0)
            Text(
              '+${achievement.pointsReward}',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.gold),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 56, color: AppColors.textSecondaryDark.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.backgroundCard,
      highlightColor: AppColors.backgroundSurface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showRedeemConfirm(RewardEntity reward) {
    final bloc = context.read<PointsBloc>();
    final commerceName =
        reward.metadata['commerceName'] as String? ?? 'Comercio';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 20),
            const Icon(Icons.card_giftcard, color: AppColors.gold, size: 48),
            const SizedBox(height: 12),
            Text(
              reward.title,
              style:
                  AppTextStyles.headlineSmall.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              commerceName,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Costo',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondaryDark)),
                  Text(
                    '${reward.pointsCost} pts',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Saldo restante',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondaryDark)),
                  Text(
                    '${_userPoints - reward.pointsCost} pts',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              onPressed: () {
                Navigator.pop(ctx);
                bloc.add(RedeemReward(
                  rewardId: reward.id,
                  commerceId: reward.commerceId,
                ));
              },
              child: const Text('Confirmar canje'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondaryDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
