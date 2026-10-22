import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/collection_data.dart';
import '../../models/workflow_report.dart';
import '../../services/collection_service.dart';
import '../../services/workflow_report_service.dart';
import '../../widgets/role_scaffold.dart';
import 'build_template_screen.dart';

class MyTemplatesScreen extends StatefulWidget {
  const MyTemplatesScreen({super.key});

  @override
  State<MyTemplatesScreen> createState() => _MyTemplatesScreenState();
}

class _MyTemplatesScreenState extends State<MyTemplatesScreen> {
  static const Color _primary = Color(0xFF0D7377);

  List<WorkflowReport> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await WorkflowReportService.getReports(
        scope: 'mine',
      );

      if (!mounted) return;

      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openBuildTemplateScreen() async {
    try {
      final List<CollectionData> collections =
      await CollectionService.getIncoming(
        status: 'submitted',
      );

      if (!mounted) return;

      if (collections.isEmpty) {
        Get.snackbar(
          'No collector reports',
          'There are no submitted collector reports available to build a template.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.black,
        );
        return;
      }

      final created = await Get.to<bool>(
            () => BuildTemplateScreen(
          collections: collections,
        ),
      );

      if (created == true) {
        await _load();
      }
    } catch (error) {
      if (!mounted) return;

      Get.snackbar(
        'Error',
        'Could not load submitted collector reports: $error',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black,
      );
    }
  }

  Color _statusColor(String status) {
    if (status.contains('rejected')) {
      return Colors.red;
    }

    if (status.contains('approved') || status.contains('sent_to_top')) {
      return Colors.green;
    }

    if (status.contains('sent')) {
      return Colors.blue;
    }

    if (status == 'draft') {
      return Colors.orange;
    }

    return Colors.grey;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'sent_to_team_leader':
        return 'Sent to Team Leader';
      case 'rejected_by_team_leader':
        return 'Rejected by Team Leader';
      case 'approved_by_team_leader':
        return 'Approved by Team Leader';
      case 'sent_to_management':
        return 'Sent to Management';
      case 'rejected_by_management':
        return 'Rejected by Management';
      case 'approved_by_management':
        return 'Approved by Management';
      case 'sent_to_top_management':
        return 'At Top Management';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Widget _buildReportItem(WorkflowReport item) {
    final statusColor = _statusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: _primary.withValues(alpha: 0.12),
          child: const Icon(
            Icons.description_outlined,
            color: _primary,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.periodLabel != null &&
                item.periodLabel!.trim().isNotEmpty)
              Text('Period: ${item.periodLabel}'),
            if (item.sectorName != null &&
                item.sectorName!.trim().isNotEmpty)
              Text('Sector: ${item.sectorName}'),
            if (item.teamLeaderRemark != null &&
                item.teamLeaderRemark!.trim().isNotEmpty)
              Text(
                'TL Remark: ${item.teamLeaderRemark}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            if (item.managementRemark != null &&
                item.managementRemark!.trim().isNotEmpty)
              Text(
                'Management Remark: ${item.managementRemark}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
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
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabel(item.status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Add WorkflowReportDetailScreen navigation later if needed.
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'My Templates / Reports',
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: _primary,
        ),
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openBuildTemplateScreen,
                icon: const Icon(Icons.add_chart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
                label: const Text(
                  'Build Template From Collector Reports',
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: _primary,
              child: _items.isEmpty
                  ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'No templates have been created yet.\n'
                          'Use “Build Template From Collector Reports” '
                          'to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _buildReportItem(_items[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}