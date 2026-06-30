import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/commerce_entity.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../services/analytics_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _repo = GetIt.instance<CommerceRepository>();

  List<CommerceEntity> _results = [];
  bool _loading = false;
  String _error = '';
  CommerceCategory? _selectedCategory;

  static const _categories = CommerceCategory.values;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final hasCategory = _selectedCategory != null;
    if (query.length < 2 && !hasCategory) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    if (query.length >= 2) {
      GetIt.instance<AnalyticsService>().logSearchCommerce(query: query);
    }
    final result = await _repo.searchCommerces(
      query: query,
      category: _selectedCategory,
      limit: 30,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (commerces) => setState(() {
        _loading = false;
        _results = commerces;
      }),
    );
  }

  void _selectCategory(CommerceCategory? cat) {
    setState(() => _selectedCategory = cat);
    _search(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            _buildCategoryChips(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar comercios...',
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondaryDark),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.primary, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _controller.clear();
                            _search('');
                          },
                          child: const Icon(Icons.close,
                              color: AppColors.textSecondaryDark, size: 20),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                ),
                onChanged: _search,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _CategoryChip(
              label: 'Todos',
              icon: Icons.apps,
              selected: _selectedCategory == null,
              onTap: () => _selectCategory(null),
            );
          }
          final cat = _categories[i - 1];
          return _CategoryChip(
            label: _catLabel(cat),
            icon: _catIcon(cat),
            selected: _selectedCategory == cat,
            onTap: () => _selectCategory(_selectedCategory == cat ? null : cat),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Text(
          _error,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_controller.text.isEmpty && _selectedCategory == null) {
      return _buildEmptyPrompt();
    }

    if (_controller.text.length < 2 && _selectedCategory == null) {
      return _buildEmptyPrompt();
    }

    if (_results.isEmpty) {
      return _buildNoResults();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        return _CommerceSearchTile(
          commerce: _results[i],
          onTap: () => context.push('/commerce/${_results[i].id}'),
        ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideX(
              begin: -0.05,
              end: 0,
            );
      },
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search,
              size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Busca restaurantes, cafeterías,\nfarmácias y más',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondaryDark),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_mall_directory_outlined,
              size: 64, color: AppColors.textSecondaryDark.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Sin resultados',
            style:
                AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Probá con otro término o categoría',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  String _catLabel(CommerceCategory cat) {
    const labels = {
      CommerceCategory.restaurants: 'Restaurantes',
      CommerceCategory.cafes: 'Cafeterías',
      CommerceCategory.pharmacies: 'Farmacias',
      CommerceCategory.technology: 'Tecnología',
      CommerceCategory.clothing: 'Ropa',
      CommerceCategory.pets: 'Mascotas',
      CommerceCategory.sports: 'Deportes',
      CommerceCategory.tourism: 'Turismo',
      CommerceCategory.beauty: 'Belleza',
      CommerceCategory.services: 'Servicios',
      CommerceCategory.supermarket: 'Súper',
      CommerceCategory.entertainment: 'Ocio',
      CommerceCategory.health: 'Salud',
      CommerceCategory.education: 'Educación',
      CommerceCategory.automotive: 'Autos',
      CommerceCategory.other: 'Otros',
    };
    return labels[cat] ?? cat.name;
  }

  IconData _catIcon(CommerceCategory cat) {
    switch (cat) {
      case CommerceCategory.restaurants:
        return Icons.restaurant;
      case CommerceCategory.cafes:
        return Icons.coffee;
      case CommerceCategory.pharmacies:
        return Icons.local_pharmacy;
      case CommerceCategory.technology:
        return Icons.devices;
      case CommerceCategory.clothing:
        return Icons.checkroom;
      case CommerceCategory.pets:
        return Icons.pets;
      case CommerceCategory.sports:
        return Icons.sports_soccer;
      case CommerceCategory.tourism:
        return Icons.landscape;
      case CommerceCategory.beauty:
        return Icons.face;
      case CommerceCategory.services:
        return Icons.build;
      case CommerceCategory.supermarket:
        return Icons.shopping_cart;
      case CommerceCategory.entertainment:
        return Icons.movie;
      case CommerceCategory.health:
        return Icons.favorite;
      case CommerceCategory.education:
        return Icons.school;
      case CommerceCategory.automotive:
        return Icons.directions_car;
      default:
        return Icons.category;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: selected ? Colors.white : AppColors.textSecondaryDark),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? Colors.white : AppColors.textSecondaryDark,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommerceSearchTile extends StatelessWidget {
  final CommerceEntity commerce;
  final VoidCallback onTap;

  const _CommerceSearchTile({
    required this.commerce,
    required this.onTap,
  });

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
              child: (commerce.logoUrl?.isNotEmpty ?? false)
                  ? CachedNetworkImage(
                      imageUrl: commerce.logoUrl!,
                      width: 56,
                      height: 56,
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
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary.withValues(alpha: 0.8)),
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
                      Icon(Icons.location_on,
                          size: 12,
                          color: AppColors.textSecondaryDark),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          commerce.address,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textSecondaryDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondaryDark, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.backgroundSurface,
      child: const Icon(Icons.store, color: AppColors.primary, size: 24),
    );
  }
}
