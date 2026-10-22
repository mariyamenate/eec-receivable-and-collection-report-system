import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/workflow_report.dart';
import '../../services/workflow_report_service.dart';
import '../../widgets/role_scaffold.dart';

class ManagementReviewScreen extends StatefulWidget {
  final WorkflowReport report;

  const ManagementReviewScreen({
    super.key,
    required this.report,
  });

  @override
  State<ManagementReviewScreen> createState() =>
      _ManagementReviewScreenState();
}

class _ManagementReviewScreenState extends State<ManagementReviewScreen> {
  final _remarkCtrl = TextEditingController();
  bool _working = false;

  static const Color _primary = Color(0xFF0D7377);

  bool get _isPending => widget.report.status == 'sent_to_management';

  bool get _isApproved => widget.report.status == 'approved_by_management';

  bool get _alreadySent =>
      widget.report.status == 'sent_to_top_management';

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    final remark = _remarkCtrl.text.trim();
    if (remark.isEmpty) {
      Get.snackbar(
        'Remark required',
        'Please write a remark when rejecting',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
      return;
    }

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Reject report?'),
        content: Text(
          'Remark will go back to Team Leader:\n\n"$remark"',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
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
      final result = await WorkflowReportService.managementAction(
        workflowReportId: widget.report.id,
        action: 'rejected',
        remark: remark,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Get.snackbar(
          'Rejected',
          'Report returned to Team Leader with remark',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black,
        );
        Get.back(result: true);
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Failed',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Could not reject: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _working = true);
    try {
      final result = await WorkflowReportService.managementAction(
        workflowReportId: widget.report.id,
        action: 'approved',
        remark: _remarkCtrl.text.trim().isEmpty
            ? null
            : _remarkCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Get.snackbar(
          'Approved',
          'You can now send to Top Management',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );
        Get.back(result: true);
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Failed',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Could not approve: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendToTop() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Send to Top Management?'),
        content: const Text(
          'The approved report will be forwarded to Top Management.',
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
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _working = true);
    try {
      final result = await WorkflowReportService.sendToTopManagement(
        workflowReportId: widget.report.id,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Get.snackbar(
          'Sent',
          'Report sent to Top Management',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );
        Get.back(result: true);
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Failed',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Error',
        'Could not send: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;

    return RoleScaffold(
      title: 'Management Review',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (r.preparedByName != null)
                    _info('Prepared by', r.preparedByName!),
                  if (r.periodLabel != null) _info('Period', r.periodLabel!),
                  if (r.sectorName != null) _info('Sector', r.sectorName!),
                  if (r.businessUnitName != null)
                    _info('Business Unit', r.businessUnitName!),
                  _info('Status', r.status.replaceAll('_', ' ')),
                  if (r.templateFileUrl != null)
                    _info('Template', 'Receivables & Collection file attached'),
                  if (r.summaryFileUrl != null)
                    _info('Summary', 'Collection summary report attached'),
                  if (r.teamLeaderRemark != null &&
                      r.teamLeaderRemark!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Team Leader remark: ${r.teamLeaderRemark}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  if (r.managementRemark != null &&
                      r.managementRemark!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Your remark: ${r.managementRemark}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_isPending) ...[
            const SizedBox(height: 20),
            const Text(
              'Your decision',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarkCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remark (required if rejecting)',
                hintText: 'Reason for rejection or optional note',
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],

          if (_isApproved) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Approved. Forward this report to Top Management.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _working ? null : _sendToTop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send),
                label: Text(
                  _working ? 'Sending...' : 'Send to Top Management',
                ),
              ),
            ),
          ],

          if (_alreadySent) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Already sent to Top Management.',
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}