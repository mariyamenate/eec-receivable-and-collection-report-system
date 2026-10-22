import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/report_history_entry.dart';
import '../../services/workflow_report_service.dart';
import '../../widgets/role_scaffold.dart';

/// Report history — audit log of actions taken on reports
/// (who did what, when, and what status it moved from/to).
class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  static const Color _primary = Color(0xFF0D7377);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _muted = Color(0xFF6B7280);

  List<ReportHistoryEntry> _entries = [];
  bool _loading = true;
  String? _error;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _projectController = TextEditingController();
  String? _appliedProjectQuery;

  int _page = 1;
  int _pageSize = 20;
  int _totalRecords = 0;
  int get _totalPages => (_totalRecords / _pageSize).ceil().clamp(1, 999999);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _projectController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await WorkflowReportService.getHistory(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        projectQuery: _appliedProjectQuery,
        page: _page,
        pageSize: _pageSize,
      );
      setState(() {
        _entries = result.entries;
        _totalRecords = result.total;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _dateFrom : _dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _appliedProjectQuery =
      _projectController.text.trim().isEmpty ? null : _projectController.text.trim();
      _page = 1;
    });
    _load();
  }

  void _resetFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _projectController.clear();
      _appliedProjectQuery = null;
      _page = 1;
    });
    _load();
  }

  Future<void> _exportCsv() async {
    try {
      final result = await WorkflowReportService.exportHistoryCsv(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        projectQuery: _appliedProjectQuery,
      );

      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Export failed.')),
          );
        }
        return;
      }

      // `result['data']` is either raw CSV text or a { "url": "..." } map,
      // depending on what export_history.php returns. Hook up whichever
      // your backend implements — e.g. write CSV text to disk with
      // path_provider + share_plus, or open the url with url_launcher.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export ready.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Color _actionColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('reject')) return Colors.red;
    if (a.contains('approve')) return Colors.green;
    if (a.contains('submit')) return _primary;
    return _muted;
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Report History',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Report history',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _primary),
            ),
            const SizedBox(height: 4),
            Text(
              '$_totalRecords records · page $_page of $_totalPages · your actions only',
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 16),

            // Filter bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  _buildDateField(
                    label: 'Date from',
                    value: _dateFrom,
                    onTap: () => _pickDate(isFrom: true),
                  ),
                  _buildDateField(
                    label: 'Date to',
                    value: _dateTo,
                    onTap: () => _pickDate(isFrom: false),
                  ),
                  SizedBox(
                    width: 220,
                    child: _buildLabeledField(
                      label: 'Project name',
                      child: TextField(
                        controller: _projectController,
                        decoration: const InputDecoration(
                          hintText: 'Search project...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Filter'),
                  ),
                  OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reset'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Export Excel (CSV)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Table
            _loading
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: _primary)),
            )
                : _error != null
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Text(_error!),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
                : _buildTable(),

            if (!_loading && _error == null) ...[
              const SizedBox(height: 12),
              _buildPager(),
              const SizedBox(height: 20),
              _buildFooterNote(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted, letterSpacing: 0.4),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDateField({required String label, required DateTime? value, required VoidCallback onTap}) {
    return SizedBox(
      width: 160,
      child: _buildLabeledField(
        label: label,
        child: InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value != null ? DateFormat('MM/dd/yyyy').format(value) : 'mm/dd/yyyy',
                  style: TextStyle(color: value != null ? Colors.black87 : Colors.grey.shade500),
                ),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text('No history entries match these filters.', style: TextStyle(color: _muted))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFFAFAFA)),
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _muted,
            letterSpacing: 0.5,
          ),
          dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
          columnSpacing: 28,
          columns: const [
            DataColumn(label: Text('WHEN')),
            DataColumn(label: Text('ACTOR')),
            DataColumn(label: Text('ROLE')),
            DataColumn(label: Text('PROJECT')),
            DataColumn(label: Text('ACTION')),
            DataColumn(label: Text('FROM → TO')),
            DataColumn(label: Text('REMARK')),
          ],
          rows: _entries.map((e) {
            return DataRow(cells: [
              DataCell(Text(DateFormat('yyyy-MM-dd').format(e.when))),
              DataCell(Text(e.actorName)),
              DataCell(_roleChip(e.role)),
              DataCell(Text(e.projectName ?? '—')),
              DataCell(
                Text(
                  e.action,
                  style: TextStyle(color: _actionColor(e.action), fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(Text('${e.fromStatus ?? '—'} → ${e.toStatus ?? '—'}')),
              DataCell(Text(e.remark ?? '—')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _roleChip(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
      ),
    );
  }

  Widget _buildPager() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _page > 1
              ? () {
            setState(() => _page--);
            _load();
          }
              : null,
        ),
        Text('Page $_page of $_totalPages', style: const TextStyle(color: _muted)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _page < _totalPages
              ? () {
            setState(() => _page++);
            _load();
          }
              : null,
        ),
      ],
    );
  }

  Widget _buildFooterNote() {
    // Static explanatory note, same idea as in the reference design.
    // Adjust the copy to whatever's accurate for your org structure.
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 12, color: _muted),
          children: [
            TextSpan(text: 'Structure: '),
            TextSpan(text: '4 Business Units', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
            TextSpan(text: ' — only '),
            TextSpan(text: 'Consultancy', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
            TextSpan(text: ' has 3 sectors (Transport, Water & Energy, Building and Urban). '
                'Each sector Sub Total + Consultancy Total + other BU totals → '),
            TextSpan(text: '1 Grand Total', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
            TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}