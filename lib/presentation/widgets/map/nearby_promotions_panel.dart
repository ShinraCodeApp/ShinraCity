import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../blocs/map/map_bloc.dart';

class NearbyPromotionsPanel extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(String commerceId) onPromotionTap;

  const NearbyPromotionsPanel({
    super.key,
    required this.onClose,
    required this.onPromotionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildHandle(),
          const SizedBox(height: 12),
          _buildHeader(context),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<MapBloc, MapState>(
              builder: (context, state) {
                if (state is MapLoaded && state.promotions.isNotEmpty) {
                  return _buildPromotionsList(state.promotions);
                }
                return _buildEmptyState();
              },
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_offer, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            'Ofertas cercanas',
            style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondaryDark),
            onPressed: onClose,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsList(List<PromotionEntity> promotions) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: promotions.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        return _buildPromotionCard(promotions[index])
            .animate()
            .fadeIn(delay: Duration(milliseconds: index * 100))
            .slideX(begin: 0.2, end: 0);
      },
    );
  }

  Widget _buildPromotionCard(PromotionEntity promotion) {
    return GestureDetector(
      onTap: () => onPromotionTap(promotion.commerceId),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: promotion.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: promotion.imageUrls.first,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 100,
                      color: AppColors.backgroundDark,
                      child: const Center(
                        child: Icon(Icons.local_offer, color: AppColors.textSecondaryDark, size: 32),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promotion.commerceName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promotion.title,
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (promotion.discountType == DiscountType.percentage)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-${promotion.discountValue.toInt()}%',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: AppColors.textSecondaryDark, size: 40),
          const SizedBox(height: 8),
          Text(
            'No hay ofertas cerca',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }
}
