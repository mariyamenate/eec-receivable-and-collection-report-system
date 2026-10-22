// lib/widgets/home_dashboard.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/lang_controller.dart';



class StatusStat {
  final int count;
  final double amount;
  const StatusStat(this.count, this.amount);
}

class DashboardStats {
  final double totalOutstanding;
  final double weekCollections;
  final double? planAchievement; // percent (0-100); null = no plan set
  final Map<String, StatusStat> status; // received, pending, draft, returned
  final List<MapEntry<String, double>> weekly; // (week start, amount)
  final List<MapEntry<String, double>> sectors; // (sector name, outstanding)

  const DashboardStats({
    required this.totalOutstanding,
    required this.weekCollections,
    required this.planAchievement,
    required this.status,
    required this.weekly,
    required this.sectors,
  });

  factory DashboardStats.empty() => const DashboardStats(
    totalOutstanding: 0,
    weekCollections: 0,
    planAchievement: null,
    status: {},
    weekly: [],
    sectors: [],
  );

  int get totalReports => status.values.fold(0, (a, b) => a + b.count);


  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    final st = <String, StatusStat>{};
    (j['status'] as Map? ?? {}).forEach((k, v) {
      st['$k'] = StatusStat((v['count'] as num?)?.toInt() ?? 0, d(v['amount']));
    });
    return DashboardStats(
      totalOutstanding: d(j['total_outstanding']),
      weekCollections: d(j['week_collections']),
      planAchievement:
      j['plan_achievement'] == null ? null : d(j['plan_achievement']),
      status: st,
      weekly: [
        for (final w in (j['weekly'] as List? ?? []))
          MapEntry('${w['week']}', d(w['amount']))
      ],
      sectors: [
        for (final s in (j['sectors'] as List? ?? []))
          MapEntry('${s['name']}', d(s['outstanding']))
      ],
    );
  }
}



class HomeDashboardController extends GetxController {

  static const bool useSampleData = true;

  final String role;
  HomeDashboardController({required this.role});

  final stats = Rxn<DashboardStats>();
  final isLoading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      stats.value = useSampleData ? _sample() : await _fetch();
    } catch (e) {
      error.value = '$e';
      stats.value ??= DashboardStats.empty();
    } finally {
      isLoading.value = false;
    }
  }

  Future<DashboardStats> _fetch() async {

    throw UnimplementedError('Dashboard endpoint not wired yet');
  }

  DashboardStats _sample() => const DashboardStats(
    totalOutstanding: 4800000,
    weekCollections: 620000,
    planAchievement: 78,
    status: {
      'received': StatusStat(12, 410000),
      'pending': StatusStat(5, 150000),
      'draft': StatusStat(3, 0),
      'returned': StatusStat(2, 60000),
    },
    weekly: [
      MapEntry('2026-08-03', 450000),
      MapEntry('2026-08-10', 620000),
      MapEntry('2026-08-17', 380000),
      MapEntry('2026-08-24', 800000),
      MapEntry('2026-08-31', 620000),
    ],
    sectors: [
      MapEntry('Construction', 1800000),
      MapEntry('Real estate', 1200000),
      MapEntry('Manufacturing', 800000),
      MapEntry('Trading', 450000),
    ],
  );
}



class HomeDashboard extends StatelessWidget {
  final String role;
  final VoidCallback? onStatusTap;
  const HomeDashboard({super.key, required this.role, this.onStatusTap});

  static const _primary = Color(0xFF0D7377);
  static const _green = Color(0xFF2E9E6B);
  static const _amber = Color(0xFFF2A33A);
  static const _blue = Color(0xFF3B82C4);
  static const _red = Color(0xFFD64545);

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HomeDashboardController>(tag: role);
    final lang = Get.find<LangController>();

    return Obx(() {
      final am = lang.isAmharic;
      String t(String en, String amh) => am ? amh : en;
      final s = c.stats.value;

      if (s == null) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      return LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final kpiCols = w >= 600 ? 3 : 1;
        final statusCols = w >= 600 ? 4 : 2;
        final chartCols = w >= 900 ? 3 : (w >= 600 ? 2 : 1);

        Widget grid(List<Widget> kids, int cols) {
          const gap = 12.0;
          final cw = (w - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final k in kids) SizedBox(width: cw, child: k)],
          );
        }

        StatusStat st(String k) => s.status[k] ?? const StatusStat(0, 0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            grid([
              _kpi(t('Total Outstanding Receivables', 'ጠቅላላ ያልተሰበሰበ ሂሳብ'),
                  _etb(s.totalOutstanding)),
              _kpi(t("This Week's Collections", 'የዚህ ሳምንት ስብሰባ'),
                  _etb(s.weekCollections)),
              _kpi(
                t('Week Plan Achievement', 'የሳምንቱ እቅድ አፈጻጸም'),
                s.planAchievement == null
                    ? '–'
                    : '${s.planAchievement!.toStringAsFixed(0)}%',
                progress: s.planAchievement == null
                    ? null
                    : (s.planAchievement! / 100).clamp(0.0, 1.0),
              ),
            ], kpiCols),
            const SizedBox(height: 16),
            grid([
              _statusCard(t('Received', 'ተቀብሏል'), Icons.check_circle_outline,
                  _green, st('received'), onStatusTap),
              _statusCard(t('Pending', 'በመጠባበቅ ላይ'), Icons.schedule, _amber,
                  st('pending'), onStatusTap),
              _statusCard(t('Draft', 'ረቂቅ'), Icons.edit_note, _blue,
                  st('draft'), onStatusTap),
              _statusCard(t('Returned', 'ተመልሷል'), Icons.undo, _red,
                  st('returned'), onStatusTap),
            ], statusCols),
            const SizedBox(height: 16),
            grid([
              _chartCard(
                t('Weekly Collections (ETB)', 'ሳምንታዊ ስብሰባ (ብር)'),
                _weeklyChart(s, t('No data', 'መረጃ የለም')),
              ),
              _chartCard(
                t('Report Status This Week', 'የሪፖርት ሁኔታ'),
                _statusDonut(s, t),
              ),
              _chartCard(
                t('Top Sectors by Outstanding', 'ከፍተኛ ያልተሰበሰበ ዘርፎች'),
                _sectorBars(s, t('No data', 'መረጃ የለም')),
              ),
            ], chartCols),
          ],
        );
      });
    });
  }

  // ── helpers ──

  static String _etb(double v) =>
      'ETB ${NumberFormat.compact().format(v)}';

  static Widget _kpi(String label, String value, {double? progress}) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: _primary,
                backgroundColor: _primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  static Widget _statusCard(String label, IconData icon, Color color,
      StatusStat stat, VoidCallback? onTap) =>
      Card(
        margin: EdgeInsets.zero,
        color: color.withValues(alpha: 0.10),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: 0.25))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('${stat.count}',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: color)),
                Text(stat.amount > 0 ? _etb(stat.amount) : ' ',
                    style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ),
      );

  static Widget _chartCard(String title, Widget child) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(height: 190, child: child),
        ],
      ),
    ),
  );

  static Widget _empty(String msg) => Center(
    child: Text(msg, style: const TextStyle(color: Colors.grey)),
  );

  static Widget _weeklyChart(DashboardStats s, String noData) {
    final data = s.weekly.length > 6
        ? s.weekly.sublist(s.weekly.length - 6)
        : s.weekly;
    if (data.isEmpty || data.every((e) => e.value == 0)) return _empty(noData);
    final compact = NumberFormat.compact();
    return BarChart(
      BarChartData(
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, m) => Text(compact.format(v),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox();
                final k = data[i].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(k.length >= 10 ? k.substring(5) : k,
                      style:
                      const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: data[i].value,
                width: 16,
                color: _primary,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      ),
    );
  }

  static Widget _statusDonut(
      DashboardStats s, String Function(String, String) t) {
    final items = [
      ('received', t('Received', 'ተቀብሏል'), _green),
      ('pending', t('Pending', 'በመጠባበቅ ላይ'), _amber),
      ('draft', t('Draft', 'ረቂቅ'), _blue),
      ('returned', t('Returned', 'ተመልሷል'), _red),
    ];
    final total = s.totalReports;
    return Row(
      children: [
        Expanded(
          child: total == 0
              ? Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 36,
              sections: [
                PieChartSectionData(
                    value: 1,
                    color: Colors.grey.shade200,
                    radius: 22,
                    showTitle: false),
              ],
            )),
            Text(t('No data', 'መረጃ የለም'),
                style: const TextStyle(color: Colors.grey)),
          ])
              : Stack(alignment: Alignment.center, children: [
            PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (final it in items)
                  if ((s.status[it.$1]?.count ?? 0) > 0)
                    PieChartSectionData(
                      value: s.status[it.$1]!.count.toDouble(),
                      color: it.$3,
                      radius: 22,
                      showTitle: false,
                    ),
              ],
            )),
            Text('$total',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: it.$3, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text('${it.$2} (${s.status[it.$1]?.count ?? 0})',
                      style: const TextStyle(fontSize: 12)),
                ]),
              ),
          ],
        ),
      ],
    );
  }

  static Widget _sectorBars(DashboardStats s, String noData) {
    final data = s.sectors.take(5).toList();
    if (data.isEmpty || data.every((e) => e.value == 0)) return _empty(noData);
    final max = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in data)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      child: Text(e.key,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))),
                  Text(NumberFormat.compact().format(e.value),
                      style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : e.value / max,
                  minHeight: 8,
                  color: _primary,
                  backgroundColor: _primary.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
      ],
    );
  }
}