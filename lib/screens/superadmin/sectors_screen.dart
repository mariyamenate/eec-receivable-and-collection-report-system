import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/sector.dart';
import '../../services/organization_service.dart';
import '../../widgets/role_scaffold.dart';
import 'projects_screen.dart';

class SectorsScreen extends StatefulWidget {
  final int businessUnitId;
  final String businessUnitName;

  const SectorsScreen({
    super.key,
    required this.businessUnitId,
    required this.businessUnitName,
  });

  @override
  State<SectorsScreen> createState() => _SectorsScreenState();
}

class _SectorsScreenState extends State<SectorsScreen> {
  List<Sector> _items = [];
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
      final list = await OrganizationService.getSectors(
        businessUnitId: widget.businessUnitId,
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

  Future<void> _showForm({Sector? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Sector' : 'Edit Sector'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Business Unit: ${widget.businessUnitName}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sector name *',
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
                          result = await OrganizationService.createSector(
                            businessUnitId: widget.businessUnitId,
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim().isEmpty
                                ? null
                                : codeCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                          );
                        } else {
                          result = await OrganizationService.updateSector(
                            id: existing.id,
                            businessUnitId: widget.businessUnitId,
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim().isEmpty
                                ? null
                                : codeCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                          );
                        }
                        setDialogState(() => saving = false);
                        if (result['success'] == true) {
                          Get.back();
                          Get.snackbar(
                            'Success',
                            existing == null ? 'Sector created' : 'Sector updated',
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

  Future<void> _confirmDelete(Sector item) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Sector'),
        content: Text('Delete "${item.name}" and its projects?'),
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
    final result = await OrganizationService.deleteSector(item.id);
    if (result['success'] == true) {
      Get.snackbar('Deleted', item.name);
      _load();
    } else {
      Get.snackbar('Error', result['message']?.toString() ?? 'Delete failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Sectors — ${widget.businessUnitName}',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: _primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Sector', style: TextStyle(color: Colors.white)),
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
                                'No sectors yet.\nFor Consultancy, add the 3 sectors here.',
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
                                  child: const Icon(Icons.category, color: _primary),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  [
                                    if (item.code != null && item.code!.isNotEmpty)
                                      'Code: ${item.code}',
                                    if (item.projectCount != null)
                                      '${item.projectCount} project(s)',
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'projects') {
                                      Get.to(() => ProjectsScreen(
                                            sectorId: item.id,
                                            sectorName: item.name,
                                            businessUnitName: widget.businessUnitName,
                                          ));
                                    } else if (v == 'edit') {
                                      _showForm(existing: item);
                                    } else if (v == 'delete') {
                                      _confirmDelete(item);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'projects',
                                      child: Text('View Projects'),
                                    ),
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Get.to(() => ProjectsScreen(
                                        sectorId: item.id,
                                        sectorName: item.name,
                                        businessUnitName: widget.businessUnitName,
                                      ));
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
