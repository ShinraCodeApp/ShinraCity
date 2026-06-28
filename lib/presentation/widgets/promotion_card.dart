import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/promotion_entity.dart';

class PromotionCard extends StatelessWidget {
  final PromotionEntity promotion;
  final VoidCallback? onTap;
  final VoidCallback? onClaim;
  final bool compact;

  const PromotionCard({
    super.key,
    required this.promotion,
    this.onTap,
    this.onClaim,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: promotion.isVip
                ? AppColors.gold.withOpacity(0.4)
                : const Color(0xFF1E293B),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: compact ? _buildCompact() : _buildFull(),
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildFull() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageHeader(),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBadgeRow(),
              const SizedBox(height: 8),
              Text(
                promotion.title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                promotion.commerceName,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 10),
              _buildFooter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompact() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildDiscountBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.title,
                  style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  promotion.commerceName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                _buildTimeRemaining(),
              ],
            ),
          ),
          if (onClaim != null && promotion.hasAvailableSlots)
            _buildClaimButton(),
        ],
      ),
    );
  }

  Widget _buildImageHeader() {
    return Stack(
      children: [
        SizedBox(
          height: 140,
          width: double.infinity,
          child: promotion.imageUrls.isNotEmpty
              ? Image.network(
                  promotion.imageUrls.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                )
              : _buildImagePlaceholder(),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: _buildDiscountBadge(),
        ),
        if (promotion.isVip)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'VIP',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.backgroundSurface,
      child: Center(
        child: Icon(
          _typeIcon(),
          color: AppColors.primary.withOpacity(0.4),
          size: 48,
        ),
      ),
    );
  }

  Widget _buildDiscountBadge() {
    final text = promotion.discountType == DiscountType.percentage
        ? '-${promotion.discountValue.toStringAsFixed(0)}%'
        : promotion.discountType == DiscountType.fixedAmount
            ? '-\$${promotion.discountValue.toStringAsFixed(0)}'
            : promotion.type.name.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildBadgeRow() {
    return Wrap(
      spacing: 6,
      children: [
        if (promotion.isExclusiveForFollowers)
          _chip('Solo seguidores', AppColors.primary),
        if (promotion.remainingSlots != null && promotion.remainingSlots! < 10)
          _chip('¡Últimos ${promotion.remainingSlots}!', AppColors.error),
        if (promotion.pointsAwarded != null && promotion.pointsAwarded! > 0)
          _chip('+${promotion.pointsAwarded} pts', AppColors.gold),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTimeRemaining(),
        if (onClaim != null && promotion.hasAvailableSlots) _buildClaimButton(),
      ],
    );
  }

  Widget _buildTimeRemaining() {
    final remaining = promotion.timeRemaining;
    Color color;
    if (remaining.inHours < 2) {
      color = AppColors.error;
    } else if (remaining.inHours < 24) {
      color = AppColors.warning;
    } else {
      color = AppColors.textSecondaryDark;
    }

    String text;
    if (remaining.inHours < 1) {
      text = '${remaining.inMinutes}min';
    } else if (remaining.inHours < 24) {
      text = '${remaining.inHours}h';
    } else {
      text = '${remaining.inDays}d';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _buildClaimButton() {
    return GestureDetector(
      onTap: onClaim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Canjear',
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  IconData _typeIcon() {
    switch (promotion.type) {
      case PromotionType.discount:
        return Icons.local_offer;
      case PromotionType.twoForOne:
        return Icons.redeem;
      case PromotionType.freeItem:
        return Icons.card_giftcard;
      case PromotionType.happyHour:
        return Icons.wine_bar;
      case PromotionType.cashback:
        return Icons.attach_money;
      case PromotionType.fidelity:
        return Icons.loyalty;
      default:
        return Icons.local_offer;
    }
  }
}
