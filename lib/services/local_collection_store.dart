import 'package:flutter/foundation.dart'; // ← this line is required for debugPrint
import '../models/collection_data.dart';

/// Shared in-memory store so Collector → Senior Accountant works
/// without depending on the backend.
class LocalCollectionStore {
  static final List<CollectionData> _items = [];

  static List<CollectionData> get items => List.unmodifiable(_items);

  static void add(CollectionData item) {
    // Prevent duplicates
    _items.removeWhere((e) => e.id == item.id);
    _items.insert(0, item);
    debugPrint('>>> LocalCollectionStore ADD id=${item.id} status=${item.status} total=${_items.length}');
  }

  static List<CollectionData> getIncoming({String? status}) {
    if (status == null || status.isEmpty) {
      return List.from(_items);
    }
    final filtered = _items.where((e) => e.status == status).toList();
    debugPrint('>>> LocalCollectionStore getIncoming status=$status → ${filtered.length} items');
    return filtered;
  }

  static void updateStatus(int id, String newStatus) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1) {
      final old = _items[index];
      _items[index] = CollectionData(
        id: old.id,
        collectorId: old.collectorId,
        projectId: old.projectId,
        sectorId: old.sectorId,
        businessUnitId: old.businessUnitId,
        period: old.period,
        periodFrom: old.periodFrom,
        periodTo: old.periodTo,
        status: newStatus,
        rows: old.rows,
        projectName: old.projectName,
        sectorName: old.sectorName,
        createdAt: old.createdAt,
        submittedAt: old.submittedAt,
      );
    }
  }

  static void clear() => _items.clear();
}