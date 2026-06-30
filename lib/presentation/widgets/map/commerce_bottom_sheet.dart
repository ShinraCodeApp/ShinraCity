import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../blocs/map/map_bloc.dart';

class CommerceBottomSheet extends StatelessWidget {
  final String commerceId;
  final LatLng userLocation;
  final VoidCallback onClose;

  const CommerceBottomSheet({
    super.key,
    required this.commerceId,
    required this.userLocation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        if (state is! MapLoaded || state.selectedCommerce == null) {
          return const SizedBox.shrink();
        }

        final commerce = state.selectedCommerce!;
        return _buildSheet(context, commerce);
      },
    );
  }

  Widget _buildSheet(BuildContext context, CommerceEntity commerce) {
    final distance = GeoUtils.calculateDistance(userLocation, commerce.location);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, commerce, distance),
                const SizedBox(height: 16),
                _buildStats(commerce),
                const SizedBox(height: 16),
                if (commerce.hasActivePromotion) _buildActivePromotion(),
                const SizedBox(height: 16),
                _buildActions(context, commerce),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildHeader(BuildContext context, CommerceEntity commerce, double distance) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: commerce.logoUrl != null
              ? CachedNetworkImage(
                  imageUrl: commerce.logoUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildLogoFallback(commerce),
                )
              : _buildLogoFallback(commerce),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      commerce.name,
                      style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (commerce.isVerified)
                    const Icon(Icons.verified, color: AppColors.primary, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                commerce.categoryDisplayName,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: commerce.isCurrentlyOpen
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.error.withOpacity(0.15),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.location_on, size: 14, color: AppColors.textSecondaryDark),
                  const SizedBox(width: 2),
                  Text(
                    GeoUtils.formatDistance(distance),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondaryDark),
          onPressed: onClose,
        ),
      ],
    );
  }

  Widget _buildLogoFallback(CommerceEntity commerce) {
    return Container(
      width: 64,
      height: 64,
      color: AppColors.backgroundSurface,
      child: Center(
        child: Text(
          commerce.name[0].toUpperCase(),
          style: AppTextStyles.headlineLarge.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildStats(CommerceEntity commerce) {
    return Row(
      children: [
        _buildStatItem(
          icon: Icons.star,
          value: commerce.rating.toStringAsFixed(1),
          label: '${commerce.reviewCount} reseÃ±as',
          color: AppColors.accent,
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          icon: Icons.people,
          value: commerce.followerCount.toString(),
          label: 'seguidores',
          color: AppColors.primary,
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          icon: Icons.local_offer,
          value: commerce.activePromotionsCount.toString(),
          label: 'promociones',
          color: AppColors.secondary,
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePromotion() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.15),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: AppColors.secondary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Â¡Hay ofertas activas!',
                  style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                ),
                Text(
                  'VisitÃ¡ el local y reclamÃ¡ tu cupÃ³n',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondaryDark, size: 14),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, CommerceEntity commerce) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/commerce/${commerce.id}'),
            icon: const Icon(Icons.storefront, size: 18),
            label: const Text('Ver comercio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.backgroundDark,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openInMaps(commerce.location),
            icon: const Icon(Icons.directions, size: 18),
            label: const Text('Ir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openInMaps(LatLng location) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}&travelmode=walking',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
