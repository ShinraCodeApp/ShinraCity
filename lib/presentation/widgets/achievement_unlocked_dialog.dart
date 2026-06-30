import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/achievement_entity.dart';

class AchievementUnlockedDialog extends StatelessWidget {
  final UserAchievementEntity userAchievement;

  const AchievementUnlockedDialog({super.key, required this.userAchievement});

  static Future<void> show(BuildContext context, UserAchievementEntity ua) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AchievementUnlockedDialog(userAchievement: ua),
    );
  }

  @override
  Widget build(BuildContext context) {
    final achievement = userAchievement.achievement;
    final rarityColors = {
      BadgeRarity.common: Colors.grey,
      BadgeRarity.uncommon: AppColors.success,
      BadgeRarity.rare: AppColors.primary,
      BadgeRarity.epic: AppColors.secondary,
      BadgeRarity.legendary: AppColors.gold,
    };
    final color = rarityColors[achievement.rarity] ?? AppColors.gold;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBadge(color).animate().scale(
              begin: const Offset(0.3, 0.3),
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
            const SizedBox(height: 20),
            Text(
              '¡Logro desbloqueado!',
              style: AppTextStyles.titleMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              style: AppTextStyles.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 500.ms).fadeIn(),
            if (achievement.pointsReward > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: AppColors.gold, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '+${achievement.pointsReward} puntos',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 600.ms).fadeIn().scale(),
            ],
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '¡Genial!',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ).animate(delay: 700.ms).fadeIn().slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.05),
          ),
        ),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
        ),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            Icons.emoji_events,
            color: color,
            size: 36,
          ),
        ),
      ],
    );
  }
}
