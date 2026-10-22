import '../config/api_config.dart';
import '../models/report.dart';
import '../models/summary_report.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ReportService {
  static Future<List<Report>> getReports({String? status, String? period}) async {
    final token = await AuthService.getToken();
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (period != null) query['period'] = period;

    final result = await ApiService.get(
      '${ApiConfig.reports}/index.php',
      token: token,
      queryParams: query.isEmpty ? null : query,
    );

    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .map((e) => Report.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<Report?> getReport(int id) async {
    final token = await AuthService.getToken();
    final result = await ApiService.get(
      '${ApiConfig.reports}/show.php?id=$id',
      token: token,
    );

    if (result['success'] == true && result['data'] != null) {
      return Report.fromJson(Map<String, dynamic>.from(result['data']));
    }
    return null;
  }

  static Future<Map<String, dynamic>> submitReport({
    required String title,
    String? description,
    String? period,
    String? filePath,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return {'success': false, 'message': 'Not authenticated'};

    if (filePath != null && filePath.isNotEmpty) {
      return ApiService.multipart(
        '${ApiConfig.reports}/store.php',
        token: token,
        fields: {
          'title': title,
          if (description != null) 'description': description,
          if (period != null) 'period': period,
        },
        fileField: 'file',
        filePath: filePath,
      );
    }

    return ApiService.post(
      '${ApiConfig.reports}/store.php',
      token: token,
      body: {
        'title': title,
        'description': description,
        'period': period,
      },
    );
  }

  static Future<Map<String, dynamic>> updateStatus(int id, String status) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.reports}/update_status.php',
      token: token,
      body: {'id': id, 'status': status},
    );
  }

  // ── Summary reports ──
  static Future<List<SummaryReport>> getSummaryReports({String? period}) async {
    final token = await AuthService.getToken();
    final query = period != null ? {'period': period} : null;

    final result = await ApiService.get(
      '${ApiConfig.summaryReports}/index.php',
      token: token,
      queryParams: query,
    );

    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .map((e) => SummaryReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createSummaryReport({
    required String title,
    String? content,
    String? period,
    String? filePath,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return {'success': false, 'message': 'Not authenticated'};

    if (filePath != null && filePath.isNotEmpty) {
      return ApiService.multipart(
        '${ApiConfig.summaryReports}/store.php',
        token: token,
        fields: {
          'title': title,
          if (content != null) 'content': content,
          if (period != null) 'period': period,
        },
        fileField: 'file',
        filePath: filePath,
      );
    }

    return ApiService.post(
      '${ApiConfig.summaryReports}/store.php',
      token: token,
      body: {
        'title': title,
        'content': content,
        'period': period,
      },
    );
  }
}
