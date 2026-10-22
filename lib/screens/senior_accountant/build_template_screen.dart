import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/collection_data.dart';
import '../../services/workflow_report_service.dart';
import '../../widgets/role_scaffold.dart';

class BuildTemplateScreen extends StatefulWidget {
  final List<CollectionData> collections;

  const BuildTemplateScreen({
    super.key,
    required this.collections,
  });

  @override
  State<BuildTemplateScreen> createState() => _BuildTemplateScreenState();
}

class _BuildTemplateScreenState extends State<BuildTemplateScreen> {
  static const Color _primary = Color(0xFF0D7377);

  // Period
  String _periodSection = 'Current Period Receivables';

  // Project rows
  final List<_ProjectRow> _rows = [];

  // Controllers
  final _reportNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Loading states
  bool _savingDraft = false;
  bool _approving = false;
  bool _rejecting = false;
  bool _generating = false;
  bool _resubmitting = false;

  final _numberFormat = NumberFormat('#,##0.00');

  // Temporary project list (replace with real API later)
  final List<Map<String, String>> _availableProjects = [
    {'id': '1', 'name': 'Bishoftu–Chefe Donsa', 'client': 'ERA'},
    {'id': '2', 'name': 'Construction portfolio', 'client': 'ERA / AACRA'},
    {'id': '3', 'name': 'Modjo – Hawassa Highway', 'client': 'ERA'},
    {'id': '4', 'name': 'Addis Ababa Ring Road', 'client': 'AACRA'},
  ];

  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _loadFromCollections();
  }

  @override
  void dispose() {
    _reportNameCtrl.dispose();
    _notesCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _loadFromCollections() {
    if (widget.collections.isNotEmpty) {
      final first = widget.collections.first;
      _reportNameCtrl.text = first.period.isNotEmpty
          ? 'Receivables Report — ${first.period}'
          : 'Receivables & Collection Report';

      // Pre-fill sample rows (improve mapping later if needed)
      _rows.add(_ProjectRow(
        projectName: 'Bishoftu–Chefe Donsa',
        client: 'ERA',
      ));
      _rows.add(_ProjectRow(
        projectName: 'Construction portfolio',
        client: 'ERA / AACRA',
      ));
    } else {
      _rows.add(_ProjectRow());
    }
  }

  void _addSelectedProject() {
    if (_selectedProjectId == null) {
      Get.snackbar('Select project', 'Please select a project first');
      return;
    }
    final project = _availableProjects.firstWhere((p) => p['id'] == _selectedProjectId);
    setState(() {
      _rows.add(_ProjectRow(
        projectName: project['name']!,
        client: project['client']!,
      ));
      _selectedProjectId = null;
    });
  }

  void _addBlankRow() {
    setState(() {
      _rows.add(_ProjectRow());
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  double get _sumWeekCollected {
    return _rows.fold(0.0, (sum, r) => sum + (double.tryParse(r.weekCollectedCtrl.text) ?? 0));
  }

  double get _sumRequested {
    return _rows.fold(0.0, (sum, r) => sum + (double.tryParse(r.requestedCtrl.text) ?? 0));
  }

  List<Map<String, dynamic>> _buildLines() {
    return _rows.map((r) {
      return {
        'project_name': r.projectCtrl.text.trim(),
        'client': r.clientCtrl.text.trim(),
        'requested': double.tryParse(r.requestedCtrl.text) ?? 0,
        'bill_period': r.billPeriodCtrl.text.trim(),
        'remaining': double.tryParse(r.remainingCtrl.text) ?? 0,
        'last_bill_date': r.lastBillDateCtrl.text.trim(),
        'week_expected': double.tryParse(r.weekExpectedCtrl.text) ?? 0,
        'week_collected': double.tryParse(r.weekCollectedCtrl.text) ?? 0,
      };
    }).toList();
  }

  // -------------------- Actions --------------------

  Future<void> _saveDraft() async {
    if (_rows.isEmpty) {
      Get.snackbar('Empty', 'Add at least one project row first');
      return;
    }

    setState(() => _savingDraft = true);
    try {
      final collectionId = widget.collections.isNotEmpty ? widget.collections.first.id : null;

      if (collectionId == null) {
        Get.snackbar('Error', 'No collection found to save against');
        return;
      }

      final result = await WorkflowReportService.saveProjectLines(
        collectionId: collectionId,
        lines: _buildLines(),
      );

      if (result['success'] == true) {
        Get.snackbar(
          'Saved',
          'Draft saved successfully',
          backgroundColor: _primary,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Failed to save draft',
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not save draft: $e');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _approveAndSend() async {
    if (_rows.isEmpty) {
      Get.snackbar('Empty', 'Add at least one project row before approving');
      return;
    }

    setState(() => _approving = true);
    try {
      final first = widget.collections.isNotEmpty ? widget.collections.first : null;

      if (first == null || first.projectId == null) {
        Get.snackbar('Error', 'Missing project information');
        return;
      }

      final templateData = {
        'period_section': _periodSection,
        'lines': _buildLines(),
        'sum_week_collected': _sumWeekCollected,
        'sum_requested': _sumRequested,
      };

      final result = await WorkflowReportService.createAndSendToTeamLeader(
        title: _reportNameCtrl.text.trim().isEmpty
            ? 'Receivables Report'
            : _reportNameCtrl.text.trim(),
        projectId: first.projectId!,
        sectorId: first.sectorId,
        businessUnitId: first.businessUnitId,
        periodLabel: first.period,
        periodFrom: first.periodFrom,
        periodTo: first.periodTo,
        collectionDataIds: widget.collections.map((c) => c.id).toList(),
        templateData: templateData,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (result['success'] == true) {
        Get.snackbar(
          'Approved',
          'Successfully sent to Team Leader',
          backgroundColor: _primary,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        Get.back(result: true);
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Failed to send to Team Leader',
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not approve: $e');
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _rejectToCollector() async {
    final remarkCtrl = TextEditingController();

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Reject to Collector'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Reason...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final remark = remarkCtrl.text.trim();
    if (remark.isEmpty) {
      Get.snackbar('Required', 'Please enter a rejection reason');
      return;
    }

    setState(() => _rejecting = true);
    try {
      final ids = widget.collections.map((c) => c.id).toList();

      final result = await WorkflowReportService.rejectToCollector(
        collectionIds: ids,
        remark: remark,
      );

      if (result['success'] == true) {
        Get.snackbar(
          'Rejected',
          'Sent back to Collector',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        Get.back(result: false);
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Failed to reject',
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not reject: $e');
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  Future<void> _generateTemplate() async {
    setState(() => _generating = true);
    try {
      final templateData = {
        'period_section': _periodSection,
        'lines': _buildLines(),
      };

      final result = await WorkflowReportService.generateCollectionTemplate(
        title: _reportNameCtrl.text.trim().isEmpty
            ? 'Receivables & Collection Template'
            : _reportNameCtrl.text.trim(),
        collectionDataIds: widget.collections.map((c) => c.id).toList(),
        templateData: templateData,
      );

      if (result['success'] == true) {
        Get.snackbar(
          'Generated',
          'Receivables & Collection Template generated successfully',
          backgroundColor: _primary,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Failed to generate template',
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not generate template: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _resubmit() async {
    setState(() => _resubmitting = true);
    try {
      await _saveDraft();
    } finally {
      if (mounted) setState(() => _resubmitting = false);
    }
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Senior Accountant — Review Projects',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Instruction
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Senior Accountant: Review / complete project rows from Collector. '
                  'Add missing projects from the registered list. Then Save and Approve to Team Leader.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),

          // Period + Project selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Period section:', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _periodSection,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Current Period Receivables',
                          child: Text('Current Period Receivables'),
                        ),
                        DropdownMenuItem(
                          value: 'Advance Payment',
                          child: Text('Advance Payment'),
                        ),
                        DropdownMenuItem(
                          value: 'Previous Years Receivables',
                          child: Text('Previous Years Receivables'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _periodSection = v ?? _periodSection),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      value: _selectedProjectId,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: '— select Superadmin project —',
                      ),
                      items: _availableProjects
                          .map((p) => DropdownMenuItem(
                        value: p['id'],
                        child: Text(p['name']!, overflow: TextOverflow.ellipsis),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedProjectId = v),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addSelectedProject,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add selected project'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addBlankRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add blank project row'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Project table
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(_primary.withOpacity(0.12)),
                columnSpacing: 14,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('PROJECT')),
                  DataColumn(label: Text('CLIENT')),
                  DataColumn(label: Text('REQUESTED')),
                  DataColumn(label: Text('BILL PERIOD')),
                  DataColumn(label: Text('REMAINING')),
                  DataColumn(label: Text('LAST BILL DATE')),
                  DataColumn(label: Text('WEEK EXPECTED')),
                  DataColumn(label: Text('WEEK COLLECTED')),
                  DataColumn(label: Text('')),
                ],
                rows: List.generate(_rows.length, (index) {
                  final r = _rows[index];
                  return DataRow(cells: [
                    DataCell(SizedBox(width: 30, child: Text('${index + 1}'))),
                    DataCell(SizedBox(
                      width: 160,
                      child: TextField(
                        controller: r.projectCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 100,
                      child: TextField(
                        controller: r.clientCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 90,
                      child: TextField(
                        controller: r.requestedCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 90,
                      child: TextField(
                        controller: r.billPeriodCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 90,
                      child: TextField(
                        controller: r.remainingCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 110,
                      child: TextField(
                        controller: r.lastBillDateCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 100,
                      child: TextField(
                        controller: r.weekExpectedCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 100,
                      child: TextField(
                        controller: r.weekCollectedCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    )),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        onPressed: () => _removeRow(index),
                      ),
                    ),
                  ]);
                }),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Sums
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sum of week collected (all rows)',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(_numberFormat.format(_sumWeekCollected),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sum of requested', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(_numberFormat.format(_sumRequested),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton(
                onPressed: _resubmitting ? null : _resubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: _resubmitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Resubmit project details'),
              ),
              OutlinedButton(
                onPressed: _savingDraft ? null : _saveDraft,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: _savingDraft
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save draft'),
              ),
              ElevatedButton(
                onPressed: _approving ? null : _approveAndSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: _approving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Approve received & send to Team Leader'),
              ),
              OutlinedButton(
                onPressed: _rejecting ? null : _rejectToCollector,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: _rejecting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Reject to Collector'),
              ),
              OutlinedButton(
                onPressed: _generating ? null : _generateTemplate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: _generating
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Generate Receivables & Collection Template'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            'Senior Accountant flow: (1) Receive report from Collector → (2) Fill Project-level receivables table — detail every project → (3) Save project details → (4) Approve received & send to Team Leader (or Reject to Collector).',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// -------------------- Helper class --------------------
class _ProjectRow {
  final projectCtrl = TextEditingController();
  final clientCtrl = TextEditingController();
  final requestedCtrl = TextEditingController(text: '0.00');
  final billPeriodCtrl = TextEditingController();
  final remainingCtrl = TextEditingController(text: '0.00');
  final lastBillDateCtrl = TextEditingController();
  final weekExpectedCtrl = TextEditingController(text: '0.00');
  final weekCollectedCtrl = TextEditingController(text: '0.00');

  _ProjectRow({String? projectName, String? client}) {
    if (projectName != null) projectCtrl.text = projectName;
    if (client != null) clientCtrl.text = client;
  }

  void dispose() {
    projectCtrl.dispose();
    clientCtrl.dispose();
    requestedCtrl.dispose();
    billPeriodCtrl.dispose();
    remainingCtrl.dispose();
    lastBillDateCtrl.dispose();
    weekExpectedCtrl.dispose();
    weekCollectedCtrl.dispose();
  }
}