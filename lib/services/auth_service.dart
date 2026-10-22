import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// Login with email or username + password.
  static Future<Map<String, dynamic>> login(String emailOrUsername, String password) async {
    final result = await ApiService.post(
      ApiConfig.login,
      body: {
        'email': emailOrUsername.trim(),
        'username': emailOrUsername.trim(),
        'password': password,
      },
    );

    if (result['success'] == true && result['data'] != null) {
      final userData = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'])
          : Map<String, dynamic>.from(result);

      if (result['token'] != null && userData['token'] == null) {
        userData['token'] = result['token'];
      }

      final user = User.fromJson(userData);
      await _saveSession(user);
      return {'success': true, 'user': user};
    }

    return {
      'success': false,
      'message': result['message']?.toString() ?? 'Login failed',
    };
  }

  /// Register with access code from administrator.
  /// Role and sector are usually assigned by the access code on the backend.
  static Future<Map<String, dynamic>> register({
    required String accessCode,
    required String fullName,
    String? email,
    required String username,
    String? phone,
    String? sector,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'access_code': accessCode.trim(),
      'full_name': fullName.trim(),
      'name': fullName.trim(),
      'username': username.trim(),
      'password': password,
    };
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (sector != null && sector.isNotEmpty) body['sector'] = sector;

    final result = await ApiService.post(ApiConfig.register, body: body);

    if (result['success'] == true) {
      return {
        'success': true,
        'message': result['message']?.toString() ?? 'Account created',
      };
    }

    return {
      'success': false,
      'message': result['message']?.toString() ?? 'Registration failed',
    };
  }

  /// Fetch current user from /me endpoint (validates token).
  static Future<User?> me() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    final result = await ApiService.get(ApiConfig.me, token: token);

    if (result['success'] == true && result['data'] != null) {
      final userData = Map<String, dynamic>.from(result['data']);
      userData['token'] = token;
      final user = User.fromJson(userData);
      await _saveSession(user);
      return user;
    }

    await logout();
    return null;
  }

  static Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      await ApiService.post(ApiConfig.logout, token: token);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      final map = _decodeUser(raw);
      return User.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user.token != null) {
      await prefs.setString(_tokenKey, user.token!);
    }
    await prefs.setString(_userKey, _encodeUser(user));
  }

  static String _encodeUser(User u) {
    return [
      u.id,
      u.name,
      u.email,
      u.role,
      u.phone ?? '',
      u.avatar ?? '',
      u.token ?? '',
    ].join('||');
  }

  static Map<String, dynamic> _decodeUser(String raw) {
    final parts = raw.split('||');
    return {
      'id': int.tryParse(parts.elementAt(0)) ?? 0,
      'name': parts.elementAt(1),
      'email': parts.elementAt(2),
      'role': parts.elementAt(3),
      'phone': parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
      'avatar': parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
      'token': parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null,
    };
  }
}
