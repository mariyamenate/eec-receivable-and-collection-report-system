import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/project.dart';
import '../../services/organization_service.dart';
import '../../widgets/role_scaffold.dart';

class ProjectsScreen extends StatefulWidget {
  final int sectorId;
  final String sectorName;
  final String businessUnitName;

  const ProjectsScreen({
    super.key,
    required this.sectorId,
    required this.sectorName,
    required this.businessUnitName,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _items = [];
  bool _loading = true;
  String? _error;

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
      final list = await OrganizationService.getProjects(sectorId: widget.sectorId);
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

  Future<void> _showForm({Project? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String status = existing?.status ?? 'active';
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Project' : 'Edit Project'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.businessUnitName} › ${widget.sectorName}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Project name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'on_hold', child: Text('On Hold')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => status = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        Map<String, dynamic> result;
                        if (existing == null) {
                          result = await OrganizationService.createProject(
                            sectorId: widget.sectorId,
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim().isEmpty
                                ? null
                                : codeCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            status: status,
                          );
                        } else {
                          result = await OrganizationService.updateProject(
                            id: existing.id,
                            sectorId: widget.sectorId,
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim().isEmpty
                                ? null
                                : codeCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            status: status,
                          );
                        }
                        setDialogState(() => saving = false);
                        if (result['success'] == true) {
                          Get.back();
                          Get.snackbar(
                            'Success',
                            existing == null ? 'Project created' : 'Project updated',
                          );
                          _load();
                        } else {
                          Get.snackbar(
                            'Error',
                            result['message']?.toString() ?? 'Failed',
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(existing == null ? 'Save' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Project item) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete project "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await OrganizationService.deleteProject(item.id);
    if (result['success'] == true) {
      Get.snackbar('Deleted', item.name);
      _load();
    } else {
      Get.snackbar('Error', result['message']?.toString() ?? 'Delete failed');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'on_hold':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Projects — ${widget.sectorName}',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: _primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Project', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
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
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'No projects in this sector yet.\nTap + Add Project.',
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
                                leading: CircleAvatar(
                                  backgroundColor: _primary.withValues(alpha: 0.15),
                                  child: const Icon(Icons.folder, color: _primary),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Row(
                                  children: [
                                    if (item.code != null && item.code!.isNotEmpty) ...[
                                      Text('Code: ${item.code}  '),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(item.status).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.status.replaceAll('_', ' '),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _statusColor(item.status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _showForm(existing: item);
                                    } else if (v == 'delete') {
                                      _confirmDelete(item);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                                onTap: () => _showForm(existing: item),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
