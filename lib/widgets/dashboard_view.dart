// lib/widgets/dashboard_view.dart
// Needs:  flutter pub add fl_chart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../models/dashboard_data.dart';

class DashboardView extends StatefulWidget {
  final String role; // 'collector' | 'senior_accountant' | 'team_leader' | 'superadmin'
  final String? userId;

  const DashboardView({super.key, required this.role, this.userId});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  static const Color _primary = Color(0xFF0D7377);
  static const Color _teal = Color(0xFF0AA8C0);

  late final DashboardController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(
      DashboardController(role: widget.role, userId: widget.userId),
      tag: widget.role,
    );
  }

  @override
  void dispose() {
    Get.delete<DashboardController>(tag: widget.role);
    super.dispose();
  }

  // ---------- formatting ----------
  String _money(double v) {
    final s = v.round().toString();
    final withCommas =
    s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${'currency_etb'.tr} $withCommas';
  }

  String _compact(double v) {
    String t(double x) {
      final s = x.toStringAsFixed(1);
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }

    if (v >= 1e6) return '${t(v / 1e6)}M';
    if (v >= 1e3) return '${t(v / 1e3)}K';
    return v.toStringAsFixed(0);
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final d = _c.data.value;
      return RefreshIndicator(
        onRefresh: _c.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_c.isLoading.value)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            _row([
              _kpi('total_outstanding'.tr, _money(d.outstanding)),
              _kpi('this_week_collections'.tr, _money(d.weekCollections)),
              _kpi(
                'week_plan_achievement'.tr,
                d.planAchievementPct == null
                    ? '–'
                    : '${d.planAchievementPct!.toStringAsFixed(0)}%',
              ),
            ], height: 120),
            const SizedBox(height: 16),
            _row([
              _chartCard('weekly_collections_etb'.tr, _weeklyChart(d)),
              _chartCard('report_status_this_week'.tr, _statusChart(d)),
              _chartCard('top_sectors_outstanding'.tr, _sectorsList(d)),
            ], height: 340),
          ],
        ),
      );
    });
  }

  /// 3 columns on wide screens, stacked on narrow ones.
  Widget _row(List<Widget> children, {required double height}) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 800) {
        return SizedBox(
          height: height,
          child: Row(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      }
      return Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            SizedBox(height: height, child: children[i]),
          ],
        ],
      );
    });
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _kpi(String label, String value) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111B2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(String title, Widget body) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _empty() => Center(
    child: Text('no_data'.tr,
        style: TextStyle(color: Colors.grey.shade500)),
  );

  // ---------- Weekly collections (bar) ----------
  Widget _weeklyChart(DashboardData d) {
    if (d.weekly.isEmpty) return _empty();

    final maxV = d.weekly.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY / 5,
              getTitlesWidget: (v, meta) => Text(
                _compact(v),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= d.weekly.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    d.weekly[i].label,
                    style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < d.weekly.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: d.weekly[i].amount,
                color: _teal,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
      ),
    );
  }

  // ---------- Report status (donut) ----------
  Widget _statusChart(DashboardData d) {
    final entries = <MapEntry<String, Color>>[
      const MapEntry('draft', Color(0xFF9AA5B1)),
      const MapEntry('submitted', Color(0xFF0AA8C0)),
      const MapEntry('received', Color(0xFF2E9E6B)),
      const MapEntry('returned', Color(0xFFE0A030)),
    ];
    final total =
    entries.fold<int>(0, (s, e) => s + (d.statusCounts[e.key] ?? 0));

    final sections = total == 0
        ? [
      PieChartSectionData(
        value: 1,
        color: _teal,
        radius: 30,
        showTitle: false,
      ),
    ]
        : [
      for (final e in entries)
        if ((d.statusCounts[e.key] ?? 0) > 0)
          PieChartSectionData(
            value: d.statusCounts[e.key]!.toDouble(),
            color: e.value,
            radius: 30,
            showTitle: false,
          ),
    ];

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: total == 0 ? 0 : 2,
              centerSpaceRadius: 60,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: total == 0
              ? [_legend(_teal, 'no_data'.tr)]
              : [
            for (final e in entries)
              if ((d.statusCounts[e.key] ?? 0) > 0)
                _legend(e.value,
                    '${e.key.tr} (${d.statusCounts[e.key]})'),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color c, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: c),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  // ---------- Top sectors ----------
  Widget _sectorsList(DashboardData d) {
    if (d.topSectors.isEmpty) return _empty();

    final maxV =
    d.topSectors.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    return ListView(
      children: [
        for (final s in d.topSectors)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(s.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    Text(_compact(s.amount),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxV <= 0 ? 0 : s.amount / maxV,
                    minHeight: 10,
                    color: _primary,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}