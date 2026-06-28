import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/user_entity.dart';
import '../../screens/admin/admin_panel_screen.dart';
import '../../screens/business/register_business_screen.dart';

class MyBusinessesSection extends StatefulWidget {
  final UserEntity user;
  const MyBusinessesSection({super.key, required this.user});

  @override
  State<MyBusinessesSection> createState() => _MyBusinessesSectionState();
}

class _MyBusinessesSectionState extends State<MyBusinessesSection> {
  final _db = FirebaseFirestore.instance;

  bool get _isAdmin =>
      widget.user.role == UserRole.admin ||
      widget.user.role == UserRole.superAdmin;

  Stream<QuerySnapshot> get _businessStream => _db
      .collection(AppConstants.commercesCollection)
      .where('ownerId', isEqualTo: widget.user.id)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Future<void> _deleteBusiness(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AdminGateDialog(),
    ) ?? false;
    if (!ok) return;

    await _db.collection(AppConstants.commercesCollection).doc(id).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ "$name" eliminado'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '🏪 Mis Negocios',
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const RegisterBusinessScreen(),
                  ),
                );
                if (result == true) setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      'Crear',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _businessStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return _buildEmpty();
            }

            return Column(
              children: docs
                  .map((doc) => _buildBusinessCard(doc))
                  .toList(),
            );
          },
        ),
        if (_isAdmin) ...[
          const SizedBox(height: 8),
          _buildAdminAllBusinessesButton(),
        ],
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            '¿Tenés un negocio?',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Registrá tu comercio, emprendimiento o negocio y llegá a clientes cercanos con promociones y cupones.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_business),
            label: const Text(
              'Registrar mi negocio',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const RegisterBusinessScreen(),
                ),
              );
              if (result == true) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'pending';
    final logoUrl = data['logoUrl'] as String?;
    final name = data['name'] as String? ?? 'Sin nombre';
    final city = data['city'] as String? ?? '';
    final catStr = data['category'] as String? ?? 'other';

    final statusColors = {
      'active': AppColors.success,
      'pending': AppColors.warning,
      'suspended': AppColors.error,
      'rejected': AppColors.error,
    };
    final statusLabels = {
      'active': '✅ Activo',
      'pending': '⏳ Pendiente',
      'suspended': '🚫 Suspendido',
      'rejected': '❌ Rechazado',
    };
    final statusColor = statusColors[status] ?? AppColors.textSecondaryDark;
    final categoryEmoji = _categoryEmojis[catStr] ?? '📦';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 52,
                height: 52,
                color: AppColors.backgroundSurface,
                child: logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Icon(
                          Icons.storefront,
                          color: AppColors.textSecondaryDark,
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.storefront,
                          color: AppColors.textSecondaryDark,
                        ),
                      )
                    : Center(
                        child: Text(
                          categoryEmoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
              ),
            ),
            title: Text(
              name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '$categoryEmoji $city',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusLabels[status] ?? status,
                style: AppTextStyles.labelSmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _actionBtn(
                  icon: Icons.bar_chart_outlined,
                  label: 'Dashboard',
                  color: AppColors.primary,
                  onTap: () => context.push('/business'),
                ),
                const SizedBox(width: 6),
                _actionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  color: AppColors.secondary,
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => RegisterBusinessScreen(
                          editCommerceId: doc.id,
                        ),
                      ),
                    );
                    if (result == true) setState(() {});
                  },
                ),
                if (_isAdmin) ...[
                  const SizedBox(width: 6),
                  _actionBtn(
                    icon: Icons.delete_outline,
                    label: 'Eliminar',
                    color: AppColors.error,
                    onTap: () => _deleteBusiness(doc.id, name),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminAllBusinessesButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Text(
              'Gestionar todos los negocios',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: AppColors.error, size: 12),
          ],
        ),
      ),
    );
  }

  static const _categoryEmojis = {
    'restaurants': '🍽️',
    'cafes': '☕',
    'fastFood': '🍔',
    'bar': '🍺',
    'bakery': '🥐',
    'pharmacies': '💊',
    'health': '🏥',
    'beauty': '💄',
    'clothing': '👕',
    'supermarket': '🛒',
    'hardware': '🔩',
    'jewelry': '💎',
    'market': '🏪',
    'streetVendor': '🛍️',
    'entrepreneur': '🚀',
    'services': '🔧',
    'automotive': '🚗',
    'education': '📚',
    'technology': '💻',
    'entertainment': '🎭',
    'sports': '⚽',
    'tourism': '✈️',
    'pets': '🐾',
    'other': '📦',
  };
}

// ── Admin Gate Dialog (local copy to avoid cross-import) ──────────────────────

class _AdminGateDialog extends StatefulWidget {
  const _AdminGateDialog();

  @override
  State<_AdminGateDialog> createState() => _AdminGateDialogState();
}

class _AdminGateDialogState extends State<_AdminGateDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _checkPassword() {
    if (_ctrl.text == 'ShinraSakujo') {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Contraseña incorrecta');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.security, color: AppColors.error),
          const SizedBox(width: 8),
          Text(
            'Confirmar acción',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
      content: TextField(
        controller: _ctrl,
        obscureText: _obscure,
        style: const TextStyle(color: Colors.white),
        onSubmitted: (_) => _checkPassword(),
        decoration: InputDecoration(
          hintText: 'Contraseña de admin',
          hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
          suffixIcon: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textSecondaryDark,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          errorText: _error,
          errorStyle: const TextStyle(color: AppColors.error),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
          ),
          onPressed: _checkPassword,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
