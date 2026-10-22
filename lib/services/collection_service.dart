import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/collection_data.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'local_collection_store.dart';

class CollectionService {
  /// Backend is live — local fallback is OFF.
  /// Only flip this to true temporarily for offline UI testing.
  static const bool useLocalFallback = false;

  static Future<List<CollectionData>> getMyCollections({
    String? status,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    final query = <String, String>{'mine': '1'};
    if (status != null && status.isNotEmpty) query['status'] = status;

    final result = await ApiService.get(
      '${ApiConfig.collectionData}/index.php',
      token: token,
      queryParams: query,
    );

    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .map((item) => CollectionData.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return [];
  }

  /// Senior Accountant – incoming collector submissions
  static Future<List<CollectionData>> getIncoming({
    String? status,
  }) async {
    // ========== LOCAL FALLBACK ==========
    if (useLocalFallback) {
      await Future.delayed(const Duration(milliseconds: 150));
      final list = LocalCollectionStore.getIncoming(status: status);
      debugPrint('>>> LOCAL getIncoming  filter=$status  count=${list.length}');
      return list;
    }
    // ========== END LOCAL ==========

    final token = await AuthService.getToken();
    if (token == null) {
      debugPrint('[CollectionService] getIncoming: no token');
      return [];
    }

    final query = <String, String>{'incoming': '1'};
    if (status != null && status.isNotEmpty) query['status'] = status;

    final result = await ApiService.get(
      '${ApiConfig.collectionData}/index.php',
      token: token,
      queryParams: query,
    );

    debugPrint('[CollectionService] getIncoming query=$query');
    debugPrint('[CollectionService] getIncoming response=$result');

    if (result['success'] == true && result['data'] is List) {
      final list = (result['data'] as List)
          .map((item) => CollectionData.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      debugPrint('[CollectionService] parsed ${list.length} items');
      return list;
    }

    return [];
  }

  static Future<CollectionData?> getById(int id) async {
    if (useLocalFallback) {
      try {
        return LocalCollectionStore.items.firstWhere((e) => e.id == id);
      } catch (_) {
        return null;
      }
    }

    final token = await AuthService.getToken();
    if (token == null) return null;

    final result = await ApiService.get(
      '${ApiConfig.collectionData}/show.php?id=$id',
      token: token,
    );

    if (result['success'] == true && result['data'] != null) {
      return CollectionData.fromJson(Map<String, dynamic>.from(result['data']));
    }
    return null;
  }

  /// Collector submits one detailed collection record
  static Future<Map<String, dynamic>> submit({
    int? id, // ← added for update support
    required int projectId,
    int? sectorId,
    int? businessUnitId,
    DateTime? periodFrom,
    DateTime? periodTo,
    required Map<String, dynamic> tableData,
    String? filePath,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    // ========== LOCAL FALLBACK ==========
    if (useLocalFallback) {
      final newId = id ?? DateTime.now().millisecondsSinceEpoch;

      final item = CollectionData(
        id: newId,
        collectorId: 0,
        projectId: projectId,
        sectorId: sectorId,
        businessUnitId: businessUnitId,
        period: '',
        periodFrom: periodFrom,
        periodTo: periodTo,
        status: 'submitted',
        rows: tableData,
        projectName: tableData['client_project']?['project_title']?.toString() ??
            'Project #$projectId',
        sectorName: tableData['sector_name']?.toString() ?? 'Construction',
        createdAt: DateTime.now(),
        submittedAt: DateTime.now(),
      );

      if (id != null) {
        // update existing in local store
        final index = LocalCollectionStore.items.indexWhere((e) => e.id == id);
        if (index != -1) {
          LocalCollectionStore.items[index] = item;
        } else {
          LocalCollectionStore.add(item);
        }
      } else {
        LocalCollectionStore.add(item);
      }

      debugPrint(
          '>>> LOCAL SUBMIT SUCCESS  id=$newId  total=${LocalCollectionStore.items.length}');

      return {
        'success': true,
        'message': 'Submitted successfully (local)',
        'data': item.toJson(),
      };
    }
    // ========== END LOCAL ==========

    final body = <String, dynamic>{
      if (id != null) 'id': id, // ← added
      'project_id': projectId,
      if (sectorId != null) 'sector_id': sectorId,
      if (businessUnitId != null) 'business_unit_id': businessUnitId,
      if (periodFrom != null)
        'period_from': periodFrom.toIso8601String().split('T').first,
      if (periodTo != null)
        'period_to': periodTo.toIso8601String().split('T').first,
      'status': 'submitted',
      'table_data': tableData,
    };

    if (filePath != null && filePath.trim().isNotEmpty) {
      return ApiService.multipart(
        '${ApiConfig.collectionData}/store.php',
        token: token,
        fields: {
          if (id != null) 'id': id.toString(), // ← added
          'project_id': projectId.toString(),
          'status': 'submitted',
          if (sectorId != null) 'sector_id': sectorId.toString(),
          if (businessUnitId != null)
            'business_unit_id': businessUnitId.toString(),
          if (periodFrom != null)
            'period_from': periodFrom.toIso8601String().split('T').first,
          if (periodTo != null)
            'period_to': periodTo.toIso8601String().split('T').first,
          'table_data': jsonEncode(tableData),
        },
        fileField: 'file',
        filePath: filePath,
      );
    }

    final result = await ApiService.post(
      '${ApiConfig.collectionData}/store.php',
      token: token,
      body: body,
    );

    debugPrint('[CollectionService] submit response=$result');
    return result;
  }

  static Future<Map<String, dynamic>> saveDraft({
    int? id, // ← added for update support
    required int projectId,
    int? sectorId,
    int? businessUnitId,
    DateTime? periodFrom,
    DateTime? periodTo,
    required Map<String, dynamic> tableData,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    return ApiService.post(
      '${ApiConfig.collectionData}/store.php',
      token: token,
      body: {
        if (id != null) 'id': id, // ← added
        'project_id': projectId,
        if (sectorId != null) 'sector_id': sectorId,
        if (businessUnitId != null) 'business_unit_id': businessUnitId,
        if (periodFrom != null)
          'period_from': periodFrom.toIso8601String().split('T').first,
        if (periodTo != null)
          'period_to': periodTo.toIso8601String().split('T').first,
        'status': 'draft',
        'table_data': tableData,
      },
    );
  }

  static Future<Map<String, dynamic>> generateTemplate({
    required Map<String, dynamic> data,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    return ApiService.post(
      '${ApiConfig.workflowReports}/generate_template.php',
      token: token,
      body: {'data': data},
    );
  }

  /// Shared helper for status-only transitions (approve / reject) on an
  /// existing collection record. Posts to the same store.php endpoint
  /// already used by submit()/saveDraft(), passing just the id + new
  /// status (+ optional remark) rather than the full table_data.
  ///
  /// NOTE: confirm with your backend that store.php accepts a partial
  /// update like this (id + status [+ remark], no table_data). If it
  /// requires table_data on every call, or if there's a dedicated
  /// endpoint (e.g. review.php) for approve/reject, point this at that
  /// instead.
  static Future<Map<String, dynamic>> _updateStatus({
    required int id,
    required String status,
    String? remark,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    if (useLocalFallback) {
      final index = LocalCollectionStore.items.indexWhere((e) => e.id == id);
      if (index == -1) {
        return {'success': false, 'message': 'Item not found (local)'};
      }
      final existingJson = LocalCollectionStore.items[index].toJson();
      existingJson['status'] = status;
      if (remark != null) existingJson['remark'] = remark;
      LocalCollectionStore.items[index] =
          CollectionData.fromJson(Map<String, dynamic>.from(existingJson));
      debugPrint('>>> LOCAL updateStatus id=$id -> $status remark=$remark');
      return {'success': true, 'message': 'Updated (local)'};
    }

    final result = await ApiService.post(
      '${ApiConfig.collectionData}/store.php',
      token: token,
      body: {
        'id': id,
        'status': status,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      },
    );

    debugPrint('[CollectionService] _updateStatus id=$id status=$status response=$result');
    return result;
  }

  /// Senior Accountant approves a submitted report and forwards it to the
  /// Team Leader.
  static Future<Map<String, dynamic>> approve({required int id}) {
    return _updateStatus(id: id, status: 'sent_to_team_leader');
  }

  /// Senior Accountant rejects a submitted report back to the Collector,
  /// attaching a required remark explaining why.
  static Future<Map<String, dynamic>> reject({
    required int id,
    required String remark,
  }) {
    return _updateStatus(
      id: id,
      status: 'rejected_by_senior_accountant',
      remark: remark,
    );
  }

  static Future<Map<String, dynamic>> saveOrUpdate({
    required List<int> collectionIds,
    required String title,
    required Map<String, dynamic> payload,
    String? filePath,
    required bool submit,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    final path = '${ApiConfig.collectionData}/save_or_update.php';

    if (filePath != null && filePath.trim().isNotEmpty) {
      return ApiService.multipart(
        path,
        token: token,
        fields: {
          'collection_ids': collectionIds.join(','),
          'title': title,
          'payload': jsonEncode(payload),
          'submit': submit ? '1' : '0',
        },
        fileField: 'file',
        filePath: filePath,
      );
    }

    return ApiService.post(
      path,
      token: token,
      body: {
        'collection_ids': collectionIds,
        'title': title,
        'payload': payload,
        'submit': submit,
      },
    );
  }
}