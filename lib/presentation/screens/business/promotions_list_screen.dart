import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../blocs/promotions/promotions_bloc.dart';

class PromotionsListScreen extends StatefulWidget {
  final String commerceId;

  const PromotionsListScreen({super.key, required this.commerceId});

  @override
  State<PromotionsListScreen> createState() => _PromotionsListScreenState();
}

class _PromotionsListScreenState extends State<PromotionsListScreen> {
  PromotionStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    context
        .read<PromotionsBloc>()
        .add(LoadCommercePromotions(commerceId: widget.commerceId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Todas las promociones'),
        backgroundColor: AppColors.backgroundCard,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva promoción',
            onPressed: () => context
                .push('/commerce/${widget.commerceId}/create-promotion'),
          ),
        ],
      ),
      body: BlocListener<PromotionsBloc, PromotionsState>(
        listener: (context, state) {
          if (state is PromotionDeleted || state is PromotionStatusChanged) {
            context.read<PromotionsBloc>().add(
                  LoadCommercePromotions(commerceId: widget.commerceId),
                );
          }
          if (state is PromotionsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: Column(
          children: [
            _buildFilterChips(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final statuses = [
      null,
      PromotionStatus.active,
      PromotionStatus.paused,
      PromotionStatus.expired,
    ];
    const labels = ['Todas', 'Activas', 'Pausadas', 'Expiradas'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(statuses.length, (i) {
          final selected = _filterStatus == statuses[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (_) => setState(() => _filterStatus = statuses[i]),
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
              labelStyle: AppTextStyles.bodySmall.copyWith(
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
              ),
              backgroundColor: AppColors.backgroundCard,
              side: BorderSide(
                color: selected
                    ? AppColors.primary
                    : const Color(0xFF1E293B),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildList() {
    return BlocBuilder<PromotionsBloc, PromotionsState>(
      builder: (context, state) {
        if (state is PromotionsLoading || state is PromotionOperationLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final all =
            state is PromotionsLoaded ? state.promotions : <PromotionEntity>[];
        final filtered = _filterStatus == null
            ? all
            : all.where((p) => p.status == _filterStatus).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  size: 56,
                  color: AppColors.textSecondaryDark,
                ),
                const SizedBox(height: 16),
                Text(
                  _filterStatus != null
                      ? 'Sin promociones en este estado'
                      : 'Sin promociones creadas',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => context.push(
                      '/commerce/${widget.commerceId}/create-promotion'),
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  label: Text(
                    'Crear promoción',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _buildTile(context, filtered[i]),
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, PromotionEntity promotion) {
    final isActive = promotion.status == PromotionStatus.active;
    final isPaused = promotion.status == PromotionStatus.paused;
    final statusColor = isActive
        ? AppColors.success
        : isPaused
            ? AppColors.accent
            : AppColors.textSecondaryDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.title,
                  style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _statusLabel(promotion.status),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${promotion.usedSlots}'
                      '${promotion.totalSlots != null ? "/${promotion.totalSlots}" : ""}'
                      ' usos',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textSecondaryDark,
              size: 20,
            ),
            color: AppColors.backgroundSurface,
            onSelected: (value) => _handleAction(context, value, promotion),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(
                  'Editar',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: Colors.white),
                ),
              ),
              if (isActive)
                PopupMenuItem(
                  value: 'pause',
                  child: Text(
                    'Pausar',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.warning),
                  ),
                )
              else if (isPaused)
                PopupMenuItem(
                  value: 'activate',
                  child: Text(
                    'Activar',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.success),
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Eliminar',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAction(
      BuildContext context, String action, PromotionEntity promotion) {
    switch (action) {
      case 'edit':
        context.push(
          '/commerce/${widget.commerceId}/edit-promotion/${promotion.id}',
          extra: promotion,
        );
      case 'pause':
        context.read<PromotionsBloc>().add(ChangePromotionStatus(
              promotionId: promotion.id,
              status: PromotionStatus.paused,
            ));
      case 'activate':
        context.read<PromotionsBloc>().add(ChangePromotionStatus(
              promotionId: promotion.id,
              status: PromotionStatus.active,
            ));
      case 'delete':
        _confirmDelete(context, promotion);
    }
  }

  void _confirmDelete(BuildContext context, PromotionEntity promotion) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar promoción',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        content: Text(
          '¿Eliminar "${promotion.title}"? Esta acción no se puede deshacer.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context
                  .read<PromotionsBloc>()
                  .add(DeletePromotion(promotion.id));
            },
            child: Text(
              'Eliminar',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(PromotionStatus status) => switch (status) {
        PromotionStatus.active => 'Activa',
        PromotionStatus.paused => 'Pausada',
        PromotionStatus.expired => 'Expirada',
        PromotionStatus.draft => 'Borrador',
        PromotionStatus.cancelled => 'Cancelada',
        PromotionStatus.scheduled => 'Programada',
      };
}
