import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/coupon_entity.dart';
import '../../blocs/coupons/coupons_bloc.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<CouponsBloc>().add(LoadUserCouponsEvent());
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
      appBar: AppBar(
        title: const Text('Mis Cupones'),
        backgroundColor: AppColors.backgroundCard,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          tabs: const [
            Tab(text: 'Activos'),
            Tab(text: 'Utilizados'),
            Tab(text: 'Expirados'),
          ],
        ),
      ),
      body: BlocBuilder<CouponsBloc, CouponsState>(
        builder: (context, state) {
          if (state is CouponsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is CouponsLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildCouponsList(
                  state.coupons.where((c) => c.isValid).toList(),
                  'No tenés cupones activos',
                ),
                _buildCouponsList(
                  state.coupons.where((c) => c.status == CouponStatus.used).toList(),
                  'No hay cupones utilizados',
                ),
                _buildCouponsList(
                  state.coupons.where((c) => c.isExpired).toList(),
                  'No hay cupones expirados',
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildCouponsList(List<CouponEntity> coupons, String emptyMessage) {
    if (coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.confirmation_num_outlined,
                size: 64, color: AppColors.textSecondaryDark),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coupons.length,
      itemBuilder: (context, index) {
        return _CouponCard(
          coupon: coupons[index],
          onTap: () => _showCouponDetail(coupons[index]),
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: index * 80))
            .slideY(begin: 0.2, end: 0);
      },
    );
  }

  void _showCouponDetail(CouponEntity coupon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CouponDetailSheet(coupon: coupon),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponEntity coupon;
  final VoidCallback onTap;

  const _CouponCard({required this.coupon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isValid = coupon.isValid;
    final color = isValid ? AppColors.primary : AppColors.textSecondaryDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isValid ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFF1E293B),
          ),
        ),
        child: Row(
          children: [
            // Left colored stripe
            Container(
              width: 6,
              height: 100,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.commerceName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coupon.promotionTitle,
                      style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: AppColors.textSecondaryDark),
                        const SizedBox(width: 4),
                        Text(
                          isValid
                              ? 'Vence ${timeago.format(coupon.expiresAt, locale: 'es')}'
                              : coupon.status == CouponStatus.used
                                  ? 'Utilizado ${timeago.format(coupon.usedAt!, locale: 'es')}'
                                  : 'Expirado',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isValid
                                ? coupon.timeRemaining.inHours < 24
                                    ? AppColors.warning
                                    : AppColors.textSecondaryDark
                                : AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // QR preview
            Padding(
              padding: const EdgeInsets.all(12),
              child: isValid
                  ? QrImageView(
                      data: coupon.qrData,
                      size: 60,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(4),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        coupon.status == CouponStatus.used
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: coupon.status == CouponStatus.used
                            ? AppColors.success
                            : AppColors.error,
                        size: 28,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponDetailSheet extends StatelessWidget {
  final CouponEntity coupon;

  const _CouponDetailSheet({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    coupon.commerceName,
                    style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    coupon.promotionTitle,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (coupon.isValid) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: coupon.qrData,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Text(
                        coupon.id.substring(0, 8).toUpperCase(),
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondaryDark),
                        const SizedBox(width: 6),
                        Text(
                          'Mostrá este QR al empleado del local',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildExpirationWarning(),
                  ] else
                    _buildUsedState(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationWarning() {
    final remaining = coupon.timeRemaining;
    final isUrgent = remaining.inHours < 24;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? AppColors.warning.withValues(alpha: 0.3) : const Color(0xFF1E293B),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            color: isUrgent ? AppColors.warning : AppColors.textSecondaryDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vencimiento',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
              ),
              Text(
                timeago.format(coupon.expiresAt, locale: 'es'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isUrgent ? AppColors.warning : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsedState() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: coupon.status == CouponStatus.used
                ? AppColors.success.withValues(alpha: 0.15)
                : AppColors.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            coupon.status == CouponStatus.used ? Icons.check_circle : Icons.cancel,
            color: coupon.status == CouponStatus.used ? AppColors.success : AppColors.error,
            size: 44,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          coupon.statusDisplayName,
          style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
        ),
        if (coupon.savedAmount != null) ...[
          const SizedBox(height: 12),
          Text(
            'Ahorraste \$${coupon.savedAmount!.toStringAsFixed(0)}',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.success),
          ),
        ],
      ],
    );
  }
}

// QR Scanner for business employees
class QRScannerScreen extends StatefulWidget {
  final String commerceId;

  const QRScannerScreen({super.key, required this.commerceId});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CouponsBloc, CouponsState>(
      listener: (context, state) {
        if (state is CouponValidated) {
          setState(() => _isProcessing = false);
          _showResult(context, success: true,
              message: state.result['message'] as String? ?? '¡Cupón validado!');
        } else if (state is CouponsError) {
          setState(() => _isProcessing = false);
          _controller.start();
          _showResult(context, success: false, message: state.message);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Escanear Cupón'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            _buildOverlay(),
          ],
        ),
      ),
    );
  }

  void _showResult(BuildContext context, {required bool success, required String message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          success ? Icons.check_circle : Icons.error,
          color: success ? AppColors.success : AppColors.error,
          size: 48,
        ),
        title: Text(
          success ? '¡Validado!' : 'Error',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (success) Navigator.of(context).pop();
            },
            child: Text(
              success ? 'Listo' : 'Reintentar',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(color: Colors.black54),
        ),
        Row(
          children: [
            Expanded(child: Container(color: Colors.black54)),
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Expanded(child: Container(color: Colors.black54)),
          ],
        ),
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.black54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Apuntá al código QR del cupón',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: AppColors.primary),
                ] else ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _enterCodeManually,
                    icon: const Icon(Icons.keyboard, color: AppColors.primary),
                    label: Text('Ingresar código manualmente',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _enterCodeManually() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ingresar código', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, letterSpacing: 4, fontSize: 20),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(color: AppColors.textSecondaryDark),
            filled: true,
            fillColor: AppColors.backgroundSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              _controller.stop();
              context.read<CouponsBloc>().add(ValidateCouponEvent(
                qrData: code,
                commerceId: widget.commerceId,
              ));
            },
            child: const Text('Validar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isProcessing = true);
    _controller.stop();

    context.read<CouponsBloc>().add(ValidateCouponEvent(
      qrData: barcode!.rawValue!,
      commerceId: widget.commerceId,
    ));
  }
}
