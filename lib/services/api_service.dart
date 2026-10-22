import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<String?> _resolveToken(String? token) async {
    if (token != null && token.isNotEmpty) return token;
    return await AuthService.getToken();
  }

  static Future<Map<String, dynamic>> get(
      String url, {
        String? token,
        Map<String, String>? queryParams,
      }) async {
    try {
      var uri = Uri.parse(url);
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final resolvedToken = await _resolveToken(token);

      final response = await http
          .get(
        uri,
        headers: ApiConfig.headers(token: resolvedToken),
      )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': _friendlyError(e),
      };
    }
  }

  static Future<Map<String, dynamic>> post(
      String url, {
        String? token,
        Map<String, dynamic>? body,
      }) async {
    try {
      final resolvedToken = await _resolveToken(token);

      final response = await http
          .post(
        Uri.parse(url),
        headers: ApiConfig.headers(token: resolvedToken),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': _friendlyError(e),
      };
    }
  }

  static Future<Map<String, dynamic>> put(
      String url, {
        String? token,
        Map<String, dynamic>? body,
      }) async {
    try {
      final resolvedToken = await _resolveToken(token);

      final response = await http
          .put(
        Uri.parse(url),
        headers: ApiConfig.headers(token: resolvedToken),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': _friendlyError(e),
      };
    }
  }

  static Future<Map<String, dynamic>> delete(
      String url, {
        String? token,
      }) async {
    try {
      final resolvedToken = await _resolveToken(token);

      final response = await http
          .delete(
        Uri.parse(url),
        headers: ApiConfig.headers(token: resolvedToken),
      )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': _friendlyError(e),
      };
    }
  }

  static Future<Map<String, dynamic>> multipart(
      String url, {
        String? token,
        required Map<String, String> fields,
        required String fileField,
        required String filePath,
        String method = 'POST',
      }) async {
    try {
      final resolvedToken = await _resolveToken(token);
      if (resolvedToken == null) {
        return {'success': false, 'message': 'Unauthorized — missing token'};
      }

      final request = http.MultipartRequest(method, Uri.parse(url));
      request.headers.addAll({
        'Authorization': 'Bearer $resolvedToken',
        'Accept': 'application/json',
      });
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': _friendlyError(e),
      };
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (!data.containsKey('success')) {
          data['success'] =
              response.statusCode >= 200 && response.statusCode < 300;
        }
        return data;
      }
      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'data': data,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Invalid response from server (${response.statusCode})',
        'body': response.body,
      };
    }
  }

  static String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Server is not responding. Please check your internet connection or try again later.';
    }
    if (msg.contains('socket') || msg.contains('connection')) {
      return 'Cannot connect to server. Check your internet or server address.';
    }
    return e.toString();
  }
}