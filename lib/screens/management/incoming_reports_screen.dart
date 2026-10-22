import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/workflow_report.dart';
import '../../services/workflow_report_service.dart';
import '../../widgets/role_scaffold.dart';
import 'review_report_screen.dart';

class ManagementIncomingScreen extends StatefulWidget {
  const ManagementIncomingScreen({super.key});

  @override
  State<ManagementIncomingScreen> createState() => _ManagementIncomingScreenState();
}

class _ManagementIncomingScreenState extends State<ManagementIncomingScreen> {
  List<WorkflowReport> _items = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter = 'sent_to_management';

  static const Color _primary = Color(0xFF0D7377);

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
      final list = await WorkflowReportService.getReports(
        scope: 'incoming_management',
        status: _statusFilter,
      );
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    if (status.contains('rejected')) return Colors.red;
    if (status.contains('approved') || status.contains('top')) return Colors.green;
    if (status == 'sent_to_management') return Colors.orange;
    return Colors.grey;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'sent_to_management':
        return 'Pending your review';
      case 'rejected_by_management':
        return 'You rejected';
      case 'approved_by_management':
        return 'You approved';
      case 'sent_to_top_management':
        return 'Sent to Top Management';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Reports for Review',
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _chip('Pending', 'sent_to_management'),
                _chip('Approved', 'approved_by_management'),
                _chip('Rejected', 'rejected_by_management'),
                _chip('Sent to Top', 'sent_to_top_management'),
                _chip('All', null),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            ElevatedButton(onPressed: _load, child: const Text('Retry')),
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
                                      'No reports waiting.\nTeam Leader sends approved reports here.',
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
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: _statusColor(item.status)
                                            .withValues(alpha: 0.15),
                                        child: Icon(
                                          Icons.description,
                                          color: _statusColor(item.status),
                                        ),
                                      ),
                                      title: Text(
                                        item.title,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (item.preparedByName != null)
                                            Text('Prepared: ${item.preparedByName}'),
                                          if (item.periodLabel != null)
                                            Text('Period: ${item.periodLabel}'),
                                          if (item.sectorName != null)
                                            Text('Sector: ${item.sectorName}'),
                                          if (item.createdAt != null)
                                            Text(
                                              DateFormat('MMM d, yyyy').format(item.createdAt!),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
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
                                              borderRadius: BorderRadius.circular(8),
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
                                      onTap: () async {
                                        final result = await Get.to(
                                          () => ManagementReviewScreen(report: item),
                                        );
                                        if (result == true) _load();
                                      },
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
