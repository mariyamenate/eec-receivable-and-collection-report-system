import '../config/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

class AccountService {
  /// Updates the logged-in user's OWN username and/or password.
  /// Leave [newUsername] or [newPassword] null/empty to leave that field
  /// unchanged. [currentPassword] is always required, as a safety check
  /// server-side before allowing either change.
  ///
  /// TODO: this assumes an ApiConfig constant named `users` (mirroring
  /// `businessUnits`, `sectors`, `projects` in OrganizationService) pointing
  /// at your users API folder, and a `update_credentials.php` endpoint
  /// under it. Adjust the path below to match your actual ApiConfig/API
  /// layout if different.
  static Future<Map<String, dynamic>> updateCredentials({
    required String currentPassword,
    String? newUsername,
    String? newPassword,
  }) async {
    final token = await AuthService.getToken();
    return ApiService.post(
      '${ApiConfig.users}/update_credentials.php',
      token: token,
      body: {
        'current_password': currentPassword,
        if (newUsername != null && newUsername.trim().isNotEmpty)
          'username': newUsername.trim(),
        if (newPassword != null && newPassword.isNotEmpty)
          'new_password': newPassword,
      },
    );
  }
}