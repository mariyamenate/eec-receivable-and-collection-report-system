import '../config/api_config.dart';
import '../models/business_unit.dart';
import '../models/sector.dart';
import '../models/project.dart';
import 'api_service.dart';
import 'auth_service.dart';

class OrganizationService {
  // ── Business Units ──

  static Future<List<BusinessUnit>> getBusinessUnits() async {
    final token = await AuthService.getToken();
    final result = await ApiService.get(
      '${ApiConfig.businessUnits}/index.php',
      token: token,
    );
    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .map((e) => BusinessUnit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createBusinessUnit({
    required String name,
    String? code,
    String? description,
  }) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.businessUnits}/store.php',
      token: token,
      body: {
        'name': name,
        if (code != null) 'code': code,
        if (description != null) 'description': description,
      },
    );
  }

  static Future<Map<String, dynamic>> updateBusinessUnit({
    required int id,
    required String name,
    String? code,
    String? description,
    bool? isActive,
  }) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.businessUnits}/update.php',
      token: token,
      body: {
        'id': id,
        'name': name,
        if (code != null) 'code': code,
        if (description != null) 'description': description,
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteBusinessUnit(int id) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.businessUnits}/delete.php',
      token: token,
      body: {'id': id},
    );
  }

  // ── Sectors ──

  static Future<List<Sector>> getSectors({int? businessUnitId}) async {
    final token = await AuthService.getToken();
    final query = businessUnitId != null
        ? {'business_unit_id': businessUnitId.toString()}
        : null;
    final result = await ApiService.get(
      '${ApiConfig.sectors}/index.php',
      token: token,
      queryParams: query,
    );
    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .map((e) => Sector.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createSector({
    required int businessUnitId,
    required String name,
    String? code,
    String? description,
  }) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.sectors}/store.php',
      token: token,
      body: {
        'business_unit_id': businessUnitId,
        'name': name,
        if (code != null) 'code': code,
        if (description != null) 'description': description,
      },
    );
  }

  static Future<Map<String, dynamic>> updateSector({
    required int id,
    required int businessUnitId,
    required String name,
    String? code,
    String? description,
    bool? isActive,
  }) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.sectors}/update.php',
      token: token,
      body: {
        'id': id,
        'business_unit_id': businessUnitId,
        'name': name,
        if (code != null) 'code': code,
        if (description != null) 'description': description,
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteSector(int id) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.sectors}/delete.php',
      token: token,
      body: {'id': id},
    );
  }

  // ── Projects ──

  static Future<List<Project>> getProjects({
    int? sectorId,
    int? businessUnitId,
  }) async {
    final token = await AuthService.getToken();
    final query = <String, String>{};
    if (sectorId != null) query['sector_id'] = sectorId.toString();
    if (businessUnitId != null) {
      query['business_unit_id'] = businessUnitId.toString();
    }
    final result = await ApiService.get(
      '${ApiConfig.projects}/index.php',
      token: token,
      queryParams: query.isEmpty ? null : query,
    );
    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Paginated projects scoped to the LOGGED-IN COLLECTOR's own Business
  /// Unit/Sector (as assigned by their super-admin-issued access code).
  /// The backend should still enforce the collector's real scope from the token.
  static Future<Map<String, dynamic>> getMyProjects({
    int page = 1,
    int perPage = 20,
    String? search,
    int? businessUnitId,
    int? sectorId,
  }) async {
    final token = await AuthService.getToken();
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }
    if (businessUnitId != null) {
      query['business_unit_id'] = businessUnitId.toString();
    }
    if (sectorId != null) {
      query['sector_id'] = sectorId.toString();
    }

    final result = await ApiService.get(
      '${ApiConfig.projects}/my_projects.php',
      token: token,
      queryParams: query,
    );

    if (result['success'] == true && result['data'] is List) {
      final projects = (result['data'] as List)
          .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return {
        'data': projects,
        'has_more': result['has_more'] as bool? ?? false,
        'total_pages': result['total_pages'] as int?,
      };
    }
    return {'data': <Project>[], 'has_more': false, 'total_pages': null};
  }

  static Future<Map<String, dynamic>> createProject({
    required int sectorId,
    required String name,
    String? code,
    String? description,
    String status = 'active',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.projects}/store.php',
      token: token,
      body: {
        'sector_id': sectorId,
        'name': name,
        if (code != null) 'code': code,
        if (description != null) 'description': description,
        'status': status,
        if (startDate != null)
          'start_date': startDate.toIso8601String().split('T').first,
        if (endDate != null)
          'end_date': endDate.toIso8601String().split('T').first,
      },
    );
  }

  static Future<Map<String, dynamic>> updateProject({
    required int id,
    required int sectorId,
    required String name,
    String? code,
    String? description,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.projects}/update.php',
      token: token,
      body: {
        'id': id,
        'sector_id': sectorId,
        'name': name,
        if (code != null) 'code': code,
        if (description != null) 'description': description,
        if (status != null) 'status': status,
        if (startDate != null)
          'start_date': startDate.toIso8601String().split('T').first,
        if (endDate != null)
          'end_date': endDate.toIso8601String().split('T').first,
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteProject(int id) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.projects}/delete.php',
      token: token,
      body: {'id': id},
    );
  }
}