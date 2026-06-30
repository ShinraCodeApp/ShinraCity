import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/commerce_entity.dart';

class CategoryFilterBar extends StatelessWidget {
  final CommerceCategory? selectedCategory;
  final void Function(CommerceCategory?) onCategorySelected;

  const CategoryFilterBar({
    super.key,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  static const _categories = [
    // Gastronomía
    (CommerceCategory.restaurants, '🍽️', 'Restaurantes'),
    (CommerceCategory.cafes, '☕', 'Cafeterías'),
    (CommerceCategory.fastFood, '🍔', 'Comida Rápida'),
    (CommerceCategory.bar, '🍺', 'Bar / Pub'),
    (CommerceCategory.bakery, '🥐', 'Panadería'),
    // Salud y bienestar
    (CommerceCategory.pharmacies, '💊', 'Farmacias'),
    (CommerceCategory.health, '🏥', 'Salud'),
    (CommerceCategory.beauty, '💄', 'Belleza'),
    // Comercio
    (CommerceCategory.clothing, '👕', 'Ropa'),
    (CommerceCategory.supermarket, '🛒', 'Supermercados'),
    (CommerceCategory.hardware, '🔩', 'Ferretería'),
    (CommerceCategory.jewelry, '💎', 'Joyería'),
    (CommerceCategory.market, '🏪', 'Feria / Mercado'),
    // Emprendedores
    (CommerceCategory.streetVendor, '🛍️', 'Vendedores'),
    (CommerceCategory.entrepreneur, '🚀', 'Emprendimientos'),
    (CommerceCategory.artisans, '🎨', 'Artesanos'),
    // Servicios
    (CommerceCategory.services, '🔧', 'Servicios'),
    (CommerceCategory.automotive, '🚗', 'Automotriz'),
    (CommerceCategory.education, '📚', 'Educación'),
    // Ocio y tech
    (CommerceCategory.technology, '💻', 'Tecnología'),
    (CommerceCategory.entertainment, '🎭', 'Entretenimiento'),
    (CommerceCategory.sports, '⚽', 'Deportes'),
    (CommerceCategory.tourism, '✈️', 'Turismo'),
    // Otras
    (CommerceCategory.pets, '🐾', 'Mascotas'),
    (CommerceCategory.other, '📦', 'Otros'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChip(null, '🗺️', 'Todos'),
          const SizedBox(width: 8),
          ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(cat.$1, cat.$2, cat.$3),
              )),
        ],
      ),
    );
  }

  Widget _buildChip(CommerceCategory? category, String emoji, String label) {
    final isSelected = selectedCategory == category;

    return GestureDetector(
      onTap: () => onCategorySelected(isSelected ? null : category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.backgroundCard.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? AppColors.backgroundDark : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
