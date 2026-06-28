import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../blocs/auth/auth_bloc.dart';

class FavoritesScreen extends StatefulWidget {
  final bool showFollowing;

  const FavoritesScreen({super.key, this.showFollowing = false});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<CommerceEntity> _commerces = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final repo = GetIt.instance<CommerceRepository>();
    final result = widget.showFollowing
        ? await repo.getUserFollowing(authState.user.id)
        : await repo.getUserFavorites(authState.user.id);

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (list) => setState(() {
        _loading = false;
        _commerces = list;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.showFollowing ? 'Comercios seguidos' : 'Favoritos';
    final emptyIcon =
        widget.showFollowing ? Icons.storefront_outlined : Icons.favorite_outline;
    final emptyText = widget.showFollowing
        ? 'Aún no seguís ningún comercio'
        : 'Aún no tenés favoritos';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(title,
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error.isNotEmpty
              ? _buildError()
              : _commerces.isEmpty
                  ? _buildEmpty(emptyIcon, emptyText)
                  : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _commerces.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CommerceTile(
        commerce: _commerces[i],
        onTap: () => context.push('/commerce/${_commerces[i].id}'),
      ).animate(delay: Duration(milliseconds: i * 50)).fadeIn().slideX(
            begin: -0.04,
            end: 0,
          ),
    );
  }

  Widget _buildEmpty(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.primary.withOpacity(0.25)),
          const SizedBox(height: 16),
          Text(text,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondaryDark)),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.explore, color: AppColors.primary),
            label: Text('Explorar el mapa',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
            onPressed: () => context.go('/map'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Text(_error,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondaryDark)),
    );
  }
}

class _CommerceTile extends StatelessWidget {
  final CommerceEntity commerce;
  final VoidCallback onTap;

  const _CommerceTile({required this.commerce, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: commerce.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: commerce.logoUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
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
                          style: AppTextStyles.titleSmall
                              .copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (commerce.status == CommerceStatus.verified)
                        const Icon(Icons.verified,
                            color: AppColors.primary, size: 14),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    commerce.categoryDisplayName,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: AppColors.gold),
                      const SizedBox(width: 3),
                      Text(
                        commerce.rating.toStringAsFixed(1),
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondaryDark),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: commerce.isCurrentlyOpen
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        commerce.isCurrentlyOpen ? 'Abierto' : 'Cerrado',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: commerce.isCurrentlyOpen
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondaryDark, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      color: AppColors.backgroundSurface,
      child: const Icon(Icons.store, color: AppColors.primary, size: 22),
    );
  }
}
