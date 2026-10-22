import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/collection_data.dart';
import '../../services/collection_service.dart';
import '../../widgets/role_scaffold.dart';
import 'collect_data_screen.dart';

class MyCollectionsScreen extends StatefulWidget {
  const MyCollectionsScreen({super.key});

  @override
  State<MyCollectionsScreen> createState() => _MyCollectionsScreenState();
}

class _MyCollectionsScreenState extends State<MyCollectionsScreen> {
  List<CollectionData> _items = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

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
      final list = await CollectionService.getMyCollections(status: _statusFilter);
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
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'submitted':
        return Colors.blue;
      case 'received':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Sent to Senior Accountant';
      case 'received':
        return 'Received';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'My Collections',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.to(() => const CollectDataScreen());
          if (result == true) _load();
        },
        backgroundColor: _primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _chip('All', null),
                _chip('Draft', 'draft'),
                _chip('Submitted', 'submitted'),
                _chip('Received', 'received'),
                _chip('Rejected', 'rejected'),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                      'No collection records yet.\nTap + New to collect data.',
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
                        vertical: 8,
                      ),
                      title: Text(
                        item.projectName ?? 'Project #${item.projectId ?? "-"}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (item.period.isNotEmpty)
                            Text('Period: ${item.period}'),
                          if (item.sectorName != null)
                            Text('Sector: ${item.sectorName}'),
                          if (item.submittedAt != null)
                            Text(
                              'Sent: ${DateFormat('MMM d, yyyy HH:mm').format(item.submittedAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          if (item.remark != null && item.remark!.isNotEmpty)
                            Text(
                              'Remark: ${item.remark}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
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
                      // ========== ADDED: Open for edit ==========
                      onTap: () async {
                        final result = await Get.to(
                              () => CollectDataScreen(existing: item),
                        );
                        if (result == true) _load();
                      },
                      // ==========================================
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