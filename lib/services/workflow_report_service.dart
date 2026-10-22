import 'dart:convert';

import '../config/api_config.dart';
import '../models/report_history_entry.dart';
import '../models/workflow_report.dart';
import 'api_service.dart';
import 'auth_service.dart';

class WorkflowReportService {
  // ---------------------------------------------------------------------------
  // List / detail
  // ---------------------------------------------------------------------------

  static Future<List<WorkflowReport>> getReports({
    String scope = 'mine',
    String? status,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return [];

    final query = <String, String>{'scope': scope};
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }

    final result = await ApiService.get(
      '${ApiConfig.workflowReports}/index.php',
      token: token,
      queryParams: query,
    );

    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .map(
            (item) => WorkflowReport.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList();
    }
    return [];
  }

  static Future<WorkflowReport?> getById(int id) async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final result = await ApiService.get(
      '${ApiConfig.workflowReports}/show.php?id=$id',
      token: token,
    );

    if (result['success'] == true && result['data'] != null) {
      return WorkflowReport.fromJson(
        Map<String, dynamic>.from(result['data']),
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // History / audit log
  // ---------------------------------------------------------------------------

  /// Report history — one row per action taken on a report (who did what,
  /// when, and which status it moved from/to). Backend endpoint:
  /// GET {workflowReports}/history.php
  ///
  /// Expected response shape:
  /// {
  ///   "success": true,
  ///   "data": [ { "id":1, "when":"...", "actor_name":"...", "role":"...",
  ///               "project_name":"...", "action":"...",
  ///               "from_status":"...", "to_status":"...", "remark":"..." }, ... ],
  ///   "total": 42
  /// }
  static Future<ReportHistoryPage> getHistory({
    String scope = 'mine',
    DateTime? dateFrom,
    DateTime? dateTo,
    String? projectQuery,
    int page = 1,
    int pageSize = 20,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return ReportHistoryPage.empty();

    final query = <String, String>{
      'scope': scope,
      'page': '$page',
      'page_size': '$pageSize',
    };
    if (dateFrom != null) {
      query['date_from'] = dateFrom.toIso8601String().split('T').first;
    }
    if (dateTo != null) {
      query['date_to'] = dateTo.toIso8601String().split('T').first;
    }
    if (projectQuery != null && projectQuery.trim().isNotEmpty) {
      query['project'] = projectQuery.trim();
    }

    final result = await ApiService.get(
      '${ApiConfig.workflowReports}/history.php',
      token: token,
      queryParams: query,
    );

    if (result['success'] == true && result['data'] is List) {
      final entries = (result['data'] as List)
          .map(
            (item) => ReportHistoryEntry.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList();
      final total = result['total'] is int
          ? result['total'] as int
          : (result['count'] is int ? result['count'] as int : entries.length);
      return ReportHistoryPage(entries: entries, total: total);
    }
    return ReportHistoryPage.empty();
  }

  /// Requests a CSV export of the history matching the given filters.
  /// Backend endpoint: GET {workflowReports}/export_history.php
  ///
  /// Expected response shape (pick whichever your backend implements):
  /// { "success": true, "data": "<raw csv text>" }
  /// or
  /// { "success": true, "data": { "url": "https://.../export_123.csv" } }
  static Future<Map<String, dynamic>> exportHistoryCsv({
    String scope = 'mine',
    DateTime? dateFrom,
    DateTime? dateTo,
    String? projectQuery,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    final query = <String, String>{'scope': scope};
    if (dateFrom != null) {
      query['date_from'] = dateFrom.toIso8601String().split('T').first;
    }
    if (dateTo != null) {
      query['date_to'] = dateTo.toIso8601String().split('T').first;
    }
    if (projectQuery != null && projectQuery.trim().isNotEmpty) {
      query['project'] = projectQuery.trim();
    }

    return ApiService.get(
      '${ApiConfig.workflowReports}/export_history.php',
      token: token,
      queryParams: query,
    );
  }

  // ---------------------------------------------------------------------------
  // Senior Accountant — File 1
  // ---------------------------------------------------------------------------

  /// Generates a template file from collector data (does not create a new collection row).
  static Future<Map<String, dynamic>> generateCollectionTemplate({
    required String title,
    required List<int> collectionDataIds,
    required Map<String, dynamic> templateData,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    return ApiService.post(
      '${ApiConfig.workflowReports}/generate_collection_template.php',
      token: token,
      body: {
        'title': title,
        'collection_data_ids': collectionDataIds,
        'template_data': templateData,
      },
    );
  }

  /// Creates a workflow report and sends File 1 (Receivables Template) to Team Leader.
  /// Status on success: sent_to_team_leader
  static Future<Map<String, dynamic>> createAndSendToTeamLeader({
    required String title,
    required int projectId,
    int? sectorId,
    int? businessUnitId,
    String? periodLabel,
    DateTime? periodFrom,
    DateTime? periodTo,
    required List<int> collectionDataIds,
    required Map<String, dynamic> templateData,
    String? templateFilePath,
    String? notes,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    final body = <String, dynamic>{
      'title': title,
      'project_id': projectId,
      if (sectorId != null) 'sector_id': sectorId,
      if (businessUnitId != null) 'business_unit_id': businessUnitId,
      if (periodLabel != null && periodLabel.trim().isNotEmpty)
        'period_label': periodLabel.trim(),
      if (periodFrom != null)
        'period_from': periodFrom.toIso8601String().split('T').first,
      if (periodTo != null)
        'period_to': periodTo.toIso8601String().split('T').first,
      'collection_data_ids': collectionDataIds,
      'template_data': templateData,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    if (templateFilePath != null && templateFilePath.trim().isNotEmpty) {
      return ApiService.multipart(
        '${ApiConfig.workflowReports}/create_and_send.php',
        token: token,
        fields: {
          'title': title,
          'project_id': projectId.toString(),
          if (sectorId != null) 'sector_id': sectorId.toString(),
          if (businessUnitId != null)
            'business_unit_id': businessUnitId.toString(),
          if (periodLabel != null && periodLabel.trim().isNotEmpty)
            'period_label': periodLabel.trim(),
          if (periodFrom != null)
            'period_from': periodFrom.toIso8601String().split('T').first,
          if (periodTo != null)
            'period_to': periodTo.toIso8601String().split('T').first,
          'collection_data_ids': collectionDataIds.join(','),
          'template_data': jsonEncode(templateData),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
        fileField: 'template_file',
        filePath: templateFilePath,
      );
    }

    return ApiService.post(
      '${ApiConfig.workflowReports}/create_and_send.php',
      token: token,
      body: body,
    );
  }

  /// Save Senior Accountant project-level lines (draft).
  static Future<Map<String, dynamic>> saveProjectLines({
    required int collectionId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    return ApiService.post(
      '${ApiConfig.collectionData}/save_lines.php',
      token: token,
      body: {
        'collection_id': collectionId,
        'lines': lines,
      },
    );
  }

  /// Reject one or more collector submissions (SA → Collector).
  static Future<Map<String, dynamic>> rejectToCollector({
    required List<int> collectionIds,
    required String remark,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    return ApiService.post(
      '${ApiConfig.collectionData}/reject.php',
      token: token,
      body: {
        'collection_ids': collectionIds,
        'remark': remark.trim(),
      },
    );
  }

  /// Reject a single collection (optional helper).
  static Future<Map<String, dynamic>> rejectCollection({
    required int collectionId,
    required String remark,
  }) async {
    return rejectToCollector(
      collectionIds: [collectionId],
      remark: remark,
    );
  }

  // ---------------------------------------------------------------------------
  // Team Leader — File 2 + forward
  // ---------------------------------------------------------------------------

  /// Team Leader: action = 'approved' | 'rejected'
  static Future<Map<String, dynamic>> teamLeaderAction({
    required int workflowReportId,
    required String action,
    String? remark,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    return ApiService.post(
      '${ApiConfig.workflowReports}/team_leader_action.php',
      token: token,
      body: {
        'workflow_report_id': workflowReportId,
        'action': action,
        if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
      },
    );
  }

  /// Team Leader sends File 1 + File 2 → Management + Finance Director.
  /// Status on success: sent_to_management
  ///
  /// Optional [summaryFilePath] uploads the 4-Sectors Collection Summary (File 2).
  static Future<Map<String, dynamic>> sendToManagementAndFinance({
    required int workflowReportId,
    String? summaryFilePath,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    if (summaryFilePath != null && summaryFilePath.trim().isNotEmpty) {
      return ApiService.multipart(
        '${ApiConfig.workflowReports}/send_to_management_and_finance.php',
        token: token,
        fields: {
          'workflow_report_id': workflowReportId.toString(),
        },
        fileField: 'summary_file',
        filePath: summaryFilePath,
      );
    }

    return ApiService.post(
      '${ApiConfig.workflowReports}/send_to_management_and_finance.php',
      token: token,
      body: {'workflow_report_id': workflowReportId},
    );
  }

  // ---------------------------------------------------------------------------
  // Management → Top Management
  // ---------------------------------------------------------------------------

  /// Management: action = 'approved' | 'rejected'
  static Future<Map<String, dynamic>> managementAction({
    required int workflowReportId,
    required String action,
    String? remark,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    return ApiService.post(
      '${ApiConfig.workflowReports}/management_action.php',
      token: token,
      body: {
        'workflow_report_id': workflowReportId,
        'action': action,
        if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
      },
    );
  }

  /// Management sends approved report to Top Management.
  /// Status on success: sent_to_top_management
  static Future<Map<String, dynamic>> sendToTopManagement({
    required int workflowReportId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Not authenticated. Please log in again.',
      };
    }

    return ApiService.post(
      '${ApiConfig.workflowReports}/send_to_top_management.php',
      token: token,
      body: {'workflow_report_id': workflowReportId},
    );
  }
}