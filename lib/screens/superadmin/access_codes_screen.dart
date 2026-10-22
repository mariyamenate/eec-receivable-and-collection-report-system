import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../models/access_code.dart';
import '../../models/business_unit.dart';
import '../../models/sector.dart';
import '../../services/access_code_service.dart';
import '../../services/organization_service.dart';
import '../../widgets/role_scaffold.dart';

class AccessCodesScreen extends StatefulWidget {
  const AccessCodesScreen({super.key});

  @override
  State<AccessCodesScreen> createState() => _AccessCodesScreenState();
}

class _AccessCodesScreenState extends State<AccessCodesScreen> {
  List<AccessCode> _items = [];
  List<BusinessUnit> _units = [];
  List<Sector> _sectors = [];
  bool _loading = true;
  String? _error;
  String? _filterRole;
  bool _unusedOnly = false;

  static const Color _primary = Color(0xFF0D7377);

  static const List<Map<String, String>> _roles = [
    {'value': 'collector', 'label': 'Collector'},
    {'value': 'senior_accountant', 'label': 'Senior Accountant'},
    {'value': 'team_leader', 'label': 'Team Leader'},
    {'value': 'finance_director', 'label': 'Finance Director'},
    {'value': 'management', 'label': 'Management'},
    {'value': 'top_management', 'label': 'Top Management'},
    {'value': 'superadmin', 'label': 'Super Admin'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AccessCodeService.getAll(role: _filterRole, unusedOnly: _unusedOnly),
        OrganizationService.getBusinessUnits(),
        OrganizationService.getSectors(),
      ]);
      setState(() {
        _items = results[0] as List<AccessCode>;
        _units = results[1] as List<BusinessUnit>;
        _sectors = results[2] as List<Sector>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showCreateOrEdit({AccessCode? existing}) async {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String role = existing?.role ?? 'collector';
    int? businessUnitId = existing?.businessUnitId;
    int? sectorId = existing?.sectorId;
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool autoGenerate = existing == null;

    List<Sector> filteredSectors = businessUnitId == null
        ? _sectors
        : _sectors.where((s) => s.businessUnitId == businessUnitId).toList();

    await Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? 'Create Access Code' : 'Edit Access Code'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Role
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(
                        labelText: 'Role *',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles
                          .map((r) => DropdownMenuItem(
                                value: r['value'],
                                child: Text(r['label']!),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => role = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Business Unit (optional)
                    DropdownButtonFormField<int?>(
                      value: businessUnitId,
                      decoration: const InputDecoration(
                        labelText: 'Business Unit (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('-- None --'),
                        ),
                        ..._units.map(
                          (u) => DropdownMenuItem(value: u.id, child: Text(u.name)),
                        ),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          businessUnitId = v;
                          sectorId = null;
                          filteredSectors = v == null
                              ? _sectors
                              : _sectors.where((s) => s.businessUnitId == v).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Sector (optional — preferred from access code)
                    DropdownButtonFormField<int?>(
                      value: sectorId,
                      decoration: const InputDecoration(
                        labelText: 'Sector (optional)',
                        helperText: 'Assigned automatically at signup if set',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('-- assigned later / none --'),
                        ),
                        ...filteredSectors.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.businessUnitName != null
                                  ? '${s.name} (${s.businessUnitName})'
                                  : s.name,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => sectorId = v),
                    ),
                    const SizedBox(height: 12),

                    // Code
                    if (existing == null) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Auto-generate code'),
                        value: autoGenerate,
                        activeColor: _primary,
                        onChanged: (v) => setDialogState(() => autoGenerate = v),
                      ),
                      if (!autoGenerate)
                        TextFormField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Custom code *',
                            hintText: 'e.g. EEC-COLLECT-01',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (!autoGenerate && (v == null || v.trim().isEmpty)) {
                              return 'Enter a code';
                            }
                            return null;
                          },
                        ),
                    ] else
                      TextFormField(
                        controller: codeCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'e.g. For new Addis collectors',
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
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);

                        Map<String, dynamic> result;
                        if (existing == null) {
                          result = await AccessCodeService.create(
                            role: role,
                            code: autoGenerate ? null : codeCtrl.text.trim(),
                            sectorId: sectorId,
                            businessUnitId: businessUnitId,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          );
                        } else {
                          result = await AccessCodeService.update(
                            id: existing.id,
                            role: role,
                            sectorId: sectorId,
                            businessUnitId: businessUnitId,
                            note: noteCtrl.text.trim(),
                          );
                        }

                        setDialogState(() => saving = false);
                        if (result['success'] == true) {
                          Get.back();
                          final createdCode =
                              result['data']?['code']?.toString() ?? codeCtrl.text;
                          Get.snackbar(
                            'Success',
                            existing == null
                                ? 'Code created: $createdCode'
                                : 'Access code updated',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                          _loadAll();
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        existing == null ? 'Create' : 'Update',
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(AccessCode item) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Access Code'),
        content: Text('Delete code "${item.code}"?'),
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
    final result = await AccessCodeService.delete(item.id);
    if (result['success'] == true) {
      Get.snackbar('Deleted', item.code);
      _loadAll();
    } else {
      Get.snackbar('Error', result['message']?.toString() ?? 'Delete failed');
    }
  }

  Future<void> _deactivate(AccessCode item) async {
    final result = await AccessCodeService.deactivate(item.id);
    if (result['success'] == true) {
      Get.snackbar('Deactivated', item.code);
      _loadAll();
    } else {
      Get.snackbar('Error', result['message']?.toString() ?? 'Failed');
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    Get.snackbar('Copied', code, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
  }

  Color _statusColor(AccessCode a) {
    if (!a.isActive) return Colors.grey;
    if (a.isUsed) return Colors.blue;
    if (a.isExpired) return Colors.orange;
    return Colors.green;
  }

  String _statusLabel(AccessCode a) {
    if (!a.isActive) return 'Inactive';
    if (a.isUsed) return 'Used';
    if (a.isExpired) return 'Expired';
    return 'Available';
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Access Codes',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrEdit(),
        backgroundColor: _primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Code', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _filterRole,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Filter by role',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All roles')),
                      ..._roles.map(
                        (r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _filterRole = v);
                      _loadAll();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Unused only'),
                  selected: _unusedOnly,
                  selectedColor: _primary.withValues(alpha: 0.2),
                  checkmarkColor: _primary,
                  onSelected: (v) {
                    setState(() => _unusedOnly = v);
                    _loadAll();
                  },
                ),
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
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        color: _primary,
                        child: _items.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 100),
                                  Center(
                                    child: Text(
                                      'No access codes yet.\nTap + Create Code.',
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
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.code,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'monospace',
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 18),
                                            tooltip: 'Copy',
                                            onPressed: () => _copyCode(item.code),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(item.roleLabel),
                                          if (item.sectorName != null ||
                                              item.businessUnitName != null)
                                            Text(
                                              [
                                                if (item.businessUnitName != null)
                                                  item.businessUnitName!,
                                                if (item.sectorName != null) item.sectorName!,
                                              ].join(' › '),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          if (item.isUsed && item.usedByName != null)
                                            Text(
                                              'Used by: ${item.usedByName}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusColor(item).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _statusLabel(item),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _statusColor(item),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      isThreeLine: true,
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') {
                                            _showCreateOrEdit(existing: item);
                                          } else if (v == 'deactivate') {
                                            _deactivate(item);
                                          } else if (v == 'delete') {
                                            _confirmDelete(item);
                                          } else if (v == 'copy') {
                                            _copyCode(item.code);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'copy',
                                            child: Text('Copy code'),
                                          ),
                                          if (!item.isUsed)
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit'),
                                            ),
                                          if (item.isActive && !item.isUsed)
                                            const PopupMenuItem(
                                              value: 'deactivate',
                                              child: Text('Deactivate'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
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
}
