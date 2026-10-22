import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../models/collection_data.dart';
import '../../services/collection_service.dart';
import '../../services/organization_service.dart';
import '../../widgets/role_scaffold.dart';
import '../../controllers/auth_controller.dart';

class CollectDataScreen extends StatefulWidget {
  final CollectionData? existing;

  /// When true, the whole form is shown for viewing only (no editing),
  /// used by reviewers (e.g. Senior Accountant) opening a submitted report.
  final bool readOnly;

  /// Optional AppBar title override while in [readOnly] mode.
  final String? readOnlyTitle;

  /// Called when the reviewer taps "Approve". Only shown in [readOnly] mode
  /// when non-null.
  final VoidCallback? onApprove;

  /// Called when the reviewer taps "Reject". Only shown in [readOnly] mode
  /// when non-null.
  final VoidCallback? onReject;

  const CollectDataScreen({
    super.key,
    this.existing,
    this.readOnly = false,
    this.readOnlyTitle,
    this.onApprove,
    this.onReject,
  });

  @override
  State<CollectDataScreen> createState() => _CollectDataScreenState();
}

class _CollectDataScreenState extends State<CollectDataScreen> {
  static const Color _primary = Color(0xFF0D7377);

  /// Whether form fields should accept input. False while reviewing.
  bool get _editable => !widget.readOnly;

  final _reportNameCtrl = TextEditingController();
  final _referenceNumberCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _voucherType = 'Milestone';

  final _companyNameCtrl = TextEditingController(text: 'EEC');
  final _projectTitleCtrl = TextEditingController();
  final _receivedFromCtrl = TextEditingController();
  final _documentNoCtrl = TextEditingController();
  final _issueNoCtrl = TextEditingController();
  final _paymentDocNoCtrl = TextEditingController();
  DateTime? _projectStart;
  DateTime? _projectEnd;
  String _amendment = 'No';
  String _advancePaymentReceived = 'No';
  final _advanceAmountCtrl = TextEditingController(text: '0.00');
  final _amountInWordsCtrl = TextEditingController();
  final _preparedByCtrl = TextEditingController();
  final _checkedByCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  String _paymentType = 'Milestone';
  final List<_PaymentPhase> _phases = [_PaymentPhase(seq: 1)];

  int? get _collectorBusinessUnitId => Get.find<AuthController>().currentUser?.businessUnitId;
  int? get _collectorSectorId => Get.find<AuthController>().currentUser?.sectorId;
  String? get _collectorSectorName => Get.find<AuthController>().currentUser?.sectorName;

  Project? _selectedProject;

  final Map<String, _CollectionRow> _rows = {
    'current_period': _CollectionRow('1. Current Period Receivables'),
    'advance_current_year': _CollectionRow('2. Advance payment \u2013 Current year'),
    'advance_previous_year': _CollectionRow('3. Advance payment \u2013 Previous year'),
    'previous_years': _CollectionRow('4. Previous Years Receivables'),
  };

  final List<_PlanRow> _planRows = [_PlanRow()];
  final List<_CashRow> _cashRows = [_CashRow()];

  bool _submitting = false;
  bool _generating = false;
  bool _savingDraft = false;
  DateTime? _lastSavedAt;

  @override
  void initState() {
    super.initState();
    for (final row in _rows.values) {
      row.attachListener(() => setState(() {}));
    }

    // Load existing draft / submission if provided
    if (widget.existing != null) {
      _loadExisting(widget.existing!);
    }

    assert(() {
      if (_collectorBusinessUnitId == null || _collectorSectorId == null) {
        debugPrint(
          '[CollectDataScreen] WARNING: _collectorBusinessUnitId / '
              '_collectorSectorId are null for the current user. Check that '
              'login/me.php actually returns business_unit_id and sector_id '
              'on the user record.',
        );
      }
      return true;
    }());
  }

  void _loadExisting(CollectionData c) {
    final raw = c.rows;
    if (raw is! Map) return;

    final map = Map<String, dynamic>.from(raw as Map);

    _reportNameCtrl.text = map['report_name']?.toString() ?? '';
    _referenceNumberCtrl.text = map['reference_number']?.toString() ?? '';
    _voucherType = map['voucher_type']?.toString() ?? 'Milestone';
    _startDate = c.periodFrom;
    _endDate = c.periodTo;

    final clientProject = map['client_project'];
    if (clientProject is Map) {
      final cp = Map<String, dynamic>.from(clientProject);
      _companyNameCtrl.text = cp['company_name']?.toString() ?? 'EEC';
      _projectTitleCtrl.text = cp['project_title']?.toString() ?? '';
      _receivedFromCtrl.text = cp['received_from']?.toString() ?? '';
      _documentNoCtrl.text = cp['document_no']?.toString() ?? '';
      _issueNoCtrl.text = cp['issue_no']?.toString() ?? '';
      _paymentDocNoCtrl.text = cp['payment_doc_no']?.toString() ?? '';
      _amendment = cp['amendment']?.toString() ?? 'No';
      _advancePaymentReceived = cp['advance_payment_received']?.toString() ?? 'No';
      _advanceAmountCtrl.text = (cp['advance_amount'] ?? 0).toString();
      _amountInWordsCtrl.text = cp['amount_in_words']?.toString() ?? '';
      _preparedByCtrl.text = cp['prepared_by']?.toString() ?? '';
      _checkedByCtrl.text = cp['checked_by']?.toString() ?? '';
      _purposeCtrl.text = cp['purpose']?.toString() ?? '';
      _reasonCtrl.text = cp['reason']?.toString() ?? '';

      if (cp['project_start'] != null) {
        _projectStart = DateTime.tryParse(cp['project_start'].toString());
      }
      if (cp['project_end'] != null) {
        _projectEnd = DateTime.tryParse(cp['project_end'].toString());
      }
    }

    final paymentPhases = map['payment_phases'];
    if (paymentPhases is Map) {
      final pp = Map<String, dynamic>.from(paymentPhases);
      _paymentType = pp['payment_type']?.toString() ?? 'Milestone';
      _recoveryPercentCtrl.text = (pp['advance_recovery_percent'] ?? 20).toString();

      final phases = pp['phases'];
      if (phases is List && phases.isNotEmpty) {
        for (final p in _phases) {
          p.dispose();
        }
        _phases.clear();

        for (final item in phases) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final phase = _PaymentPhase(seq: (m['seq'] as num?)?.toInt() ?? (_phases.length + 1));
            phase.milestoneCtrl.text = m['milestone']?.toString() ?? '';
            phase.budgetCtrl.text = (m['budget_amount'] ?? 0).toString();
            phase.collectedCtrl.text = (m['collected'] ?? 0).toString();
            _phases.add(phase);
          }
        }
      }
    }

    final rows = map['rows'];
    if (rows is Map) {
      for (final entry in rows.entries) {
        final key = entry.key.toString();
        if (_rows.containsKey(key) && entry.value is Map) {
          final r = Map<String, dynamic>.from(entry.value);
          final row = _rows[key]!;
          row.requestedCtrl.text = (r['requested'] ?? 0).toString();
          row.weekPlanCtrl.text = (r['week_plan'] ?? 0).toString();
          row.weekCollectedCtrl.text = (r['week_collected'] ?? 0).toString();
          row.ytdPlanCtrl.text = (r['ytd_plan'] ?? 0).toString();
          row.ytdCollectedCtrl.text = (r['ytd_collected'] ?? 0).toString();
        }
      }
    }

    // Next week plan
    final nextWeekPlan = map['next_week_plan'];
    if (nextWeekPlan is List && nextWeekPlan.isNotEmpty) {
      for (final p in _planRows) {
        p.dispose();
      }
      _planRows.clear();

      for (final item in nextWeekPlan) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final plan = _PlanRow();
          plan.period = m['period']?.toString() ?? 'current_year';
          plan.projectCtrl.text = m['plan_project']?.toString() ?? '';
          plan.executedCtrl.text = m['plan_executed']?.toString() ?? '';
          plan.amountCtrl.text = (m['plan_amount'] ?? 0).toString();
          plan.ipcCtrl.text = m['plan_ipc']?.toString() ?? '';
          _planRows.add(plan);
        }
      }
    }

    final cashCollections = map['cash_collections'];
    if (cashCollections is List && cashCollections.isNotEmpty) {
      for (final c in _cashRows) {
        c.dispose();
      }
      _cashRows.clear();

      for (final item in cashCollections) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final cash = _CashRow();
          cash.clientNameCtrl.text = m['client_name']?.toString() ?? '';
          cash.cashValueCtrl.text = (m['cash_value'] ?? 0).toString();
          cash.receivableValueCtrl.text = (m['receivable_value'] ?? 0).toString();
          _cashRows.add(cash);
        }
      }
    }

    _selectedProject = Project(
      id: c.projectId ?? 0,
      name: c.projectName!,
      sectorId: c.sectorId ?? _collectorSectorId ?? 0,
    );

    setState(() {});
  }

  @override
  void dispose() {
    _reportNameCtrl.dispose();
    _referenceNumberCtrl.dispose();
    _companyNameCtrl.dispose();
    _projectTitleCtrl.dispose();
    _receivedFromCtrl.dispose();
    _documentNoCtrl.dispose();
    _issueNoCtrl.dispose();
    _paymentDocNoCtrl.dispose();
    _advanceAmountCtrl.dispose();
    _recoveryPercentCtrl.dispose();
    _amountInWordsCtrl.dispose();
    _preparedByCtrl.dispose();
    _checkedByCtrl.dispose();
    _purposeCtrl.dispose();
    _reasonCtrl.dispose();
    for (final p in _phases) {
      p.dispose();
    }
    for (final r in _rows.values) {
      r.dispose();
    }
    for (final p in _planRows) {
      p.dispose();
    }
    for (final c in _cashRows) {
      c.dispose();
    }
    super.dispose();
  }

  List<Project> _pickerProjects = [];
  bool _pickerLoading = false;
  String _pickerSearch = '';
  String? _pickerError;

  Future<void> _fetchAllPickerProjects() async {
    if (_pickerLoading) return;
    _pickerLoading = true;
    _pickerError = null;
    final List<Project> all = [];
    try {
      if (_collectorBusinessUnitId == null || _collectorSectorId == null) {
        _pickerProjects = [];
        _pickerError =
        'Your Business Unit / Sector could not be determined from your '
            'account. Please contact your administrator.';
        return;
      }

      int page = 1;
      const perPage = 100;
      while (true) {
        final result = await OrganizationService.getMyProjects(
          page: page,
          perPage: perPage,
          search: _pickerSearch,
          businessUnitId: _collectorBusinessUnitId,
          sectorId: _collectorSectorId,
        );

        if (result['success'] == false) {
          _pickerError = result['message']?.toString() ?? 'Could not load projects';
          break;
        }

        final rawData = result['data'];
        if (rawData is! List) {
          throw FormatException(
            'Expected "data" to be a List but got ${rawData.runtimeType}',
          );
        }
        final List<Project> items = rawData.cast<Project>();
        all.addAll(items);

        final bool hasMore = result['has_more'] as bool? ?? false;
        if (!hasMore || items.isEmpty) break;
        page += 1;
      }
      _pickerProjects = all;
    } catch (error, stackTrace) {
      debugPrint('[CollectDataScreen] getMyProjects failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _pickerProjects = [];
      _pickerError = 'Could not load projects: $error';
    } finally {
      _pickerLoading = false;
    }
  }

  String? get _selectedSectorName => _collectorSectorName;

  bool get _selectionComplete => _selectedProject != null;

  Widget _phaseBreakdown(int index) {
    final p = _phases[index];
    final deduction = _advanceDeductionForPhase(index);
    final net = _netAfterAdvanceForPhase(index);
    final vat = _vatForPhase(index);
    final total = _totalWithVatForPhase(index);
    final fmt = NumberFormat('#,##0.00');
    Widget line(String label, double value, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13)),
            Text(fmt.format(value), style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, left: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          line('Net Sum Due to the Contractor ETB', p.netSumDue),
          line('Less - Advance Repay (WITHOUT VAT, ${_recoveryPercentCtrl.text}% of budget)', deduction),
          const Divider(height: 8),
          line('Net after advance', net, bold: true),
          line('NET 15% VAT in ETB', vat),
          const Divider(height: 8),
          line('Total with 15% VAT, ETB', total, bold: true),
        ],
      ),
    );
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) onPicked(picked);
  }

  double get _totalBudget =>
      _phases.fold(0.0, (sum, p) => sum + (double.tryParse(p.budgetCtrl.text) ?? 0));

  final _recoveryPercentCtrl = TextEditingController(text: '20');

  double _advanceDeductionForPhase(int index) {
    final pct = (double.tryParse(_recoveryPercentCtrl.text) ?? 0) / 100;
    double remaining = double.tryParse(_advanceAmountCtrl.text) ?? 0;
    double result = 0;
    for (int i = 0; i < _phases.length; i++) {
      final proposed = _phases[i].netSumDue * pct;
      final actual = proposed > remaining ? remaining : proposed;
      if (i == index) {
        result = actual;
        break;
      }
      remaining -= actual;
      if (remaining < 0) remaining = 0;
    }
    return result;
  }

  double _netAfterAdvanceForPhase(int index) =>
      _phases[index].netSumDue - _advanceDeductionForPhase(index);
  double _vatForPhase(int index) => _netAfterAdvanceForPhase(index) * 0.15;
  double _totalWithVatForPhase(int index) =>
      _netAfterAdvanceForPhase(index) + _vatForPhase(index);

  double get _totalAdvanceDeducted {
    double sum = 0;
    for (int i = 0; i < _phases.length; i++) {
      sum += _advanceDeductionForPhase(i);
    }
    return sum;
  }

  Map<String, double> _totalsAcrossRows() {
    final totals = {
      'requested': 0.0,
      'week_plan': 0.0,
      'week_collected': 0.0,
      'ytd_plan': 0.0,
      'ytd_collected': 0.0,
      'remaining': 0.0,
    };
    for (final row in _rows.values) {
      final requested = row.requested;
      final ytdCollected = row.ytdCollected;
      totals['requested'] = totals['requested']! + requested;
      totals['week_plan'] = totals['week_plan']! + row.weekPlan;
      totals['week_collected'] = totals['week_collected']! + row.weekCollected;
      totals['ytd_plan'] = totals['ytd_plan']! + row.ytdPlan;
      totals['ytd_collected'] = totals['ytd_collected']! + ytdCollected;
      totals['remaining'] = totals['remaining']! + (requested - ytdCollected);
    }
    return totals;
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'report_name': _reportNameCtrl.text.trim(),
      'sector_name': _selectedSectorName,
      'period_from': _startDate?.toIso8601String().split('T').first,
      'period_to': _endDate?.toIso8601String().split('T').first,
      'voucher_type': _voucherType,
      'reference_number': _referenceNumberCtrl.text.trim(),
      'client_project': {
        'company_name': _companyNameCtrl.text.trim(),
        'project_title': _projectTitleCtrl.text.trim(),
        'received_from': _receivedFromCtrl.text.trim(),
        'document_no': _documentNoCtrl.text.trim(),
        'issue_no': _issueNoCtrl.text.trim(),
        'payment_doc_no': _paymentDocNoCtrl.text.trim(),
        'project_start': _projectStart?.toIso8601String().split('T').first,
        'project_end': _projectEnd?.toIso8601String().split('T').first,
        'amendment': _amendment,
        'advance_payment_received': _advancePaymentReceived,
        'advance_amount': double.tryParse(_advanceAmountCtrl.text) ?? 0,
        'amount_in_words': _amountInWordsCtrl.text.trim(),
        'prepared_by': _preparedByCtrl.text.trim(),
        'checked_by': _checkedByCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'reason': _reasonCtrl.text.trim(),
      },
      'payment_phases': {
        'payment_type': _paymentType,
        'advance_recovery_percent': double.tryParse(_recoveryPercentCtrl.text) ?? 0,
        'phases': List.generate(_phases.length, (i) {
          final p = _phases[i];
          return {
            'seq': p.seq,
            'milestone': p.milestoneCtrl.text.trim(),
            'budget_amount': double.tryParse(p.budgetCtrl.text) ?? 0,
            'advance_deduction': _advanceDeductionForPhase(i),
            'collected': double.tryParse(p.collectedCtrl.text) ?? 0,
            'net_after_advance': _netAfterAdvanceForPhase(i),
            'vat_amount': _vatForPhase(i),
            'total_with_vat': _totalWithVatForPhase(i),
          };
        }),
        'total_budget': _totalBudget,
      },
      'rows': _rows.map((key, row) => MapEntry(key, {
        'requested': row.requested,
        'week_plan': row.weekPlan,
        'week_collected': row.weekCollected,
        'ytd_plan': row.ytdPlan,
        'ytd_collected': row.ytdCollected,
      })),
      'next_week_plan': _planRows
          .map((p) => {
        'period': p.period,
        'plan_project': p.projectCtrl.text.trim(),
        'plan_executed': p.executedCtrl.text.trim(),
        'plan_amount': double.tryParse(p.amountCtrl.text) ?? 0,
        'plan_ipc': p.ipcCtrl.text.trim(),
      })
          .toList(),
      'cash_collections': _cashRows
          .map((c) => {
        'client_name': c.clientNameCtrl.text.trim(),
        'cash_value': double.tryParse(c.cashValueCtrl.text) ?? 0,
        'receivable_value': double.tryParse(c.receivableValueCtrl.text) ?? 0,
      })
          .toList(),
    };
  }

  Future<void> _saveDraft() async {
    if (!_selectionComplete) {
      Get.snackbar(
        'Required',
        'Please select a project first',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _savingDraft = true);

    try {
      final payload = _buildPayload();

      final result = await CollectionService.saveDraft(
        id: widget.existing?.id,
        projectId: _selectedProject!.id,
        sectorId: _collectorSectorId,
        businessUnitId: _collectorBusinessUnitId,
        periodFrom: _startDate,
        periodTo: _endDate,
        tableData: payload,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _lastSavedAt = DateTime.now();
        });
        Get.snackbar(
          'Draft Saved',
          'Your draft has been saved successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Failed to save draft',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to save draft: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingDraft = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_selectionComplete) {
      Get.snackbar(
        'Required',
        'Please select a Business Unit, Sector and Project first',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_reportNameCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Required',
        'Report name is required',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final payload = _buildPayload();

      final result = await CollectionService.submit(
        id: widget.existing?.id,
        projectId: _selectedProject!.id,
        sectorId: _collectorSectorId,
        businessUnitId: _collectorBusinessUnitId,
        periodFrom: _startDate,
        periodTo: _endDate,
        tableData: payload,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Get.snackbar(
          'Success',
          'Saved and submitted to Senior Accountant',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );

        Get.back(result: true);
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Submit failed',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black,
        );
      }
    } catch (error) {
      if (!mounted) return;

      Get.snackbar(
        'Error',
        'Could not submit the report: $error',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  /// Generates the collector's own report as an .xlsx file entirely in the
  /// browser (same approach already used on the Senior Accountant screen) —
  /// no backend endpoint required.
  Future<void> _generateTemplate() async {
    if (!_selectionComplete) {
      Get.snackbar(
        'Required',
        'Please select a Business Unit, Sector and Project first',
      );
      return;
    }

    if (_reportNameCtrl.text.trim().isEmpty) {
      Get.snackbar('Required', 'Report name is required');
      return;
    }

    setState(() => _generating = true);

    try {
      final payload = _buildPayload();

      final workbook = xls.Excel.createExcel();
      const sheetName = 'Collection Report';
      workbook.rename(workbook.getDefaultSheet()!, sheetName);
      final sheet = workbook[sheetName];

      final title = _reportNameCtrl.text.trim().isEmpty
          ? 'Receivables and Collection Report'
          : _reportNameCtrl.text.trim();
      sheet.appendRow([xls.TextCellValue(title)]);

      final periodStr =
          '${_startDate != null ? DateFormat('MMM d, yyyy').format(_startDate!) : ''}'
          ' - '
          '${_endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : ''}';
      sheet.appendRow([xls.TextCellValue('Period: $periodStr')]);
      sheet.appendRow([xls.TextCellValue('')]);

      // ---- Client & project information ----
      sheet.appendRow([xls.TextCellValue('Client & Project Information')]);
      final clientProject =
      Map<String, dynamic>.from(payload['client_project'] as Map? ?? {});
      void kv(String label, dynamic value) {
        sheet.appendRow(
            [xls.TextCellValue(label), xls.TextCellValue(value?.toString() ?? '')]);
      }

      kv('Company name', clientProject['company_name']);
      kv('Project title', clientProject['project_title']);
      kv('Received from / client', clientProject['received_from']);
      kv('Document no.', clientProject['document_no']);
      kv('Issue no.', clientProject['issue_no']);
      kv('Payment doc. no.', clientProject['payment_doc_no']);
      kv('Advance payment received', clientProject['advance_payment_received']);
      kv('Advance amount', clientProject['advance_amount']);
      sheet.appendRow([xls.TextCellValue('')]);

      // ---- Payment phases ----
      final phases =
          (payload['payment_phases'] as Map?)?['phases'] as List? ?? [];
      if (phases.isNotEmpty) {
        sheet.appendRow([xls.TextCellValue('Payment Phases')]);
        sheet.appendRow([
          xls.TextCellValue('Seq'),
          xls.TextCellValue('Milestone'),
          xls.TextCellValue('Budget amount'),
          xls.TextCellValue('Advance deduction'),
          xls.TextCellValue('Collected'),
          xls.TextCellValue('Net after advance'),
          xls.TextCellValue('VAT'),
          xls.TextCellValue('Total with VAT'),
        ]);
        for (final p in phases) {
          final m = Map<String, dynamic>.from(p as Map);
          sheet.appendRow([
            xls.IntCellValue((m['seq'] as num?)?.toInt() ?? 0),
            xls.TextCellValue(m['milestone']?.toString() ?? ''),
            xls.DoubleCellValue((m['budget_amount'] as num?)?.toDouble() ?? 0),
            xls.DoubleCellValue((m['advance_deduction'] as num?)?.toDouble() ?? 0),
            xls.DoubleCellValue((m['collected'] as num?)?.toDouble() ?? 0),
            xls.DoubleCellValue((m['net_after_advance'] as num?)?.toDouble() ?? 0),
            xls.DoubleCellValue((m['vat_amount'] as num?)?.toDouble() ?? 0),
            xls.DoubleCellValue((m['total_with_vat'] as num?)?.toDouble() ?? 0),
          ]);
        }
        sheet.appendRow([xls.TextCellValue('')]);
      }

      // ---- Receivables & collection ----
      sheet.appendRow([xls.TextCellValue('Receivables & Collection')]);
      sheet.appendRow([
        xls.TextCellValue('Description'),
        xls.TextCellValue('Requested'),
        xls.TextCellValue('Week plan'),
        xls.TextCellValue('Week collected'),
        xls.TextCellValue('YTD plan'),
        xls.TextCellValue('YTD collected'),
      ]);
      const rowLabels = {
        'current_period': '1. Current Period Receivables',
        'advance_current_year': '2. Advance payment \u2013 Current year',
        'advance_previous_year': '3. Advance payment \u2013 Previous year',
        'previous_years': '4. Previous Years Receivables',
      };
      final rowsMap = Map<String, dynamic>.from(payload['rows'] as Map? ?? {});
      rowLabels.forEach((key, label) {
        final r = Map<String, dynamic>.from(rowsMap[key] as Map? ?? {});
        sheet.appendRow([
          xls.TextCellValue(label),
          xls.DoubleCellValue((r['requested'] as num?)?.toDouble() ?? 0),
          xls.DoubleCellValue((r['week_plan'] as num?)?.toDouble() ?? 0),
          xls.DoubleCellValue((r['week_collected'] as num?)?.toDouble() ?? 0),
          xls.DoubleCellValue((r['ytd_plan'] as num?)?.toDouble() ?? 0),
          xls.DoubleCellValue((r['ytd_collected'] as num?)?.toDouble() ?? 0),
        ]);
      });
      sheet.appendRow([xls.TextCellValue('')]);

      // ---- Next week plan ----
      final nextWeekPlan = payload['next_week_plan'] as List? ?? [];
      if (nextWeekPlan.isNotEmpty) {
        sheet.appendRow([xls.TextCellValue('Next Week Plan')]);
        sheet.appendRow([
          xls.TextCellValue('Period'),
          xls.TextCellValue('Plan project'),
          xls.TextCellValue('Plan executed'),
          xls.TextCellValue('Plan amount'),
          xls.TextCellValue('Plan IPC'),
        ]);
        for (final p in nextWeekPlan) {
          final m = Map<String, dynamic>.from(p as Map);
          sheet.appendRow([
            xls.TextCellValue(m['period']?.toString() ?? ''),
            xls.TextCellValue(m['plan_project']?.toString() ?? ''),
            xls.TextCellValue(m['plan_executed']?.toString() ?? ''),
            xls.DoubleCellValue((m['plan_amount'] as num?)?.toDouble() ?? 0),
            xls.TextCellValue(m['plan_ipc']?.toString() ?? ''),
          ]);
        }
        sheet.appendRow([xls.TextCellValue('')]);
      }

      // ---- Cash collections ----
      final cashCollections = payload['cash_collections'] as List? ?? [];
      if (cashCollections.isNotEmpty) {
        sheet.appendRow([xls.TextCellValue('Cash Collections')]);
        sheet.appendRow([
          xls.TextCellValue('Client name'),
          xls.TextCellValue('Cash value'),
          xls.TextCellValue('Receivable value'),
        ]);
        for (final c in cashCollections) {
          final m = Map<String, dynamic>.from(c as Map);
          sheet.appendRow([
            xls.TextCellValue(m['client_name']?.toString() ?? ''),
            xls.DoubleCellValue((m['cash_value'] as num?)?.toDouble() ?? 0),
            xls.DoubleCellValue((m['receivable_value'] as num?)?.toDouble() ?? 0),
          ]);
        }
      }

      final bytes = workbook.save();
      if (bytes == null) {
        if (!mounted) return;
        Get.snackbar(
          'Error',
          'Could not generate the file.',
          backgroundColor: Colors.red.shade100,
        );
        return;
      }

      final fileName =
          'Collection_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      Get.snackbar(
        'Generated',
        'Report file downloaded.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _primary,
        colorText: Colors.white,
      );
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Could not generate the file: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    border: const OutlineInputBorder(),
  );

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return OutlinedButton.icon(
      onPressed: widget.readOnly ? null : () => _pickDate(value, onPicked),
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(value == null ? label : DateFormat('MM/dd/yyyy').format(value)),
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
    );
  }

  Widget _projectSelectionCard() {
    final missingScope = _collectorBusinessUnitId == null || _collectorSectorId == null;

    return _sectionCard('1. Select Project'.tr, [
      if (missingScope && !widget.readOnly)
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Your Business Unit / Sector could not be determined from '
                      'your account, so no projects can be loaded yet. Please '
                      'contact your administrator.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      InkWell(
        onTap: (missingScope || widget.readOnly) ? null : _openProjectPicker,
        child: InputDecorator(
          decoration: _dec('Project *'),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedProject?.name ?? '-- Tap to select a project --'.tr,
                  style: TextStyle(
                    color: _selectedProject == null ? Colors.black45 : Colors.black87,
                  ),
                ),
              ),
              if (!widget.readOnly)
                const Icon(Icons.search, size: 18, color: Colors.black45),
            ],
          ),
        ),
      ),
    ]);
  }

  Future<void> _openProjectPicker() async {
    await _fetchAllPickerProjects();
    if (!mounted) return;

    final searchCtrl = TextEditingController(text: _pickerSearch);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> runSearch(String q) async {
              _pickerSearch = q.trim();
              await _fetchAllPickerProjects();
              setSheetState(() {});
            }

            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: _dec('Search projects', hint: 'Type to filter'),
                      onSubmitted: runSearch,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (_pickerError != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 32),
                                  const SizedBox(height: 12),
                                  Text(
                                    _pickerError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () => runSearch(_pickerSearch),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_pickerProjects.isEmpty && !_pickerLoading)
                          const Center(child: Text('No projects found'))
                        else
                          ListView.builder(
                            itemCount: _pickerProjects.length,
                            itemBuilder: (context, i) {
                              final project = _pickerProjects[i];
                              return ListTile(
                                title: Text(project.name),
                                onTap: () {
                                  setState(() => _selectedProject = project);
                                  Navigator.of(sheetContext).pop();
                                },
                              );
                            },
                          ),
                        if (_pickerLoading)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _selectionPendingNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Select a project above to continue.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    final String title = widget.readOnly
        ? (widget.readOnlyTitle ?? 'Review Submission')
        : (isEditing ? 'Edit Draft' : 'Collect Data');

    final String subtitle = widget.readOnly
        ? 'Viewing submitted report. Read-only.'
        : (isEditing
        ? 'Editing existing draft. Make changes and Save or Submit.'
        : 'Select a project \u2192 fill its form below.');

    return RoleScaffold(
      title: title.tr,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          _projectSelectionCard(),

          if (!_selectionComplete)
            _selectionPendingNotice()
          else ...[
            _sectionCard('2. Report details'.tr, [
              TextFormField(
                controller: _reportNameCtrl,
                enabled: _editable,
                decoration: _dec('Report name *', hint: 'e.g. Weekly Collection Report \u2013 Construction Sector'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateField('Start date *', _startDate, (d) => setState(() => _startDate = d))),
                const SizedBox(width: 12),
                Expanded(child: _dateField('End date *', _endDate, (d) => setState(() => _endDate = d))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _voucherType,
                    decoration: _dec('Voucher type'),
                    hint: const Text('-- select --'),
                    items: [
                      'IPC \u2013 Interim Payment Certificate',
                      'Advance Payment',
                      'Retention',
                      'Milestone',
                      'Final Payment',
                      'Other',
                    ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: _editable ? (v) => setState(() => _voucherType = v ?? _voucherType) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _referenceNumberCtrl,
                    enabled: _editable,
                    decoration: _dec('Reference number', hint: 'e.g. REF/2026/001 or IPC #15'),
                  ),
                ),
              ]),
            ]),

            _sectionCard('Client & project information'.tr, [
              Row(children: [
                Expanded(child: TextFormField(controller: _companyNameCtrl, enabled: _editable, decoration: _dec('Company name'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _projectTitleCtrl, enabled: _editable, decoration: _dec('Project title'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _receivedFromCtrl, enabled: _editable, decoration: _dec('Received from / client'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _documentNoCtrl, enabled: _editable, decoration: _dec('Document no.', hint: 'e.g. OF/EEC/0012'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _issueNoCtrl, enabled: _editable, decoration: _dec('Issue no.'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _paymentDocNoCtrl, enabled: _editable, decoration: _dec('Payment doc. no.'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateField('Project start', _projectStart, (d) => setState(() => _projectStart = d))),
                const SizedBox(width: 12),
                Expanded(child: _dateField('Project end', _projectEnd, (d) => setState(() => _projectEnd = d))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _amendment,
                    decoration: _dec('Amendment'),
                    items: ['No', 'Yes'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: _editable ? (v) => setState(() => _amendment = v ?? _amendment) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _advancePaymentReceived,
                    decoration: _dec('Advance payment received'),
                    items: ['No', 'Yes'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: _editable ? (v) => setState(() => _advancePaymentReceived = v ?? _advancePaymentReceived) : null,
                  ),
                ),
              ]),
              if (_advancePaymentReceived == 'Yes') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _advanceAmountCtrl,
                  enabled: _editable,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Advance payment amount', hint: 'Total advance received before project start'),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _amountInWordsCtrl, enabled: _editable, decoration: _dec('Amount in words'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _preparedByCtrl, enabled: _editable, decoration: _dec('Prepared by'))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _checkedByCtrl, enabled: _editable, decoration: _dec('Checked by')),
              const SizedBox(height: 12),
              TextFormField(controller: _purposeCtrl, enabled: _editable, maxLines: 2, decoration: _dec('Purpose / \u12E8\u1275\u1245\u134D\u1208\u1230\u1275 \u121D\u12AD\u1295\u12EB\u1275')),
              const SizedBox(height: 12),
              TextFormField(controller: _reasonCtrl, enabled: _editable, maxLines: 2, decoration: _dec('Reason')),
            ]),

            _sectionCard('Payment phases (per agreement)'.tr, [
              DropdownButtonFormField<String>(
                value: _paymentType,
                decoration: _dec('Payment type'),
                items: ['Milestone', 'Percentage', 'Lump Sum']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _editable ? (v) => setState(() => _paymentType = v ?? _paymentType) : null,
              ),
              if (_advancePaymentReceived == 'Yes') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recoveryPercentCtrl,
                  enabled: _editable,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Advance recovery % per IPC', hint: 'e.g. 20 = 20% of each phase recovers the advance'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 12),
              ...List.generate(_phases.length, (i) {
                final p = _phases[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        SizedBox(width: 48, child: Text('${p.seq}', textAlign: TextAlign.center)),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(controller: p.milestoneCtrl, enabled: _editable, decoration: _dec('Milestone')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: p.budgetCtrl,
                            enabled: _editable,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _dec('Budget amount'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: p.collectedCtrl,
                            enabled: _editable,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _dec('Collected'),
                          ),
                        ),
                        if (!widget.readOnly)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: _phases.length > 1
                                ? () => setState(() {
                              p.dispose();
                              _phases.removeAt(i);
                            })
                                : null,
                          ),
                      ]),
                      if (_advancePaymentReceived == 'Yes') _phaseBreakdown(i),
                    ],
                  ),
                );
              }),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total budget: ${NumberFormat('#,##0.00').format(_totalBudget)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (!widget.readOnly)
                    TextButton.icon(
                      onPressed: () => setState(() => _phases.add(_PaymentPhase(seq: _phases.length + 1))),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add phase'),
                    ),
                ],
              ),
              if (_advancePaymentReceived == 'Yes') ...[
                const SizedBox(height: 8),
                Text(
                  'Advance received: ${NumberFormat('#,##0.00').format(double.tryParse(_advanceAmountCtrl.text) ?? 0)}   '
                      '\u2022   Total deducted so far: ${NumberFormat('#,##0.00').format(_totalAdvanceDeducted)}   '
                      '\u2022   Advance remaining: ${NumberFormat('#,##0.00').format((double.tryParse(_advanceAmountCtrl.text) ?? 0) - _totalAdvanceDeducted)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ]),

            _sectionCard('Receivables & collection'.tr, [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Requested (from Jul 1)')),
                    DataColumn(label: Text('Week plan')),
                    DataColumn(label: Text('Week collected')),
                    DataColumn(label: Text('YTD plan')),
                    DataColumn(label: Text('YTD collected')),
                    DataColumn(label: Text('Remaining')),
                  ],
                  rows: [
                    ..._rows.values.map((row) => DataRow(cells: [
                      DataCell(SizedBox(width: 200, child: Text(row.label))),
                      DataCell(SizedBox(width: 110, child: TextField(controller: row.requestedCtrl, enabled: _editable, decoration: _dec(''), keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
                      DataCell(SizedBox(width: 110, child: TextField(controller: row.weekPlanCtrl, enabled: _editable, decoration: _dec(''), keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
                      DataCell(SizedBox(width: 110, child: TextField(controller: row.weekCollectedCtrl, enabled: _editable, decoration: _dec(''), keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
                      DataCell(SizedBox(width: 110, child: TextField(controller: row.ytdPlanCtrl, enabled: _editable, decoration: _dec(''), keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
                      DataCell(SizedBox(width: 110, child: TextField(controller: row.ytdCollectedCtrl, enabled: _editable, decoration: _dec(''), keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
                      DataCell(SizedBox(width: 100, child: Text(NumberFormat('#,##0.00').format(row.requested - row.ytdCollected)))),
                    ])),
                    DataRow(
                      color: MaterialStateProperty.all(Colors.grey.shade100),
                      cells: [
                        const DataCell(Text('Total under collection follow-up', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(NumberFormat('#,##0.00').format(_totalsAcrossRows()['requested']), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(NumberFormat('#,##0.00').format(_totalsAcrossRows()['week_plan']), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(NumberFormat('#,##0.00').format(_totalsAcrossRows()['week_collected']), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(NumberFormat('#,##0.00').format(_totalsAcrossRows()['ytd_plan']), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(NumberFormat('#,##0.00').format(_totalsAcrossRows()['ytd_collected']), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(NumberFormat('#,##0.00').format(_totalsAcrossRows()['remaining']), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
            ]),

            _sectionCard('Next week plan'.tr, [
              ...List.generate(_planRows.length, (i) {
                final p = _planRows[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(width: 40, child: Text('${i + 1}')),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        value: p.period,
                        isExpanded: true,
                        isDense: true,
                        decoration: _dec('Period'),
                        items: ['current_year', 'previous_year']
                            .map((v) => DropdownMenuItem(value: v, child: Text(v == 'current_year' ? 'Current year' : 'Previous year')))
                            .toList(),
                        onChanged: _editable ? (v) => setState(() => p.period = v ?? p.period) : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: p.projectCtrl, enabled: _editable, decoration: _dec('Plan project'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: p.executedCtrl, enabled: _editable, decoration: _dec('Plan executed'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: p.amountCtrl, enabled: _editable, decoration: _dec('Plan amount'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: p.ipcCtrl, enabled: _editable, decoration: _dec('Plan IPC'))),
                    if (!widget.readOnly)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _planRows.length > 1
                            ? () => setState(() {
                          p.dispose();
                          _planRows.removeAt(i);
                        })
                            : null,
                      ),
                  ]),
                );
              }),
              if (!widget.readOnly)
                TextButton.icon(
                  onPressed: () => setState(() => _planRows.add(_PlanRow())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add plan row'),
                ),
            ]),

            _sectionCard('Cash collections'.tr, [
              ...List.generate(_cashRows.length, (i) {
                final c = _cashRows[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(width: 40, child: Text('${i + 1}')),
                    Expanded(flex: 2, child: TextFormField(controller: c.clientNameCtrl, enabled: _editable, decoration: _dec('Client name'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: c.cashValueCtrl, enabled: _editable, decoration: _dec('Cash value'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: c.receivableValueCtrl, enabled: _editable, decoration: _dec('Receivable value'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    if (!widget.readOnly)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _cashRows.length > 1
                            ? () => setState(() {
                          c.dispose();
                          _cashRows.removeAt(i);
                        })
                            : null,
                      ),
                  ]),
                );
              }),
              if (!widget.readOnly)
                TextButton.icon(
                  onPressed: () => setState(() => _cashRows.add(_CashRow())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add cash row'),
                ),
            ]),

            const SizedBox(height: 8),
            if (widget.readOnly) ...[
              // Review mode: no Save/Submit — just optional Approve/Reject
              // actions supplied by the caller (e.g. Senior Accountant flow),
              // plus the ability to export what's being reviewed.
              Row(
                children: [
                  if (widget.onReject != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  if (widget.onReject != null && widget.onApprove != null)
                    const SizedBox(width: 10),
                  if (widget.onApprove != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Approve & Send to Team Leader',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        isEditing ? 'Update & Submit' : 'New submission to Senior Accountant',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _savingDraft ? null : _saveDraft,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _savingDraft
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(
                        isEditing ? 'Update Draft' : 'Save draft',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _generating ? null : _generateTemplate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _generating
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        'Generate / Print report',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            if (_lastSavedAt != null && !widget.readOnly) ...[
              const SizedBox(height: 8),
              Text(
                'Saved at ${DateFormat('HH:mm').format(_lastSavedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============ Helper classes (unchanged) ============

class _CollectionRow {
  final String label;
  final requestedCtrl = TextEditingController(text: '0.00');
  final weekPlanCtrl = TextEditingController(text: '0.00');
  final weekCollectedCtrl = TextEditingController(text: '0.00');
  final ytdPlanCtrl = TextEditingController(text: '0.00');
  final ytdCollectedCtrl = TextEditingController(text: '0.00');

  _CollectionRow(this.label);

  double get requested => double.tryParse(requestedCtrl.text) ?? 0;
  double get weekPlan => double.tryParse(weekPlanCtrl.text) ?? 0;
  double get weekCollected => double.tryParse(weekCollectedCtrl.text) ?? 0;
  double get ytdPlan => double.tryParse(ytdPlanCtrl.text) ?? 0;
  double get ytdCollected => double.tryParse(ytdCollectedCtrl.text) ?? 0;

  void attachListener(VoidCallback cb) {
    requestedCtrl.addListener(cb);
    weekPlanCtrl.addListener(cb);
    weekCollectedCtrl.addListener(cb);
    ytdPlanCtrl.addListener(cb);
    ytdCollectedCtrl.addListener(cb);
  }

  void dispose() {
    requestedCtrl.dispose();
    weekPlanCtrl.dispose();
    weekCollectedCtrl.dispose();
    ytdPlanCtrl.dispose();
    ytdCollectedCtrl.dispose();
  }
}

class _PaymentPhase {
  int seq;
  final milestoneCtrl = TextEditingController();
  final budgetCtrl = TextEditingController(text: '0.00');
  final collectedCtrl = TextEditingController(text: '0.00');

  _PaymentPhase({required this.seq});

  double get netSumDue => double.tryParse(budgetCtrl.text) ?? 0;

  void dispose() {
    milestoneCtrl.dispose();
    budgetCtrl.dispose();
    collectedCtrl.dispose();
  }
}

class _PlanRow {
  String period = 'current_year';
  final projectCtrl = TextEditingController();
  final executedCtrl = TextEditingController();
  final amountCtrl = TextEditingController(text: '0.00');
  final ipcCtrl = TextEditingController();

  void dispose() {
    projectCtrl.dispose();
    executedCtrl.dispose();
    amountCtrl.dispose();
    ipcCtrl.dispose();
  }
}

class _CashRow {
  final clientNameCtrl = TextEditingController();
  final cashValueCtrl = TextEditingController(text: '0.00');
  final receivableValueCtrl = TextEditingController(text: '0.00');

  void dispose() {
    clientNameCtrl.dispose();
    cashValueCtrl.dispose();
    receivableValueCtrl.dispose();
  }
}