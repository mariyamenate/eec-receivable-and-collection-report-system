import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_notification.dart';

class NotificationService {
  static const String baseUrl = 'https://your-api.example.com/api';
  static String? authToken;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  // ---------------------------------------------------------------------------
  // Real API
  // ---------------------------------------------------------------------------

  static Future<List<AppNotification>> getNotifications({
    int page = 1,
    int perPage = 30,
    bool? unreadOnly,
  }) async {
    final uri = Uri.parse('$baseUrl/notifications').replace(queryParameters: {
      'page': '$page',
      'per_page': '$perPage',
      if (unreadOnly == true) 'unread_only': '1',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (body['data'] as List? ?? []);
      return list
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load notifications: ${response.statusCode}');
  }

  /// Create a new notification (used when someone sends a chat message)
  static Future<void> create({
    required String title,
    required String body,
    String type = 'message',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'body': body,
        'type': type,
        'is_read': false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create notification: ${response.statusCode}');
    }
  }

  static Future<void> markAsRead(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to mark notification read: ${response.statusCode}');
    }
  }

  static Future<void> markAllAsRead() async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to mark all read: ${response.statusCode}');
    }
  }

  static Future<int> unreadCount() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['count'] as int? ?? 0;
    }
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Local fallback
  // ---------------------------------------------------------------------------
  static final List<AppNotification> _local = [
    AppNotification(
      id: 1,
      title: 'New meeting scheduled',
      body: 'Construction team sync is scheduled for tomorrow 10:00',
      type: 'meeting',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 2,
      title: 'Project update',
      body: 'Site inspection report uploaded for Project Alpha',
      type: 'project',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: 3,
      title: 'Collection submitted',
      body: 'Your data collection for Sector Construction was received',
      type: 'collection',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static Future<List<AppNotification>> getNotificationsLocal() async {
    await Future.delayed(const Duration(milliseconds: 250));
    // newest first
    final sorted = List<AppNotification>.from(_local)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Local version of create (used when backend is not ready)
  static Future<void> createLocal({
    required String title,
    required String body,
    String type = 'message',
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final newNotif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      type: type,
      isRead: false,
      createdAt: DateTime.now(),
    );
    _local.insert(0, newNotif); // add to top
  }

  static Future<void> markAsReadLocal(int id) async {
    final idx = _local.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _local[idx] = _local[idx].copyWith(isRead: true);
    }
  }

  static Future<void> markAllAsReadLocal() async {
    for (var i = 0; i < _local.length; i++) {
      _local[i] = _local[i].copyWith(isRead: true);
    }
  }
}