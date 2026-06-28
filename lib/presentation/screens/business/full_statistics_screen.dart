import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/repositories/commerce_repository.dart';

class FullStatisticsScreen extends StatefulWidget {
  final String commerceId;
  final String commerceName;

  const FullStatisticsScreen({
    super.key,
    required this.commerceId,
    required this.commerceName,
  });

  @override
  State<FullStatisticsScreen> createState() => _FullStatisticsScreenState();
}

class _FullStatisticsScreenState extends State<FullStatisticsScreen> {
  final _repo = GetIt.instance<CommerceRepository>();

  String _period = 'week';
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _analytics = {};
  List<int> _dailyCounts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final analyticsF = _repo.getCommerceAnalytics(
      commerceId: widget.commerceId,
      period: _period,
    );
    final chartF = _repo.getDailyCouponCounts(commerceId: widget.commerceId);

    final analyticsResult = await analyticsF;
    final chartResult = await chartF;

    if (!mounted) return;

    analyticsResult.fold(
      (f) => setState(() {
        _error = f.message;
        _loading = false;
      }),
      (data) {
        _analytics = data;
        chartResult.fold(
          (_) => null,
          (counts) => _dailyCounts = counts,
        );
        setState(() => _loading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Text(
          'Estadísticas',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _loading
                ? _buildShimmer()
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = [
      ('day', 'Hoy'),
      ('week', 'Semana'),
      ('month', 'Mes'),
    ];
    return Container(
      color: AppColors.backgroundCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: periods.map((p) {
          final selected = _period == p.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (_period != p.$1) {
                  setState(() => _period = p.$1);
                  _load();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.$2,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondaryDark,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    final claimed = _analytics['claimed'] as int? ?? 0;
    final redeemed = _analytics['redeemed'] as int? ?? 0;
    final conversionRate = _analytics['conversionRate'] as int? ?? 0;
    final totalPoints = _analytics['totalPointsGiven'] as int? ?? 0;
    final followers = _analytics['followerCount'] as int? ?? 0;
    final activePromos = _analytics['activePromotions'] as int? ?? 0;
    final totalRedemptions = _analytics['totalRedemptions'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Resumen del período'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildMetricCard(
                '$claimed',
                'Cupones reclamados',
                Icons.confirmation_num_outlined,
                AppColors.primary,
              ),
              _buildMetricCard(
                '$redeemed',
                'Cupones canjeados',
                Icons.check_circle_outline,
                AppColors.success,
              ),
              _buildMetricCard(
                '$conversionRate%',
                'Tasa de conversión',
                Icons.trending_up,
                AppColors.accent,
              ),
              _buildMetricCard(
                '$totalPoints pts',
                'Puntos otorgados',
                Icons.star_outline,
                AppColors.gold,
              ),
              _buildMetricCard(
                '$followers',
                'Seguidores',
                Icons.people_outline,
                AppColors.accentGreen,
              ),
              _buildMetricCard(
                '$activePromos',
                'Promos activas',
                Icons.local_offer_outlined,
                AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMetricCard(
            '$totalRedemptions',
            'Total de canjes histórico',
            Icons.history,
            AppColors.textSecondaryDark,
            fullWidth: true,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Actividad diaria (últimos 30 días)'),
          const SizedBox(height: 12),
          _buildChart(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String value,
    String label,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_dailyCounts.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            'Sin datos',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondaryDark),
          ),
        ),
      );
    }

    final periodDays = _period == 'day' ? 1 : _period == 'week' ? 7 : 30;
    final data = _dailyCounts.length >= periodDays
        ? _dailyCounts.sublist(_dailyCounts.length - periodDays)
        : _dailyCounts;
    final maxY =
        (data.reduce((a, b) => a > b ? a : b).toDouble() * 1.2).clamp(4.0, double.infinity);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withOpacity(0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondaryDark),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                data.length,
                (i) => FlSpot(i.toDouble(), data[i].toDouble()),
              ),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: AppColors.textSecondaryDark.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Error al cargar estadísticas',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondaryDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.backgroundCard,
      highlightColor: AppColors.backgroundSurface,
      child: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: List.generate(
          6,
          (_) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
