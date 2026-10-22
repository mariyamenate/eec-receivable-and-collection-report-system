import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/collection_data.dart';
import '../../services/collection_service.dart';
import '../../widgets/role_scaffold.dart';

import '../collector/collect_data_screen.dart';

class IncomingCollectionsScreen extends StatefulWidget {
  const IncomingCollectionsScreen({super.key});

  @override
  State<IncomingCollectionsScreen> createState() =>
      _IncomingCollectionsScreenState();
}

class _IncomingCollectionsScreenState
    extends State<IncomingCollectionsScreen> {
  static const Color _primary = Color(0xFF0D7377);

  List<CollectionData> _items = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter = 'submitted';

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

    try {
      final list = await CollectionService.getIncoming(
        status: _statusFilter,
      );

      // ========== DEBUG ==========
      debugPrint('>>> IncomingCollectionsScreen loaded ${list.length} items (filter=$_statusFilter)');
      for (var item in list) {
        debugPrint(
            '   → id=${item.id} | status=${item.status} | project=${item.projectName}');
      }
      // ==========================

      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('>>> IncomingCollectionsScreen ERROR: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    if (status.contains('rejected')) return Colors.red;
    if (status.contains('sent_to_team_leader')) return Colors.green;
    if (status == 'submitted') return Colors.orange;
    return Colors.grey;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Pending your review';
      case 'rejected_by_senior_accountant':
        return 'You rejected to Collector';
      case 'sent_to_team_leader':
        return 'Sent to Team Leader';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM d, yyyy').format(date);
  }


  Future<void> _openReport(CollectionData item) async {
    final result = await Get.to<bool>(
          () => CollectDataScreen(
        existing: item,
        readOnly: true,
        readOnlyTitle: 'Review Submission',
        onApprove: () => _approve(item),
        onReject: () => _reject(item),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _approve(CollectionData item) async {
    try {

      final result = await CollectionService.approve(id: item.id);

      if (result['success'] == true) {
        Get.back(); // close the read-only review screen
        Get.snackbar(
          'Approved',
          'Sent to Team Leader',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText: Colors.white,
        );
        _load();
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Could not approve',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not approve: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }


  Future<void> _reject(CollectionData item) async {
    final remarkCtrl = TextEditingController();

    final remark = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject submission'),
        content: TextField(
          controller: remarkCtrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Remark *',
            hintText: 'Explain why you are rejecting this report',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (remarkCtrl.text.trim().isEmpty) {
                Get.snackbar(
                  'Required',
                  'Please write a remark before rejecting',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }
              Navigator.of(dialogContext).pop(remarkCtrl.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    // Cancelled the dialog — do nothing.
    if (remark == null || remark.isEmpty) return;

    try {
      // NOTE: adjust to match your actual CollectionService method /
      // parameter names.
      final result = await CollectionService.reject(
        id: item.id,
        remark: remark,
      );

      if (result['success'] == true) {
        Get.back(); // close the read-only review screen
        Get.snackbar(
          'Rejected',
          'Sent back to the collector with your remark',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
        _load();
      } else {
        Get.snackbar(
          'Error',
          result['message']?.toString() ?? 'Could not reject',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not reject: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Incoming Collections',
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _chip('Pending', 'submitted'),
                _chip('Rejected by me', 'rejected_by_senior_accountant'),
                _chip('Sent to TL', 'sent_to_team_leader'),
                _chip('All', null),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
                : _error != null
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _load,
              color: _primary,
              child: _items.isEmpty
                  ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'No collector submissions waiting.\n'
                          'Collectors send data here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final pending = item.status == 'submitted';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(item.status)
                            .withValues(alpha: 0.15),
                        child: Icon(
                          pending
                              ? Icons.pending_actions
                              : Icons.description,
                          color: _statusColor(item.status),
                        ),
                      ),
                      title: Text(
                        item.projectName ??
                            'Project #${item.projectId ?? '-'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          if ((item.sectorName ?? '')
                              .trim()
                              .isNotEmpty)
                            Text('Sector: ${item.sectorName}'),
                          Text(
                            'Period: '
                                '${_formatDate(item.periodFrom)} - '
                                '${_formatDate(item.periodTo)}',
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(item.status)
                                  .withValues(alpha: 0.15),
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: Text(
                              _statusLabel(item.status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(item.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openReport(item),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? status) {
    final selected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: _primary.withValues(alpha: 0.2),
        checkmarkColor: _primary,
        onSelected: (_) {
          setState(() => _statusFilter = status);
          _load();
        },
      ),
    );
  }
}