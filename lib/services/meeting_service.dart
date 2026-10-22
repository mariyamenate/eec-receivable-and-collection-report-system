import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/meeting.dart';

/// REST-style service matching your CollectionService / OrganizationService pattern.
/// Point [baseUrl] at your real backend when ready.
class MeetingService {
  // TODO: replace with your real API base + auth token helper
  static const String baseUrl = 'https://your-api.example.com/api';
  static String? authToken; // set this after login

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  /// List meetings for the current user (scoped by auth token on backend)
  static Future<List<Meeting>> getMeetings({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/meetings').replace(queryParameters: {
      'page': '$page',
      'per_page': '$perPage',
      if (status != null) 'status': status,
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (body['data'] as List? ?? []);
      return list.map((e) => Meeting.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load meetings: ${response.statusCode} ${response.body}');
  }

  static Future<Meeting> getMeeting(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/meetings/$id'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Meeting.fromJson(body['data'] as Map<String, dynamic>? ?? body);
    }
    throw Exception('Failed to load meeting: ${response.statusCode}');
  }

  static Future<Meeting> createMeeting(Meeting meeting) async {
    final response = await http.post(
      Uri.parse('$baseUrl/meetings'),
      headers: _headers,
      body: jsonEncode(meeting.toJson()),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Meeting.fromJson(body['data'] as Map<String, dynamic>? ?? body);
    }
    throw Exception('Failed to create meeting: ${response.statusCode} ${response.body}');
  }

  static Future<Meeting> updateMeeting(Meeting meeting) async {
    if (meeting.id == null) throw ArgumentError('Meeting id is required for update');
    final response = await http.put(
      Uri.parse('$baseUrl/meetings/${meeting.id}'),
      headers: _headers,
      body: jsonEncode(meeting.toJson()),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Meeting.fromJson(body['data'] as Map<String, dynamic>? ?? body);
    }
    throw Exception('Failed to update meeting: ${response.statusCode}');
  }

  static Future<Meeting> markLive(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/meetings/$id/mark-live'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Meeting.fromJson(body['data'] as Map<String, dynamic>? ?? body);
    }
    throw Exception('Failed to mark meeting live: ${response.statusCode}');
  }

  // ---------------------------------------------------------------------------
  // Local / offline helpers (useful while backend is not ready)
  // ---------------------------------------------------------------------------
  static final List<Meeting> _localMeetings = [];

  static Future<List<Meeting>> getMeetingsLocal() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_localMeetings);
  }

  static Future<Meeting> createMeetingLocal(Meeting meeting) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final created = meeting.copyWith(
      id: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now(),
    );
    _localMeetings.insert(0, created);
    return created;
  }

  static Future<Meeting> updateMeetingLocal(Meeting meeting) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _localMeetings.indexWhere((m) => m.id == meeting.id);
    if (idx >= 0) {
      _localMeetings[idx] = meeting;
    }
    return meeting;
  }
}
