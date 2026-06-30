import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../../services/image_upload_service.dart';
import '../../blocs/promotions/promotions_bloc.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/shinra_text_field.dart';

class CreatePromotionScreen extends StatefulWidget {
  final String commerceId;
  final PromotionEntity? existing;

  const CreatePromotionScreen({
    super.key,
    required this.commerceId,
    this.existing,
  });

  @override
  State<CreatePromotionScreen> createState() => _CreatePromotionScreenState();
}

class _CreatePromotionScreenState extends State<CreatePromotionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _totalSlotsController = TextEditingController();
  final _perUserLimitController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _promoCodeController = TextEditingController();

  File? _coverImageFile;
  bool _uploadingImage = false;

  PromotionType _type = PromotionType.discount;
  DiscountType _discountType = DiscountType.percentage;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isExclusiveForFollowers = false;
  bool _isVip = false;
  bool _requiresCode = false;
  int _currentStep = 0;
  int? _pointsAwarded;

  final List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _populate(widget.existing!);
    }
  }

  void _populate(PromotionEntity p) {
    _titleController.text = p.title;
    _descriptionController.text = p.description ?? '';
    _discountValueController.text = p.discountValue.toString();
    _totalSlotsController.text = p.totalSlots?.toString() ?? '';
    _perUserLimitController.text = p.perUserLimit?.toString() ?? '';
    _originalPriceController.text = p.originalPrice.toString();
    _discountedPriceController.text = p.discountedPrice?.toString() ?? '';
    _conditionsController.text = p.conditions ?? '';
    _promoCodeController.text = p.promoCode ?? '';
    _type = p.type;
    _discountType = p.discountType;
    _startDate = p.startDate;
    _endDate = p.endDate;
    _isExclusiveForFollowers = p.isExclusiveForFollowers;
    _isVip = p.isVip;
    _requiresCode = p.requiresCode;
    _pointsAwarded = p.pointsAwarded;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _totalSlotsController.dispose();
    _perUserLimitController.dispose();
    _originalPriceController.dispose();
    _discountedPriceController.dispose();
    _conditionsController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Text(
          _isEditing ? 'Editar Promoción' : 'Nueva Promoción',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<PromotionsBloc, PromotionsState>(
        listener: (context, state) {
          if (state is PromotionCreated || state is PromotionUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEditing ? 'Promoción actualizada' : 'Promoción creada'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.pop();
          }
          if (state is PromotionsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildStepper(),
              Expanded(child: _buildStepContent()),
              _buildNavButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ['Básico', 'Descuento', 'Fechas', 'Opciones'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: 200.ms,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.success
                              : isActive
                                  ? AppColors.primary
                                  : AppColors.backgroundSurface,
                          border: isActive
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text(
                                  '${i + 1}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: isActive ? Colors.white : AppColors.textSecondaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isActive ? AppColors.primary : AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: isDone ? AppColors.success : Colors.white12,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: AnimatedSwitcher(
        duration: 200.ms,
        child: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
          _buildStep4(),
        ][_currentStep],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Tipo de promoción'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PromotionType.values.map((type) {
            final isSelected = _type == type;
            return GestureDetector(
              onTap: () => setState(() => _type = type),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.white12,
                  ),
                ),
                child: Text(
                  _typeLabel(type),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        ShinraTextField(
          controller: _titleController,
          label: 'Título de la promoción',
          prefixIcon: Icons.title,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Requerido';
            if ((v?.length ?? 0) < 5) return 'Mínimo 5 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 16),
        ShinraTextField(
          controller: _descriptionController,
          label: 'Descripción (opcional)',
          prefixIcon: Icons.description_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        ShinraTextField(
          controller: _conditionsController,
          label: 'Condiciones (opcional)',
          prefixIcon: Icons.info_outline,
          hint: 'Ej: Válido de lunes a viernes',
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        _sectionLabel('Imagen de portada (opcional)'),
        const SizedBox(height: 12),
        _buildImagePicker(),
      ],
    ).animate().fadeIn();
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _uploadingImage
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary))
            : _coverImageFile != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_coverImageFile!, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _coverImageFile = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.primary.withValues(alpha: 0.6),
                          size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Agregar imagen',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondaryDark),
                      ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    final svc = GetIt.instance<ImageUploadService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: Text('Cámara',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final file = await svc.pickFromCamera(maxDim: 800);
                if (file != null && mounted) {
                  setState(() => _coverImageFile = file);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('Galería',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final file = await svc.pickFromGallery(maxDim: 800);
                if (file != null && mounted) {
                  setState(() => _coverImageFile = file);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Tipo de descuento'),
        const SizedBox(height: 12),
        Row(
          children: DiscountType.values.take(4).map((dt) {
            final isSelected = _discountType == dt;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _discountType = dt),
                child: AnimatedContainer(
                  duration: 200.ms,
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.backgroundSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white12,
                    ),
                  ),
                  child: Text(
                    _discountTypeLabel(dt),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        if (_discountType != DiscountType.freeItem && _discountType != DiscountType.twoForOne)
          ShinraTextField(
            controller: _discountValueController,
            label: _discountType == DiscountType.percentage
                ? 'Porcentaje de descuento'
                : 'Monto de descuento (\$)',
            prefixIcon: Icons.percent,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (_discountType == DiscountType.freeItem) return null;
              if (v?.isEmpty ?? true) return 'Requerido';
              final val = int.tryParse(v!);
              if (val == null || val <= 0) return 'Ingresá un valor válido';
              if (_discountType == DiscountType.percentage && val > 100) {
                return 'Máximo 100%';
              }
              return null;
            },
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ShinraTextField(
                controller: _originalPriceController,
                label: 'Precio original',
                prefixIcon: Icons.attach_money,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShinraTextField(
                controller: _discountedPriceController,
                label: 'Precio final',
                prefixIcon: Icons.local_offer_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('Cupos y límites'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ShinraTextField(
                controller: _totalSlotsController,
                label: 'Total de cupos',
                prefixIcon: Icons.people_outline,
                hint: 'Sin límite',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShinraTextField(
                controller: _perUserLimitController,
                label: 'Por usuario',
                prefixIcon: Icons.person_outline,
                hint: '1',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildStep3() {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Período de la promoción'),
        const SizedBox(height: 16),
        _buildDatePicker(
          label: 'Fecha de inicio',
          date: _startDate,
          onPick: (d) => setState(() => _startDate = d),
        ),
        const SizedBox(height: 12),
        _buildDatePicker(
          label: 'Fecha de fin',
          date: _endDate,
          onPick: (d) => setState(() => _endDate = d),
          minDate: _startDate.add(const Duration(hours: 1)),
        ),
        const SizedBox(height: 20),
        _buildDurationChips(),
      ],
    ).animate().fadeIn();
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required void Function(DateTime) onPick,
    DateTime? minDate,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: minDate ?? DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(date),
            builder: (ctx, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: AppColors.primary),
              ),
              child: child!,
            ),
          );
          if (time != null) {
            onPick(DateTime(
              picked.year, picked.month, picked.day,
              time.hour, time.minute,
            ));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChips() {
    final options = [
      ('1 día', const Duration(days: 1)),
      ('3 días', const Duration(days: 3)),
      ('1 semana', const Duration(days: 7)),
      ('2 semanas', const Duration(days: 14)),
      ('1 mes', const Duration(days: 30)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Accesos rápidos'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            return GestureDetector(
              onTap: () => setState(() => _endDate = _startDate.add(o.$2)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  o.$1,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      key: const ValueKey('step4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Opciones especiales'),
        const SizedBox(height: 12),
        _buildSwitch(
          title: 'Solo para seguidores',
          subtitle: 'La promo solo se muestra a quienes siguen tu negocio',
          value: _isExclusiveForFollowers,
          icon: Icons.people_outline,
          onChanged: (v) => setState(() => _isExclusiveForFollowers = v),
        ),
        _buildSwitch(
          title: 'Promoción VIP',
          subtitle: 'Requiere nivel Ambassador o superior',
          value: _isVip,
          icon: Icons.star_outline,
          onChanged: (v) => setState(() => _isVip = v),
        ),
        _buildSwitch(
          title: 'Requiere código',
          subtitle: 'Los usuarios deben ingresar un código para canjear',
          value: _requiresCode,
          icon: Icons.vpn_key_outlined,
          onChanged: (v) => setState(() => _requiresCode = v),
        ),
        if (_requiresCode) ...[
          const SizedBox(height: 12),
          ShinraTextField(
            controller: _promoCodeController,
            label: 'Código de promoción',
            prefixIcon: Icons.tag,
            hint: 'Ej: VERANO25',
            validator: (v) => _requiresCode && (v?.isEmpty ?? true) ? 'Requerido' : null,
          ),
        ],
        const SizedBox(height: 20),
        _sectionLabel('Puntos a otorgar'),
        const SizedBox(height: 8),
        Text(
          'Cuántos puntos gana el usuario al canjear esta promo',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [0, 10, 25, 50, 100, 200].map((pts) {
            final isSelected = _pointsAwarded == (pts == 0 ? null : pts);
            return GestureDetector(
              onTap: () => setState(() => _pointsAwarded = pts == 0 ? null : pts),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.gold : Colors.white12,
                  ),
                ),
                child: Text(
                  pts == 0 ? 'Sin puntos' : '+$pts pts',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? AppColors.gold : AppColors.textSecondaryDark,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required void Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? AppColors.primary.withValues(alpha: 0.3) : Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? AppColors.primary : AppColors.textSecondaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Anterior'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: BlocBuilder<PromotionsBloc, PromotionsState>(
              builder: (context, state) {
                final isLoading = state is PromotionOperationLoading;
                return GradientButton(
                  onPressed: isLoading ? null : _handleNext,
                  isLoading: isLoading,
                  child: Text(_currentStep == 3 ? (_isEditing ? 'Guardar' : 'Publicar') : 'Siguiente'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.titleSmall.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _handleNext() {
    if (_currentStep < 3) {
      if (_currentStep == 0 && !_validateStep1()) return;
      if (_currentStep == 1 && !_validateStep2()) return;
      setState(() => _currentStep++);
    } else {
      _submit(); // async — fire and forget; BLoC emits state on completion
    }
  }

  bool _validateStep1() {
    if (_titleController.text.trim().isEmpty) {
      _showError('Ingresá un título para la promoción');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_discountType != DiscountType.freeItem &&
        _discountType != DiscountType.twoForOne &&
        _discountValueController.text.isEmpty) {
      _showError('Ingresá el valor del descuento');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    List<String> imageUrls = widget.existing?.imageUrls ?? [];

    if (_coverImageFile != null) {
      setState(() => _uploadingImage = true);
      try {
        final svc = GetIt.instance<ImageUploadService>();
        final tempId = widget.existing?.id.isNotEmpty == true
            ? widget.existing!.id
            : DateTime.now().millisecondsSinceEpoch.toString();
        final url = await svc.uploadPromotionImage(
          promotionId: tempId,
          file: _coverImageFile!,
        );
        final existing = imageUrls.isNotEmpty ? imageUrls.first : null;
        imageUrls = [url, ...imageUrls.where((u) => u != existing)];
      } catch (_) {
        // non-fatal — proceed without image
      } finally {
        if (mounted) setState(() => _uploadingImage = false);
      }
    }

    final promotion = PromotionEntity(
      id: widget.existing?.id ?? '',
      commerceId: widget.commerceId,
      commerceName: widget.existing?.commerceName ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      type: _type,
      status: PromotionStatus.active,
      discountType: _discountType,
      discountValue: double.tryParse(_discountValueController.text) ?? 0.0,
      startDate: _startDate,
      endDate: _endDate,
      totalSlots: int.tryParse(_totalSlotsController.text),
      perUserLimit: int.tryParse(_perUserLimitController.text) ?? 1,
      isExclusiveForFollowers: _isExclusiveForFollowers,
      isVip: _isVip,
      requiresCode: _requiresCode,
      promoCode: _requiresCode ? _promoCodeController.text.trim() : null,
      conditions: _conditionsController.text.trim().isEmpty
          ? null
          : _conditionsController.text.trim(),
      originalPrice: double.tryParse(_originalPriceController.text) ?? 0.0,
      discountedPrice: double.tryParse(_discountedPriceController.text),
      pointsAwarded: _pointsAwarded,
      categories: _selectedCategories,
      imageUrls: imageUrls,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    if (!mounted) return;
    if (_isEditing) {
      context.read<PromotionsBloc>().add(UpdatePromotion(promotion));
    } else {
      context.read<PromotionsBloc>().add(CreatePromotion(promotion));
    }
  }

  String _typeLabel(PromotionType type) {
    const labels = {
      PromotionType.discount: 'Descuento',
      PromotionType.twoForOne: '2x1',
      PromotionType.freeItem: 'Producto gratis',
      PromotionType.happyHour: 'Happy Hour',
      PromotionType.cashback: 'Cashback',
      PromotionType.fidelity: 'Fidelidad',
      PromotionType.combo: 'Combo',
      PromotionType.event: 'Evento',
    };
    return labels[type] ?? type.name;
  }

  String _discountTypeLabel(DiscountType type) {
    const labels = {
      DiscountType.percentage: '%',
      DiscountType.fixedAmount: '\$',
      DiscountType.twoForOne: '2x1',
      DiscountType.freeItem: 'Gratis',
    };
    return labels[type] ?? type.name;
  }
}
