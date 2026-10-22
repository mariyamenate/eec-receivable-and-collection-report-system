import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/business_unit.dart';
import '../../services/organization_service.dart';
import '../../widgets/role_scaffold.dart';
import 'sectors_screen.dart';

class BusinessUnitsScreen extends StatefulWidget {
  const BusinessUnitsScreen({super.key});

  @override
  State<BusinessUnitsScreen> createState() => _BusinessUnitsScreenState();
}

class _BusinessUnitsScreenState extends State<BusinessUnitsScreen> {
  List<BusinessUnit> _items = [];
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
      final list = await OrganizationService.getBusinessUnits();
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

  Future<void> _showForm({BusinessUnit? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Business Unit' : 'Edit Business Unit'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name *',
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
                          result = await OrganizationService.createBusinessUnit(
                            name: nameCtrl.text.trim(),
                            code: codeCtrl.text.trim().isEmpty
                                ? null
                                : codeCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                          );
                        } else {
                          result = await OrganizationService.updateBusinessUnit(
                            id: existing.id,
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
                          Get.snackbar('Success', existing == null
                              ? 'Business unit created'
                              : 'Business unit updated');
                          _load();
                        } else {
                          Get.snackbar(
                            'Error',
                            result['message']?.toString() ?? 'Failed',
                            backgroundColor: Colors.red.shade100,
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

  Future<void> _confirmDelete(BusinessUnit item) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Business Unit'),
        content: Text(
          'Delete "${item.name}"?\nSectors and projects under it may be affected.',
        ),
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
    final result = await OrganizationService.deleteBusinessUnit(item.id);
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
      title: 'Business Units',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: _primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
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
                                'No business units yet.\nTap + Add to create one.',
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
                                  child: const Icon(Icons.business, color: _primary),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  [
                                    if (item.code != null && item.code!.isNotEmpty)
                                      'Code: ${item.code}',
                                    if (item.sectorCount != null)
                                      '${item.sectorCount} sector(s)',
                                    if (item.projectCount != null)
                                      '${item.projectCount} project(s)',
                                  ].join(' · '),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'sectors') {
                                      Get.to(() => SectorsScreen(
                                            businessUnitId: item.id,
                                            businessUnitName: item.name,
                                          ));
                                    } else if (v == 'edit') {
                                      _showForm(existing: item);
                                    } else if (v == 'delete') {
                                      _confirmDelete(item);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'sectors',
                                      child: Text('View Sectors'),
                                    ),
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Get.to(() => SectorsScreen(
                                        businessUnitId: item.id,
                                        businessUnitName: item.name,
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
