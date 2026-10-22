import 'dart:math';
import '../config/api_config.dart';
import '../models/access_code.dart';
import 'api_service.dart';
import 'auth_service.dart';

class AccessCodeService {
  static Future<List<AccessCode>> getAll({String? role, bool? unusedOnly}) async {
    final token = await AuthService.getToken();
    final query = <String, String>{};
    if (role != null) query['role'] = role;
    if (unusedOnly == true) query['unused'] = '1';

    final result = await ApiService.get(
      '${ApiConfig.accessCodes}/index.php',
      token: token,
      queryParams: query.isEmpty ? null : query,
    );

    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .map((e) => AccessCode.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> create({
    required String role,
    String? code,
    int? sectorId,
    int? businessUnitId,
    DateTime? expiresAt,
    String? note,
  }) async {
    final token = await AuthService.getToken();
    final generated = code?.trim().isNotEmpty == true
        ? code!.trim().toUpperCase()
        : _generateCode();

    return ApiService.post(
      '${ApiConfig.accessCodes}/store.php',
      token: token,
      body: {
        'code': generated,
        'role': role,
        if (sectorId != null) 'sector_id': sectorId,
        if (businessUnitId != null) 'business_unit_id': businessUnitId,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  static Future<Map<String, dynamic>> update({
    required int id,
    required String role,
    int? sectorId,
    int? businessUnitId,
    DateTime? expiresAt,
    bool? isActive,
    String? note,
  }) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.accessCodes}/update.php',
      token: token,
      body: {
        'id': id,
        'role': role,
        'sector_id': sectorId,
        'business_unit_id': businessUnitId,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        if (isActive != null) 'is_active': isActive,
        if (note != null) 'note': note,
      },
    );
  }

  static Future<Map<String, dynamic>> delete(int id) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.accessCodes}/delete.php',
      token: token,
      body: {'id': id},
    );
  }

  static Future<Map<String, dynamic>> deactivate(int id) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.accessCodes}/deactivate.php',
      token: token,
      body: {'id': id},
    );
  }

  /// Generate a readable access code like EEC-A7K2M9
  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    final part = List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
    return 'EEC-$part';
  }
}
