import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/workflow_report.dart';
import '../../services/workflow_report_service.dart';
import '../../widgets/role_scaffold.dart';
import '../../widgets/paginated_list.dart';

/// Read-only report browser for Finance Director and Top Management.
class ReportListScreen extends StatefulWidget {
  final String title;
  final String scope;
  final String? initialStatus;
  final bool showFilters;

  const ReportListScreen({
    super.key,
    required this.title,
    required this.scope,
    this.initialStatus,
    this.showFilters = true,
  });

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  List<WorkflowReport> _items = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  static const Color _primary = Color(0xFF0D7377);

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await WorkflowReportService.getReports(
        scope: widget.scope,
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
    if (status.contains('sent')) return Colors.blue;
    return Colors.grey;
  }

  String _statusLabel(String status) {
    return status.replaceAll('_', ' ');
  }

  void _openDetail(WorkflowReport item) {
    Get.to(() => ReportDetailScreen(report: item));
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: widget.title,
      body: Column(
        children: [
          if (widget.showFilters)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _chip('All', null),
                  _chip('At Management', 'sent_to_management'),
                  _chip('Approved', 'approved_by_management'),
                  _chip('At Top Mgmt', 'sent_to_top_management'),
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
                                      'No reports available yet.',
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
                                          if (item.periodLabel != null)
                                            Text('Period: ${item.periodLabel}'),
                                          if (item.sectorName != null)
                                            Text('Sector: ${item.sectorName}'),
                                          if (item.businessUnitName != null)
                                            Text('Unit: ${item.businessUnitName}'),
                                          if (item.createdAt != null)
                                            Text(
                                              DateFormat('MMM d, yyyy')
                                                  .format(item.createdAt!),
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
                                      onTap: () => _openDetail(item),
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

class ReportDetailScreen extends StatelessWidget {
  final WorkflowReport report;

  const ReportDetailScreen({super.key, required this.report});

  static const Color _primary = Color(0xFF0D7377);

  @override
  Widget build(BuildContext context) {
    final r = report;
    return RoleScaffold(
      title: 'Report Detail',
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (r.preparedByName != null) _row('Prepared by', r.preparedByName!),
                  if (r.periodLabel != null) _row('Period', r.periodLabel!),
                  if (r.sectorName != null) _row('Sector', r.sectorName!),
                  if (r.businessUnitName != null) _row('Business Unit', r.businessUnitName!),
                  _row('Status', r.status.replaceAll('_', ' ')),
                  const Divider(height: 24),
                  const Text(
                    'Files',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _fileRow(
                    'Receivables & Collection Template',
                    r.templateFileUrl != null,
                  ),
                  _fileRow(
                    'Collection Summary Report',
                    r.summaryFileUrl != null,
                  ),
                  if (r.teamLeaderRemark != null && r.teamLeaderRemark!.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text('Team Leader remark',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(r.teamLeaderRemark!),
                  ],
                  if (r.managementRemark != null && r.managementRemark!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Management remark',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(r.managementRemark!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'View only — no approve or reject actions on this screen.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _fileRow(String name, bool available) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        available ? Icons.insert_drive_file : Icons.insert_drive_file_outlined,
        color: available ? _primary : Colors.grey,
      ),
      title: Text(name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        available ? 'Available' : 'Not attached',
        style: TextStyle(
          fontSize: 12,
          color: available ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}
