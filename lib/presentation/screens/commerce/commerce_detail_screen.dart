import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/device_id.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../../domain/entities/review_entity.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../services/injection_container.dart';
import '../../blocs/commerce/commerce_bloc.dart';
import '../../blocs/promotions/promotions_bloc.dart';
import '../../blocs/coupons/coupons_bloc.dart';
import '../../widgets/promotion_card.dart';
import '../../widgets/review_submission_sheet.dart';

class CommerceDetailScreen extends StatefulWidget {
  final String commerceId;

  const CommerceDetailScreen({super.key, required this.commerceId});

  @override
  State<CommerceDetailScreen> createState() => _CommerceDetailScreenState();
}

class _CommerceDetailScreenState extends State<CommerceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFavorite = false;
  bool _isFollowing = false;
  CommerceEntity? _currentCommerce;
  String _deviceId = '';
  List<ReviewEntity> _reviews = [];
  bool _reviewsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context.read<CommerceBloc>().add(LoadCommerceDetail(widget.commerceId));
    context.read<PromotionsBloc>().add(
          LoadCommercePromotions(commerceId: widget.commerceId),
        );
    getDeviceId().then((id) => _deviceId = id);
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _reviewsLoading = true);
    final result = await sl<CommerceRepository>()
        .getCommerceReviews(commerceId: widget.commerceId);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _reviewsLoading = false),
      (reviews) => setState(() {
        _reviews = reviews;
        _reviewsLoading = false;
      }),
    );
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
      body: BlocListener<CouponsBloc, CouponsState>(
        listener: (context, state) {
          if (state is CouponClaimed) {
            _showCouponClaimedDialog(state.coupon.promotionTitle);
          } else if (state is CouponsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: BlocBuilder<CommerceBloc, CommerceState>(
          builder: (context, state) {
            if (state is CommerceDetailLoaded) {
              final commerce = state.commerce;
              _isFavorite = state.isFavorite;
              _isFollowing = state.isFollowing;
              _currentCommerce = commerce;
              return _buildContent(commerce);
            }
            if (state is CommerceError) {
              return _buildError(state.message);
            }
            return _buildLoading();
          },
        ),
      ),
    );
  }

  void _showCouponClaimedDialog(String promotionTitle) {
    final commerce = _currentCommerce;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Cupón guardado!',
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '"$promotionTitle" está en tus cupones.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (commerce != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openInMaps();
                  },
                  icon: const Icon(Icons.directions_walk, size: 18),
                  label: const Text('Ir al local ahora'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.backgroundDark,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/coupons');
                },
                icon: const Icon(Icons.confirmation_num_outlined, size: 18),
                label: const Text('Ver mis cupones'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(CommerceEntity commerce) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(commerce),
        SliverToBoxAdapter(child: _buildInfo(commerce)),
        SliverToBoxAdapter(child: _buildTabs()),
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPromotionsTab(),
              _buildAboutTab(commerce),
              _buildGalleryTab(commerce),
              _buildReviewsTab(commerce),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(CommerceEntity commerce) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        _buildActionButton(
          icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
          color: _isFavorite ? AppColors.error : Colors.white,
          onTap: _toggleFavorite,
        ),
        _buildActionButton(
          icon: Icons.share_outlined,
          color: Colors.white,
          onTap: _shareCommerce,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: commerce.galleryUrls.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: commerce.galleryUrls.first,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildCoverPlaceholder(commerce),
              )
            : _buildCoverPlaceholder(commerce),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildCoverPlaceholder(CommerceEntity commerce) {
    return Container(
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
      child: Center(
        child: Icon(
          Icons.storefront,
          size: 72,
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildInfo(CommerceEntity commerce) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogo(commerce),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commerce.name,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      commerce.category.name,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRating(commerce),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatsRow(commerce),
          const SizedBox(height: 16),
          _buildFollowButton(commerce),
          if (commerce.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              commerce.description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          _buildAddress(commerce),
          if (commerce.phone != null) _buildContact(commerce),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildLogo(CommerceEntity commerce) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: commerce.logoUrl != null
          ? CachedNetworkImage(imageUrl: commerce.logoUrl!, fit: BoxFit.cover)
          : Icon(Icons.storefront, color: AppColors.primary, size: 36),
    );
  }

  Widget _buildRating(CommerceEntity commerce) {
    final rating = commerce.rating;
    return Row(
      children: [
        ...List.generate(5, (i) {
          return Icon(
            i < rating.floor() ? Icons.star : Icons.star_border,
            size: 14,
            color: AppColors.gold,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.gold),
        ),
        const SizedBox(width: 4),
        Text(
          '(${commerce.reviewCount})',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(CommerceEntity commerce) {
    return Row(
      children: [
        _buildStat(Icons.people_outline, '${commerce.followerCount}', 'seguidores'),
        const SizedBox(width: 20),
        _buildStat(Icons.local_offer_outlined, '${commerce.activePromotionsCount}', 'promos activas'),
        const SizedBox(width: 20),
        if (commerce.plan != CommercePlan.free)
          _buildPlanBadge(commerce.plan),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondaryDark),
        const SizedBox(width: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' $label',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanBadge(CommercePlan plan) {
    final Map<CommercePlan, (String, Color)> planMeta = {
      CommercePlan.premium: ('Premium', AppColors.secondary),
      CommercePlan.enterprise: ('Enterprise', AppColors.gold),
      CommercePlan.basic: ('Basic', AppColors.primary),
    };
    final meta = planMeta[plan];
    if (meta == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.$2.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: meta.$2.withValues(alpha: 0.5)),
      ),
      child: Text(
        meta.$1,
        style: AppTextStyles.labelSmall.copyWith(color: meta.$2),
      ),
    );
  }

  Widget _buildFollowButton(CommerceEntity commerce) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleFollow,
            icon: Icon(
              _isFollowing ? Icons.notifications_active : Icons.notifications_outlined,
              size: 18,
            ),
            label: Text(_isFollowing ? 'Siguiendo' : 'Seguir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _isFollowing ? AppColors.primary : Colors.white,
              side: BorderSide(
                color: _isFollowing ? AppColors.primary : Colors.white30,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: IconButton(
            icon: const Icon(Icons.map_outlined, size: 20),
            color: Colors.white,
            onPressed: _openInMaps,
          ),
        ),
      ],
    );
  }

  Widget _buildAddress(CommerceEntity commerce) {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondaryDark),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            commerce.address,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
          ),
        ),
      ],
    );
  }

  Widget _buildContact(CommerceEntity commerce) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondaryDark),
          const SizedBox(width: 6),
          Text(
            commerce.phone!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: AppColors.backgroundDark,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Promociones'),
          Tab(text: 'Acerca de'),
          Tab(text: 'Galería'),
          Tab(text: 'Reseñas'),
        ],
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondaryDark,
        labelStyle: AppTextStyles.titleSmall,
      ),
    );
  }

  Widget _buildPromotionsTab() {
    return BlocBuilder<PromotionsBloc, PromotionsState>(
      builder: (context, state) {
        if (state is PromotionsLoading) {
          return _buildPromotionsShimmer();
        }
        if (state is PromotionsLoaded) {
          if (state.promotions.isEmpty) {
            return _buildEmpty('Sin promociones activas', Icons.local_offer_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.promotions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => PromotionCard(
              promotion: state.promotions[i],
              onTap: () => _onPromotionTap(state.promotions[i]),
              onClaim: state.promotions[i].hasAvailableSlots
                  ? () => _claimPromotion(state.promotions[i])
                  : null,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAboutTab(CommerceEntity commerce) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (commerce.description.isNotEmpty) ...[
            _buildSection('Descripción', commerce.description),
            const SizedBox(height: 20),
          ],
          _buildSectionTitle('Horarios'),
          const SizedBox(height: 8),
          _buildHours(commerce),
          const SizedBox(height: 20),
          if (commerce.website != null) ...[
            _buildSectionTitle('Sitio web'),
            const SizedBox(height: 8),
            _buildWebsite(commerce.website!),
          ],
          if (commerce.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionTitle('Etiquetas'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: commerce.tags
                  .map((tag) => Chip(
                        label: Text(tag),
                        backgroundColor: AppColors.backgroundSurface,
                        labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHours(CommerceEntity commerce) {
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return Column(
      children: List.generate(7, (i) {
        final hours = commerce.businessHours[dayKeys[i]];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  days[i],
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                hours == null || !hours.isOpen
                    ? 'Cerrado'
                    : '${hours.openTime} - ${hours.closeTime}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: hours?.isOpen == true ? Colors.white : AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 8),
        Text(
          content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildWebsite(String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(
          url.startsWith('http') ? url : 'https://$url',
        );
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        children: [
          const Icon(Icons.language, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            url,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryTab(CommerceEntity commerce) {
    if (commerce.galleryUrls.isEmpty) {
      return _buildEmpty('Sin imágenes', Icons.photo_library_outlined);
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: commerce.galleryUrls.length,
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: commerce.galleryUrls[i],
          fit: BoxFit.cover,
          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildReviewsTab(CommerceEntity commerce) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              if (_reviews.isNotEmpty) ...[
                Icon(Icons.star, color: AppColors.gold, size: 18),
                const SizedBox(width: 4),
                Text(
                  (_reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                          _reviews.length)
                      .toStringAsFixed(1),
                  style: AppTextStyles.titleMedium
                      .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${_reviews.length} reseña${_reviews.length == 1 ? '' : 's'})',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondaryDark),
                ),
              ] else
                Text(
                  'Sin reseñas aún',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondaryDark),
                ),
              const Spacer(),
              if (user != null)
                TextButton.icon(
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text('Reseñar'),
                  onPressed: () => ReviewSubmissionSheet.show(
                    context,
                    commerceId: widget.commerceId,
                    userId: user.uid,
                    userName: user.displayName ?? 'Usuario',
                    userPhotoUrl: user.photoURL,
                    onReviewSubmitted: _loadReviews,
                  ),
                ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1E293B)),
        if (_reviewsLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_reviews.isEmpty)
          Expanded(child: _buildEmpty('Sé el primero en opinar', Icons.rate_review_outlined))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ReviewCard(review: _reviews[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondaryDark.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.backgroundCard,
      highlightColor: AppColors.backgroundSurface,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.backgroundCard,
      highlightColor: AppColors.backgroundSurface,
      child: Column(
        children: [
          Container(height: 250, color: Colors.white),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(height: 24, width: double.infinity, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 16, width: 200, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 56, color: AppColors.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context
                .read<CommerceBloc>()
                .add(LoadCommerceDetail(widget.commerceId)),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite() {
    context
        .read<CommerceBloc>()
        .add(ToggleFavoriteEvent(widget.commerceId));
  }

  void _toggleFollow() {
    context
        .read<CommerceBloc>()
        .add(ToggleFollowEvent(widget.commerceId));
  }

  Future<void> _shareCommerce() async {
    final commerce = _currentCommerce;
    if (commerce == null) return;
    await Share.share(
      '¡Mirá ${commerce.name} en ShinraCity! '
      'Tienen promociones exclusivas cerca de vos. '
      'https://shinracity.app/commerce/${commerce.id}',
      subject: commerce.name,
    );
  }

  Future<void> _openInMaps() async {
    final commerce = _currentCommerce;
    if (commerce == null) return;
    final lat = commerce.location.latitude;
    final lng = commerce.location.longitude;
    final name = Uri.encodeComponent(commerce.name);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$name',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _onPromotionTap(PromotionEntity promotion) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PromotionDetailSheet(
        promotion: promotion,
        onClaim: promotion.hasAvailableSlots ? () => _claimPromotion(promotion) : null,
      ),
    );
  }

  void _claimPromotion(PromotionEntity promotion) {
    context.read<CouponsBloc>().add(
      ClaimCouponEvent(promotionId: promotion.id, deviceId: _deviceId),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Guardando "${promotion.title}"...'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.backgroundCard,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ─── Review card ─────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewEntity review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: review.userPhotoUrl != null
                    ? NetworkImage(review.userPhotoUrl!)
                    : null,
                child: review.userPhotoUrl == null
                    ? Text(
                        review.userName.isNotEmpty
                            ? review.userName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.titleSmall
                            .copyWith(color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
              RatingBarIndicator(
                rating: review.rating,
                itemCount: 5,
                itemSize: 14,
                itemBuilder: (_, __) =>
                    const Icon(Icons.star, color: AppColors.gold),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: AppTextStyles.bodySmall
                  .copyWith(color: Colors.white.withValues(alpha: 0.85), height: 1.5),
            ),
          ],
          if (review.ownerReply != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.store, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      review.ownerReply!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondaryDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

// ─── Promotion detail bottom sheet ───────────────────────────────────────────

class _PromotionDetailSheet extends StatelessWidget {
  final PromotionEntity promotion;
  final VoidCallback? onClaim;

  const _PromotionDetailSheet({required this.promotion, this.onClaim});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            promotion.title,
            style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          if (promotion.description != null)
          Text(
            promotion.description!,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondaryDark, height: 1.5),
          ),
          if (promotion.conditions?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.textSecondaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      promotion.conditions!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.star, size: 14, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(
                '+${promotion.pointsAwarded} puntos al canjear',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.gold),
              ),
              const Spacer(),
              Text(
                'Vence: ${_formatDate(promotion.endDate)}',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondaryDark),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: promotion.hasAvailableSlots
                  ? () {
                      Navigator.of(context).pop();
                      onClaim?.call();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                promotion.hasAvailableSlots
                    ? 'Ver detalle y canjear'
                    : 'Sin cupos disponibles',
                style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
