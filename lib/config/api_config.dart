class ApiConfig {
  static const String baseUrl = 'http://localhost/eec_receivable_collection/api';

  static const String login = '$baseUrl/auth/login.php';
  static const String register = '$baseUrl/auth/register.php';
  static const String me = '$baseUrl/auth/me.php';
  static const String logout = '$baseUrl/auth/logout.php';

  static const String reports = '$baseUrl/reports';
  static const String summaryReports = '$baseUrl/summary_reports';

  static const String meetings = '$baseUrl/meetings';

  static const String messages = '$baseUrl/messages';

  static const String notifications = '$baseUrl/notifications';

  static const String businessUnits = '$baseUrl/business_units';
  static const String sectors = '$baseUrl/sectors';
  static const String projects = '$baseUrl/projects';
  static const String accessCodes = '$baseUrl/access_codes';

  static const String users = '$baseUrl/users';

  static const String collectionData = '$baseUrl/collection_data';
  static const String workflowReports = '$baseUrl/workflow_reports';

  static Map<String, String> headers({String? token}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }
}