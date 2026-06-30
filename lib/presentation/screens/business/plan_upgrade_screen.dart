import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/commerce_entity.dart';

enum _BillingCycle { monthly, annual }

class PlanUpgradeScreen extends StatefulWidget {
  final CommercePlan currentPlan;
  final String commerceId;

  const PlanUpgradeScreen({
    super.key,
    required this.currentPlan,
    required this.commerceId,
  });

  @override
  State<PlanUpgradeScreen> createState() => _PlanUpgradeScreenState();
}

class _PlanUpgradeScreenState extends State<PlanUpgradeScreen> {
  _BillingCycle _cycle = _BillingCycle.annual;
  CommercePlan? _selectedPlan;
  bool _loading = false;
  String _error = '';

  static const _plans = [CommercePlan.basic, CommercePlan.premium, CommercePlan.enterprise];

  // Default prices (used when Firestore not yet configured)
  static const _defaultPrices = {
    CommercePlan.basic: {'monthly': 2990, 'annual': 2392},
    CommercePlan.premium: {'monthly': 5990, 'annual': 4792},
    CommercePlan.enterprise: {'monthly': 14990, 'annual': 11992},
  };

  Map<CommercePlan, Map<String, int>> _prices = _defaultPrices;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('plans')
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;
      setState(() {
        _prices = {
          CommercePlan.basic: {
            'monthly': (data['basic']?['monthly'] as num?)?.toInt() ?? 2990,
            'annual': (data['basic']?['annual'] as num?)?.toInt() ?? 2392,
          },
          CommercePlan.premium: {
            'monthly': (data['premium']?['monthly'] as num?)?.toInt() ?? 5990,
            'annual': (data['premium']?['annual'] as num?)?.toInt() ?? 4792,
          },
          CommercePlan.enterprise: {
            'monthly': (data['enterprise']?['monthly'] as num?)?.toInt() ?? 14990,
            'annual': (data['enterprise']?['annual'] as num?)?.toInt() ?? 11992,
          },
        };
      });
    } catch (_) {}
  }

  static const _features = {
    CommercePlan.basic: [
      'Hasta 10 promociones activas',
      'Notificaciones a seguidores',
      'Estadísticas básicas',
      'Badge de negocio verificado',
    ],
    CommercePlan.premium: [
      'Promociones ilimitadas',
      'Campañas de geofencing',
      'Analytics avanzados',
      'Soporte prioritario',
      'Galería de imágenes (20 fotos)',
      'Publicidad en mapa destacada',
    ],
    CommercePlan.enterprise: [
      'Todo lo de Premium',
      'Múltiples sucursales',
      'API de integración',
      'Manager de cuenta dedicado',
      'Campañas de IA personalizadas',
      'Exportación de datos',
      'Acceso anticipado a funciones',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Actualizar plan',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentPlanBanner(),
                  const SizedBox(height: 24),
                  _buildBillingToggle(),
                  const SizedBox(height: 20),
                  ..._plans.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildPlanCard(e.value, e.key),
                  )),
                  const SizedBox(height: 16),
                  _buildPaymentMethods(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _buildBottomCTA(),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan actual',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondaryDark),
                ),
                Text(
                  _planName(widget.currentPlan),
                  style: AppTextStyles.titleSmall
                      .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Activo',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CycleButton(
          label: 'Mensual',
          selected: _cycle == _BillingCycle.monthly,
          onTap: () => setState(() => _cycle = _BillingCycle.monthly),
        ),
        const SizedBox(width: 8),
        _CycleButton(
          label: 'Anual  -20%',
          selected: _cycle == _BillingCycle.annual,
          onTap: () => setState(() => _cycle = _BillingCycle.annual),
          badge: '20% off',
        ),
      ],
    );
  }

  Widget _buildPlanCard(CommercePlan plan, int index) {
    final isSelected = _selectedPlan == plan;
    final isCurrent = plan == widget.currentPlan;
    final priceKey = _cycle == _BillingCycle.monthly ? 'monthly' : 'annual';
    final price = _prices[plan]![priceKey]!;
    final isPremium = plan == CommercePlan.premium;

    return GestureDetector(
      onTap: isCurrent ? null : () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isPremium
                    ? AppColors.gold.withValues(alpha: 0.4)
                    : const Color(0xFF1E293B),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _planName(plan),
                            style: AppTextStyles.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Más popular',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${_formatPrice(price)}',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3, left: 4),
                            child: Text(
                              '/mes',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondaryDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.textSecondaryDark.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Plan actual',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondaryDark),
                    ),
                  )
                else if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.textSecondaryDark.withValues(alpha: 0.4)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ...(_features[plan]!.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 15,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
                    ],
                  ),
                ))),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn().slideY(
          begin: 0.06,
          end: 0,
        );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Métodos de pago aceptados',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _PaymentBadge(label: 'Tarjeta de crédito', icon: Icons.credit_card),
            const SizedBox(width: 8),
            _PaymentBadge(label: 'Mercado Pago', icon: Icons.payment),
            const SizedBox(width: 8),
            _PaymentBadge(label: 'Débito', icon: Icons.account_balance_wallet),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomCTA() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
          top: BorderSide(color: const Color(0xFF1E293B)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedPlan == null || _loading
                  ? null
                  : _initiatePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.backgroundSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _selectedPlan == null
                          ? 'Seleccioná un plan'
                          : 'Continuar con ${_planName(_selectedPlan!)}',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: _selectedPlan == null
                            ? AppColors.textSecondaryDark
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Podés cancelar en cualquier momento. Sin cargos ocultos.',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondaryDark),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment() async {
    if (_selectedPlan == null) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('createMercadoPagoPreference');
      final result = await callable.call({
        'plan': _selectedPlan!.name,
        'billingCycle': _cycle == _BillingCycle.monthly ? 'monthly' : 'annual',
        'commerceId': widget.commerceId,
      });

      final initPoint = result.data['initPoint'] as String?;

      if (!mounted) return;

      if (initPoint != null) {
        final uri = Uri.parse(initPoint);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message ?? 'Error al procesar el pago';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Error inesperado. Intenta más tarde.';
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _planName(CommercePlan plan) {
    switch (plan) {
      case CommercePlan.free:
        return 'Gratuito';
      case CommercePlan.basic:
        return 'Básico';
      case CommercePlan.premium:
        return 'Premium';
      case CommercePlan.enterprise:
        return 'Empresarial';
    }
  }

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${(price ~/ 1000)}.${(price % 1000).toString().padLeft(3, '0')}';
    }
    return price.toString();
  }
}

class _CycleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  const _CycleButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondaryDark,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PaymentBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondaryDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }
}
