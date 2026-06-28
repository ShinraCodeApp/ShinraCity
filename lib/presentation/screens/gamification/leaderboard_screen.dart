import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/points/points_bloc.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<PointsBloc>().add(const LoadLeaderboard());
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
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        centerTitle: false,
        title: Text(
          'Leaderboard',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Global'), Tab(text: 'Logros')],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGlobalTab(),
          _buildAchievementsTab(),
        ],
      ),
    );
  }

  Widget _buildGlobalTab() {
    return BlocBuilder<PointsBloc, PointsState>(
      builder: (context, state) {
        if (state is LeaderboardLoading) return _buildShimmer();
        if (state is LeaderboardLoaded) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTopThree(state.entries, state.currentUserId)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    if (i >= 3 && i < state.entries.length) {
                      return _buildEntry(state.entries[i], state.currentUserId);
                    }
                    return null;
                  },
                  childCount: state.entries.length,
                ),
              ),
            ],
          );
        }
        if (state is PointsError) {
          return Center(
            child: Text(state.message, style: const TextStyle(color: Colors.white)),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTopThree(List<Map<String, dynamic>> entries, String currentUserId) {
    if (entries.length < 3) return const SizedBox(height: 20);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundCard,
            AppColors.backgroundDark,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildPodiumCard(entries[1], 2, currentUserId, height: 100)),
          Expanded(child: _buildPodiumCard(entries[0], 1, currentUserId, height: 130)),
          Expanded(child: _buildPodiumCard(entries[2], 3, currentUserId, height: 80)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05, end: 0);
  }

  Widget _buildPodiumCard(
    Map<String, dynamic> entry,
    int rank,
    String currentUserId, {
    required double height,
  }) {
    final isCurrentUser = entry['userId'] == currentUserId;
    final rankColors = [AppColors.gold, Colors.grey.shade400, const Color(0xFFCD7F32)];
    final rankColor = rankColors[rank - 1];

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 36 : 28,
              backgroundColor: AppColors.backgroundSurface,
              backgroundImage: entry['photoUrl'] != null
                  ? NetworkImage(entry['photoUrl'])
                  : null,
              child: entry['photoUrl'] == null
                  ? Text(
                      (entry['displayName'] as String? ?? '?').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: rank == 1 ? 24 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            if (isCurrentUser)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          (entry['displayName'] as String? ?? 'Usuario').split(' ').first,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${entry['totalPoints'] ?? 0} pts',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: rankColor.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: AppTextStyles.headlineSmall.copyWith(
                color: rankColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntry(Map<String, dynamic> entry, String currentUserId) {
    final isCurrentUser = entry['userId'] == currentUserId;
    final level = entry['level'] as String? ?? 'explorer';
    final levelColor = _levelColor(level);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? AppColors.primary.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry['rank']}',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textSecondaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.backgroundSurface,
            backgroundImage: entry['photoUrl'] != null
                ? NetworkImage(entry['photoUrl'])
                : null,
            child: entry['photoUrl'] == null
                ? Text(
                    (entry['displayName'] as String? ?? '?').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry['displayName'] as String? ?? 'Usuario',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Tú',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: levelColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _levelName(level),
                      style: AppTextStyles.labelSmall.copyWith(color: levelColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry['totalPoints'] ?? 0}',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'puntos',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: entry['rank'] * 30)).fadeIn().slideX(begin: 0.05);
  }

  Widget _buildAchievementsTab() {
    return BlocBuilder<PointsBloc, PointsState>(
      builder: (context, state) {
        if (state is PointsLoading) return _buildShimmer();
        if (state is AchievementsLoaded) {
          final unlocked = state.unlocked.map((u) => u.achievementId).toSet();
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: state.all.length,
            itemBuilder: (_, i) {
              final achievement = state.all[i];
              final isUnlocked = unlocked.contains(achievement.id);
              return _buildAchievementCard(achievement, isUnlocked, i);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAchievementCard(dynamic achievement, bool isUnlocked, int index) {
    final rarityColors = {
      'common': Colors.grey,
      'uncommon': AppColors.success,
      'rare': AppColors.primary,
      'epic': AppColors.secondary,
      'legendary': AppColors.gold,
    };
    final color = rarityColors[achievement.rarity?.name ?? 'common'] ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked ? color.withOpacity(0.5) : Colors.white12,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedOpacity(
            duration: 300.ms,
            opacity: isUnlocked ? 1.0 : 0.3,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked ? color.withOpacity(0.15) : AppColors.backgroundSurface,
                border: isUnlocked ? Border.all(color: color, width: 1.5) : null,
              ),
              child: Icon(
                Icons.emoji_events,
                color: isUnlocked ? color : AppColors.textSecondaryDark,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              achievement.title ?? '',
              style: AppTextStyles.labelSmall.copyWith(
                color: isUnlocked ? Colors.white : AppColors.textSecondaryDark,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (achievement.pointsReward != null && achievement.pointsReward > 0) ...[
            const SizedBox(height: 4),
            Text(
              '+${achievement.pointsReward} pts',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.gold),
            ),
          ],
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.backgroundCard,
      highlightColor: AppColors.backgroundSurface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (_, __) => Container(
          height: 60,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    const colors = {
      'explorer': Colors.grey,
      'frequent': AppColors.primary,
      'exemplary': AppColors.success,
      'ambassador': AppColors.secondary,
      'lifetime': AppColors.gold,
    };
    return colors[level] ?? Colors.grey;
  }

  String _levelName(String level) {
    const names = {
      'explorer': 'Explorador',
      'frequent': 'Frecuente',
      'exemplary': 'Ejemplar',
      'ambassador': 'Embajador',
      'lifetime': 'Lifetime Partner',
    };
    return names[level] ?? level;
  }
}
