import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/workflow_report.dart';
import '../../services/summary_report_generator.dart';
import '../../services/workflow_report_service.dart';
import '../../widgets/role_scaffold.dart';
import '../../widgets/paginated_list.dart';

class ReviewReportScreen extends StatefulWidget {
  final WorkflowReport report;

  const ReviewReportScreen({super.key, required this.report});

  @override
  State<ReviewReportScreen> createState() => _ReviewReportScreenState();
}

class _ReviewReportScreenState extends State<ReviewReportScreen> {
  static const Color _primary = Color(0xFF0D7377);

  final _remarkCtrl = TextEditingController();
  String? _summaryPath;
  String? _summaryName;
  bool _working = false;
  bool _generating = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.report.status;
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  bool get _isPending => _status == 'sent_to_team_leader';
  bool get _canSendOnward => _status == 'approved_by_team_leader';
  bool get _alreadySent => _status == 'sent_to_management';

  String get _suggestedName {
    final from = widget.report.periodFrom != null
        ? DateFormat('MMM_d,yyyy').format(widget.report.periodFrom!)
        : 'Jul_1,2026';
    final to = widget.report.periodTo != null
        ? DateFormat('MMM_d,yyyy').format(widget.report.periodTo!)
        : 'Aug_11,2026';
    return '4_Sectors_${from}_to_${to}_Collection_summary_Report.xlsx';
  }

  Future<void> _pickSummary() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xls', 'xlsx', 'csv', 'pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _summaryPath = result.files.single.path;
        _summaryName = result.files.single.name;
      });
    }
  }

  Future<void> _generateSummary() async {
    final data = widget.report.templateData;
    if (data == null || data.isEmpty) {
      Get.snackbar(
        'No data',
        'This report has no template_data from Senior Accountant.\n'
            'Make sure the API returns template_data.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final from = widget.report.periodFrom != null
          ? DateFormat('yyyy-MM-dd').format(widget.report.periodFrom!)
          : '2026-07-01';
      final to = widget.report.periodTo != null
          ? DateFormat('yyyy-MM-dd').format(widget.report.periodTo!)
          : '2026-08-11';

      final path = await SummaryReportGenerator.generate(
        templateData: data,
        periodFrom: from,
        periodTo: to,
      );

      setState(() {
        _summaryPath = path;
        _summaryName = path.split(Platform.pathSeparator).last;
      });

      Get.snackbar(
        'Generated',
        '4-Sectors summary created: $_summaryName',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _primary,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not generate summary: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _reject() async {
    final remark = _remarkCtrl.text.trim();
    if (remark.isEmpty) {
      Get.snackbar(
        'Remark required',
        'Please write a remark when rejecting.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Reject report?'),
        content: Text('Remark will go to Senior Accountant:\n\n"$remark"'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _working = true);
    try {
      final result = await WorkflowReportService.teamLeaderAction(
        workflowReportId: widget.report.id,
        action: 'rejected',
        remark: remark,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        Get.snackbar('Rejected', 'Returned to Senior Accountant',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade100);
        Get.back(result: true);
      } else {
        Get.snackbar('Error', result['message']?.toString() ?? 'Failed',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade100);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _working = true);
    try {
      final result = await WorkflowReportService.teamLeaderAction(
        workflowReportId: widget.report.id,
        action: 'approved',
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _status = 'approved_by_team_leader');
        Get.snackbar(
          'Approved',
          'Now generate/upload the 4-Sectors summary and send to Management & Finance.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar('Error', result['message']?.toString() ?? 'Failed',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade100);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendOnward() async {
    if (_summaryPath == null) {
      final cont = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('No summary file'),
          content: const Text(
            'Generate or select the 4-Sectors summary before sending.\n\nContinue without it?',
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('Go back')),
            TextButton(onPressed: () => Get.back(result: true), child: const Text('Send without')),
          ],
        ),
      );
      if (cont != true) return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Send to Management & Finance?'),
        content: Text(
          _summaryPath != null
              ? 'File 1 (template) + File 2 ($_summaryName) will be sent.'
              : 'Only File 1 (template) will be sent.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _working = true);
    try {
      final result = await WorkflowReportService.sendToManagementAndFinance(
        workflowReportId: widget.report.id,
        summaryFilePath: _summaryPath,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _status = 'sent_to_management');
        Get.snackbar('Sent', 'Sent to Management and Finance Director',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: _primary,
            colorText: Colors.white);
        Get.back(result: true);
      } else {
        Get.snackbar('Error', result['message']?.toString() ?? 'Failed',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade100);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return RoleScaffold(
      title: 'Review Report',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (report.preparedByName != null)
                    _info('Prepared by', report.preparedByName!),
                  if (report.periodLabel != null)
                    _info('Period', report.periodLabel!),
                  if (report.sectorName != null)
                    _info('Sector', report.sectorName!),
                  if (report.businessUnitName != null)
                    _info('Business Unit', report.businessUnitName!),
                  _info('Status', _status.replaceAll('_', ' ')),
                  if (report.templateFileUrl != null)
                    _info('Template (File 1)', 'Attached'),
                  if (report.summaryFileUrl != null)
                    _info('Summary (File 2)', 'Attached'),
                ],
              ),
            ),
          ),

          // Pending review
          if (_isPending) ...[
            const SizedBox(height: 20),
            const Text('Your decision',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarkCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remark',
                hintText: 'Required when rejecting',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _working ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reject + Remark'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _working ? null : _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _working
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],

          // After approve → generate + send
          if (_canSendOnward) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Approved. Generate the 4-Sectors summary, then send both files to Management & Finance.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Collection Summary (File 2)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Suggested: $_suggestedName',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 10),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _generateSummary,
                icon: _generating
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.table_chart),
                label: Text(_generating
                    ? 'Generating...'
                    : 'Generate 4-Sectors Summary Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Or pick manually
            OutlinedButton.icon(
              onPressed: _working ? null : _pickSummary,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _summaryName ?? 'Or select summary file manually',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_summaryName != null) ...[
              const SizedBox(height: 6),
              Text('Selected: $_summaryName',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _working ? null : _sendOnward,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send),
                label: Text(_working
                    ? 'Sending...'
                    : 'Send to Management & Finance'),
              ),
            ),
          ],

          if (_alreadySent) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Already sent to Management and Finance.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}