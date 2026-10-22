import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/collection_data.dart';
import '../../services/collection_service.dart'; // use your real collection service
import '../../widgets/role_scaffold.dart';

/// Collector — fill / review collection summary and submit to Senior Accountant.
/// Does NOT send to Team Leader and does NOT reject (that is SA).
class BuildTemplateScreen extends StatefulWidget {
  final List<CollectionData> collections;

  /// If true, this is an edit of an existing draft/rejected collection.
  final bool isResubmit;

  const BuildTemplateScreen({
    super.key,
    required this.collections,
    this.isResubmit = false,
  });

  @override
  State<BuildTemplateScreen> createState() => _BuildTemplateScreenState();
}

class _BuildTemplateScreenState extends State<BuildTemplateScreen> {
  static const Color _primary = Color(0xFF0D7377);

  final _reportNameCtrl = TextEditingController();
  final _referenceNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _voucherType = 'Milestone';

  String? _filePath;
  String? _fileName;

  bool _saving = false;
  bool _submitting = false;

  final _dateFormat = DateFormat('MM/dd/yyyy');
  final _numberFormat = NumberFormat('#,##0.00');

  final List<String> _sectorOrder = const [
    'Transport Sector',
    'Water and Energy Sector',
    'Building and Urban Sector',
    'Construction Sector',
  ];

  final Map<String, _SectorSummary> _sectors = {};

  @override
  void initState() {
    super.initState();
    _aggregateCollectorReports();
  }

  @override
  void dispose() {
    _reportNameCtrl.dispose();
    _referenceNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _aggregateCollectorReports() {
    for (final sectorName in _sectorOrder) {
      _sectors[sectorName] = _SectorSummary(name: sectorName);
    }

    if (widget.collections.isEmpty) {
      _reportNameCtrl.text = 'Receivables and Collection Report';
      return;
    }

    final first = widget.collections.first;
    _startDate = first.periodFrom;
    _endDate = first.periodTo;

    final periodLabel = first.period.trim().isNotEmpty
        ? first.period
        : DateFormat('MMM yyyy').format(DateTime.now());

    _reportNameCtrl.text = 'Receivables and Collection Report — $periodLabel';

    for (final collection in widget.collections) {
      final sectorName = _resolveSectorName(collection.sectorName);
      _sectors.putIfAbsent(
        sectorName,
            () => _SectorSummary(name: sectorName),
      );
      final sector = _sectors[sectorName]!;

      final raw = collection.rows;
      if (raw == null || raw is! Map) continue;

      final payload = Map<String, dynamic>.from(raw);

      if (_referenceNumberCtrl.text.isEmpty &&
          payload['reference_number'] != null) {
        _referenceNumberCtrl.text = payload['reference_number'].toString();
      }

      final reportName = payload['report_name']?.toString().trim();
      if (reportName != null &&
          reportName.isNotEmpty &&
          !_reportNameCtrl.text.contains(reportName)) {
        _reportNameCtrl.text = reportName;
      }

      final voucherType = payload['voucher_type']?.toString();
      if (voucherType != null &&
          ['Milestone', 'Percentage', 'Lump Sum'].contains(voucherType)) {
        _voucherType = voucherType;
      }

      final submittedRows = payload['rows'];
      if (submittedRows is! Map) continue;

      final rowMap = Map<String, dynamic>.from(submittedRows);
      sector.currentPeriod.addFrom(_mapValue(rowMap['current_period']));
      sector.advancePayment.addFrom(_mapValue(rowMap['advance_current_year']));
      sector.advancePayment.addFrom(_mapValue(rowMap['advance_previous_year']));
      sector.previousYears.addFrom(_mapValue(rowMap['previous_years']));
    }
  }

  String _resolveSectorName(String? sourceName) {
    final normalized = (sourceName ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (normalized.contains('transport')) return 'Transport Sector';
    if (normalized.contains('water') || normalized.contains('energy')) {
      return 'Water and Energy Sector';
    }
    if (normalized.contains('building') || normalized.contains('urban')) {
      return 'Building and Urban Sector';
    }
    if (normalized.contains('construction')) return 'Construction Sector';

    return sourceName == null || sourceName.trim().isEmpty
        ? 'Other Sector'
        : sourceName.trim();
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool _isConsultancySector(String sectorName) {
    return sectorName == 'Transport Sector' ||
        sectorName == 'Water and Energy Sector' ||
        sectorName == 'Building and Urban Sector';
  }

  _Totals _consultancyTotal() {
    final total = _Totals();
    for (final sector in _sectors.values) {
      if (_isConsultancySector(sector.name)) {
        total.add(sector.currentPeriod);
        total.add(sector.previousYears);
      }
    }
    return total;
  }

  _Totals _allCurrentPeriod() {
    final total = _Totals();
    for (final sector in _sectors.values) {
      total.add(sector.currentPeriod);
    }
    return total;
  }

  _Totals _allAdvancePayment() {
    final total = _Totals();
    for (final sector in _sectors.values) {
      total.add(sector.advancePayment);
    }
    return total;
  }

  _Totals _allPreviousYears() {
    final total = _Totals();
    for (final sector in _sectors.values) {
      total.add(sector.previousYears);
    }
    return total;
  }

  _Totals _grandTotal() {
    final total = _Totals();
    total.add(_allCurrentPeriod());
    total.add(_allAdvancePayment());
    total.add(_allPreviousYears());
    return total;
  }

  double _percentOfTotalReceivable(_Totals row, _Totals grandTotal) {
    if (grandTotal.requested == 0) return 0;
    return (row.requested / grandTotal.requested) * 100;
  }

  double _weekPlanPercent(_Totals row) {
    if (row.requested == 0) return 0;
    return (row.weekPlan / row.requested) * 100;
  }

  Map<String, dynamic> _rowToJson({
    required String label,
    required _Totals totals,
    required _Totals grandTotal,
    bool isTotal = false,
  }) {
    return {
      'label': label,
      'requested': totals.requested,
      'week_plan': totals.weekPlan,
      'week_collected': totals.weekCollected,
      'ytd_plan': totals.ytdPlan,
      'ytd_collected': totals.ytdCollected,
      'remaining': totals.remaining,
      'percent_total_receivable':
      _percentOfTotalReceivable(totals, grandTotal),
      'week_plan_percent': _weekPlanPercent(totals),
      'is_total': isTotal,
    };
  }

  Map<String, dynamic> _buildPayload() {
    final grandTotal = _grandTotal();
    final sectorSections = <Map<String, dynamic>>[];

    for (final sectorName in _sectorOrder) {
      final sector = _sectors[sectorName];
      if (sector == null) continue;

      final sectionRows = <Map<String, dynamic>>[
        _rowToJson(
          label: 'Current Period Receivables',
          totals: sector.currentPeriod,
          grandTotal: grandTotal,
        ),
      ];

      if (sectorName == 'Construction Sector') {
        sectionRows.add(
          _rowToJson(
            label: 'Advance payment Received',
            totals: sector.advancePayment,
            grandTotal: grandTotal,
          ),
        );
      }

      sectionRows.add(
        _rowToJson(
          label: 'Previous Years Receivables',
          totals: sector.previousYears,
          grandTotal: grandTotal,
        ),
      );

      final sectorTotal = _Totals();
      sectorTotal.add(sector.currentPeriod);
      if (sectorName == 'Construction Sector') {
        sectorTotal.add(sector.advancePayment);
      }
      sectorTotal.add(sector.previousYears);

      sectionRows.add(
        _rowToJson(
          label: sectorName == 'Construction Sector'
              ? 'Construction Sector Total'
              : 'Sub Total',
          totals: sectorTotal,
          grandTotal: grandTotal,
          isTotal: true,
        ),
      );

      sectorSections.add({
        'sector_name': sectorName,
        'rows': sectionRows,
      });
    }

    return {
      'report_name': _reportNameCtrl.text.trim(),
      'reference_number': _referenceNumberCtrl.text.trim(),
      'voucher_type': _voucherType,
      'period_from': _startDate?.toIso8601String().split('T').first,
      'period_to': _endDate?.toIso8601String().split('T').first,
      'source_collection_ids':
      widget.collections.map((c) => c.id).toList(),
      'summary_sections': sectorSections,
      'consultancy_sectors_total': _rowToJson(
        label: 'Consultancy Sectors Total',
        totals: _consultancyTotal(),
        grandTotal: grandTotal,
        isTotal: true,
      ),
      'all_sectors_summary': [
        _rowToJson(
          label: 'Current Period Receivables',
          totals: _allCurrentPeriod(),
          grandTotal: grandTotal,
        ),
        _rowToJson(
          label: 'Advance payment Received',
          totals: _allAdvancePayment(),
          grandTotal: grandTotal,
        ),
        _rowToJson(
          label: 'Previous Years Receivables',
          totals: _allPreviousYears(),
          grandTotal: grandTotal,
        ),
        _rowToJson(
          label: 'Grand Total of the 4 Sectors',
          totals: grandTotal,
          grandTotal: grandTotal,
          isTotal: true,
        ),
      ],
      'notes': _notesCtrl.text.trim(),
    };
  }

  Future<void> _pickDate(
      DateTime? current,
      ValueChanged<DateTime> onPicked,
      ) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (selected != null) onPicked(selected);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  /// Save as draft only (still with Collector — not sent to SA).
  Future<void> _saveDraft() async {
    if (_reportNameCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Required',
        'Report name is required.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Wire to your real draft API, e.g.:
      // final result = await CollectionService.saveDraft(
      //   collectionIds: widget.collections.map((c) => c.id).toList(),
      //   payload: _buildPayload(),
      //   filePath: _filePath,
      // );
      //
      // For now, if you only have submit, skip draft or reuse update endpoint.
      final result = await CollectionService.saveOrUpdate(
        collectionIds: widget.collections.map((c) => c.id).toList(),
        title: _reportNameCtrl.text.trim(),
        payload: _buildPayload(),
        filePath: _filePath,
        submit: false, // draft
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Get.snackbar(
          'Saved',
          'Draft saved. You can submit to Senior Accountant when ready.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Could not save draft.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Could not save: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Submit → Senior Accountant (status: submitted).
  Future<void> _submitToSeniorAccountant() async {
    if (_reportNameCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Required',
        'Report name is required.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (widget.collections.isEmpty) {
      Get.snackbar(
        'No data',
        'There is no collection data to submit.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Submit to Senior Accountant?'),
        content: const Text(
          'This collection will be sent to Senior Accountant for review '
              'and for building the Receivables & Collection Template (File 1).',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _submitting = true);
    try {
      // Wire to your real submit API:
      // e.g. CollectionService.submitToSeniorAccountant(...)
      final result = await CollectionService.saveOrUpdate(
        collectionIds: widget.collections.map((c) => c.id).toList(),
        title: _reportNameCtrl.text.trim(),
        payload: _buildPayload(),
        filePath: _filePath,
        submit: true, // mark as submitted → SA Incoming
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Get.snackbar(
          'Submitted',
          'Sent to Senior Accountant.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );
        Get.back(result: true);
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Submit failed.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Could not submit: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }

  Widget _dateField(
      String label,
      DateTime? value,
      ValueChanged<DateTime> onPicked,
      ) {
    return OutlinedButton.icon(
      onPressed: () => _pickDate(value, onPicked),
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(value == null ? label : _dateFormat.format(value)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  DataCell _numberCell(double value, {bool bold = false}) {
    return DataCell(
      Text(
        _numberFormat.format(value),
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  DataRow _headingRow(String title) {
    return DataRow(
      color: WidgetStatePropertyAll(_primary.withValues(alpha: 0.12)),
      cells: [
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
      ],
    );
  }

  DataRow _summaryRow({
    required String label,
    required _Totals totals,
    required _Totals grandTotal,
    bool bold = false,
    Color? backgroundColor,
  }) {
    return DataRow(
      color: backgroundColor == null
          ? null
          : WidgetStatePropertyAll(backgroundColor),
      cells: [
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        _numberCell(totals.requested, bold: bold),
        _numberCell(totals.weekPlan, bold: bold),
        _numberCell(totals.weekCollected, bold: bold),
        _numberCell(totals.ytdPlan, bold: bold),
        _numberCell(totals.ytdCollected, bold: bold),
        _numberCell(totals.remaining, bold: bold),
        _numberCell(_percentOfTotalReceivable(totals, grandTotal), bold: bold),
        _numberCell(_weekPlanPercent(totals), bold: bold),
      ],
    );
  }

  List<DataRow> _tableRows() {
    final grandTotal = _grandTotal();
    final rows = <DataRow>[];
    var number = 1;

    for (final sectorName in _sectorOrder) {
      final sector = _sectors[sectorName];
      if (sector == null) continue;

      rows.add(_headingRow('$number. $sectorName'));
      rows.add(
        _summaryRow(
          label: 'Current Period Receivables',
          totals: sector.currentPeriod,
          grandTotal: grandTotal,
        ),
      );

      if (sectorName == 'Construction Sector') {
        rows.add(
          _summaryRow(
            label: 'Advance payment Received',
            totals: sector.advancePayment,
            grandTotal: grandTotal,
          ),
        );
      }

      rows.add(
        _summaryRow(
          label: 'Previous Years Receivables',
          totals: sector.previousYears,
          grandTotal: grandTotal,
        ),
      );

      final sectorTotal = _Totals();
      sectorTotal.add(sector.currentPeriod);
      if (sectorName == 'Construction Sector') {
        sectorTotal.add(sector.advancePayment);
      }
      sectorTotal.add(sector.previousYears);

      rows.add(
        _summaryRow(
          label: sectorName == 'Construction Sector'
              ? 'Construction Sector Total'
              : 'Sub Total',
          totals: sectorTotal,
          grandTotal: grandTotal,
          bold: true,
          backgroundColor: Colors.grey.shade100,
        ),
      );
      number += 1;
    }

    rows.add(
      _summaryRow(
        label: 'Consultancy Sectors Total',
        totals: _consultancyTotal(),
        grandTotal: grandTotal,
        bold: true,
        backgroundColor: Colors.teal.shade50,
      ),
    );

    rows.add(_headingRow('$number. All Sectors Summary'));
    rows.add(
      _summaryRow(
        label: 'Current Period Receivables',
        totals: _allCurrentPeriod(),
        grandTotal: grandTotal,
      ),
    );
    rows.add(
      _summaryRow(
        label: 'Advance payment Received',
        totals: _allAdvancePayment(),
        grandTotal: grandTotal,
      ),
    );
    rows.add(
      _summaryRow(
        label: 'Previous Years Receivables',
        totals: _allPreviousYears(),
        grandTotal: grandTotal,
      ),
    );
    rows.add(
      _summaryRow(
        label: 'Grand Total of the 4 Sectors',
        totals: grandTotal,
        grandTotal: grandTotal,
        bold: true,
        backgroundColor: _primary.withValues(alpha: 0.15),
      ),
    );

    return rows;
  }

  bool get _busy => _saving || _submitting;

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Submit Collection',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Collector — based on ${widget.collections.length} collection(s).\n'
                'Review the summary → optional file → Submit to Senior Accountant.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),

          _sectionCard('Report Details', [
            TextFormField(
              controller: _reportNameCtrl,
              decoration: _dec('Report name *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dateField(
                    'Start date',
                    _startDate,
                        (d) => setState(() => _startDate = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateField(
                    'End date',
                    _endDate,
                        (d) => setState(() => _endDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _voucherType,
                    decoration: _dec('Voucher type'),
                    items: ['Milestone', 'Percentage', 'Lump Sum']
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text(v)),
                    )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _voucherType = v ?? _voucherType),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _referenceNumberCtrl,
                    decoration: _dec('Reference number'),
                  ),
                ),
              ],
            ),
          ]),

          _sectionCard('Receivables & Collection Summary', [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                headingRowColor: WidgetStatePropertyAll(
                  _primary.withValues(alpha: 0.15),
                ),
                columns: const [
                  DataColumn(
                    label: SizedBox(width: 220, child: Text('Description')),
                  ),
                  DataColumn(
                    label: Text('Requested\n(from Jul 1)'),
                    numeric: true,
                  ),
                  DataColumn(label: Text('Week plan'), numeric: true),
                  DataColumn(label: Text('Week collected'), numeric: true),
                  DataColumn(label: Text('YTD plan'), numeric: true),
                  DataColumn(label: Text('YTD collected'), numeric: true),
                  DataColumn(label: Text('Remaining'), numeric: true),
                  DataColumn(label: Text('% total recv'), numeric: true),
                  DataColumn(label: Text('Week plan %'), numeric: true),
                ],
                rows: _tableRows(),
              ),
            ),
          ]),

          _sectionCard('Attachment and Notes', [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _fileName ?? 'Upload supporting file (optional)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _dec('Notes to Senior Accountant (optional)'),
            ),
          ]),

          // Collector actions only
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _saveDraft,
                icon: const Icon(Icons.save_outlined),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                ),
                label: Text(_saving ? 'Saving...' : 'Save draft'),
              ),
              ElevatedButton.icon(
                onPressed: _busy ? null : _submitToSeniorAccountant,
                icon: const Icon(Icons.send),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                ),
                label: Text(
                  _submitting
                      ? 'Submitting...'
                      : (widget.isResubmit
                      ? 'Resubmit to Senior Accountant'
                      : 'Submit to Senior Accountant'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'Collector: (1) Review summary → (2) Optional file → '
                '(3) Submit to Senior Accountant. '
                'SA will build File 1 and send to Team Leader.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectorSummary {
  final String name;
  final _Totals currentPeriod = _Totals();
  final _Totals advancePayment = _Totals();
  final _Totals previousYears = _Totals();

  _SectorSummary({required this.name});
}

class _Totals {
  double requested;
  double weekPlan;
  double weekCollected;
  double ytdPlan;
  double ytdCollected;

  _Totals({
    this.requested = 0,
    this.weekPlan = 0,
    this.weekCollected = 0,
    this.ytdPlan = 0,
    this.ytdCollected = 0,
  });

  double get remaining => requested - ytdCollected;

  void add(_Totals other) {
    requested += other.requested;
    weekPlan += other.weekPlan;
    weekCollected += other.weekCollected;
    ytdPlan += other.ytdPlan;
    ytdCollected += other.ytdCollected;
  }

  void addFrom(Map<String, dynamic> values) {
    requested += _asNumber(values['requested']);
    weekPlan += _asNumber(values['week_plan']);
    weekCollected += _asNumber(values['week_collected']);
    ytdPlan += _asNumber(values['ytd_plan']);
    ytdCollected += _asNumber(values['ytd_collected']);
  }

  static double _asNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}