import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'notifications_service.dart';

class ChatService {
  static const String baseUrl = 'https://your-api.example.com/api';
  static String? authToken;
  static int? currentUserId;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  // ---------------------------------------------------------------------------
  // Real API
  // ---------------------------------------------------------------------------

  static Future<List<ChatMessage>> getMessages({
    int? meetingId,
    int page = 1,
    int perPage = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/messages').replace(queryParameters: {
      'page': '$page',
      'per_page': '$perPage',
      if (meetingId != null) 'meeting_id': '$meetingId',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (body['data'] as List? ?? []);
      return list
          .map((e) => ChatMessage.fromJson(
        e as Map<String, dynamic>,
        currentUserId: currentUserId,
      ))
          .toList();
    }
    throw Exception('Failed to load messages: ${response.statusCode}');
  }

  static Future<ChatMessage> sendText({
    required String content,
    int? meetingId,
    required int senderId,
    required String senderName,
    int? recipientId, // null = everyone, value = only this user
  }) async {
    final payload = {
      'type': 'text',
      'content': content,
      if (meetingId != null) 'meeting_id': meetingId,
      'sender_id': senderId,
      'sender_name': senderName,
      if (recipientId != null) 'recipient_id': recipientId,
      'is_direct': recipientId != null,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/chat/messages'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = ChatMessage.fromJson(
        body['data'] as Map<String, dynamic>? ?? body,
        currentUserId: currentUserId,
      );

      await _createMessageNotification(
        senderName: senderName,
        content: content,
        recipientId: recipientId,
      );

      return message;
    }
    throw Exception('Failed to send message: ${response.statusCode}');
  }

  static Future<ChatMessage> sendVoice({
    required String localFilePath,
    required int durationSeconds,
    int? meetingId,
    required int senderId,
    required String senderName,
    int? recipientId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/chat/messages'),
    );
    request.headers.addAll(_headers);
    request.fields['type'] = 'voice';
    request.fields['duration_seconds'] = '$durationSeconds';
    if (meetingId != null) request.fields['meeting_id'] = '$meetingId';
    request.fields['sender_id'] = '$senderId';
    request.fields['sender_name'] = senderName;
    if (recipientId != null) request.fields['recipient_id'] = '$recipientId';
    request.fields['is_direct'] = recipientId != null ? 'true' : 'false';
    request.files.add(await http.MultipartFile.fromPath('audio', localFilePath));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = ChatMessage.fromJson(
        body['data'] as Map<String, dynamic>? ?? body,
        currentUserId: currentUserId,
      );

      await _createMessageNotification(
        senderName: senderName,
        content: '🎤 Voice message (${durationSeconds}s)',
        recipientId: recipientId,
      );

      return message;
    }
    throw Exception('Failed to send voice: ${response.statusCode}');
  }

  // ---------------------------------------------------------------------------
  // Helper – creates notification
  // ---------------------------------------------------------------------------
  static Future<void> _createMessageNotification({
    required String senderName,
    required String content,
    int? recipientId,
  }) async {
    final shortBody =
    content.length > 90 ? '${content.substring(0, 90)}...' : content;

    try {
      await NotificationService.create(
        title: 'New message from $senderName',
        body: shortBody,
        type: 'message',
        // Optional: if your backend supports recipient
        // recipientId: recipientId,
      );
    } catch (e) {
      debugPrint('API notification failed, using local: $e');
      try {
        await NotificationService.createLocal(
          title: 'New message from $senderName',
          body: shortBody,
          type: 'message',
        );
      } catch (e2) {
        debugPrint('Local notification also failed: $e2');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Local fallback
  // ---------------------------------------------------------------------------
  static final List<ChatMessage> _localMessages = [];

  static Future<List<ChatMessage>> getMessagesLocal({int? meetingId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (meetingId == null) return List.from(_localMessages);
    return _localMessages.where((m) => m.meetingId == meetingId).toList();
  }

  static Future<ChatMessage> sendTextLocal({
    required String content,
    int? meetingId,
    required int senderId,
    required String senderName,
    int? recipientId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      meetingId: meetingId,
      senderId: senderId,
      senderName: senderName,
      type: 'text',
      content: content,
      createdAt: DateTime.now(),
      isMine: true,
    );
    _localMessages.add(msg);

    await _createMessageNotification(
      senderName: senderName,
      content: content,
      recipientId: recipientId,
    );

    return msg;
  }

  static Future<ChatMessage> sendVoiceLocal({
    required String localFilePath,
    required int durationSeconds,
    int? meetingId,
    required int senderId,
    required String senderName,
    int? recipientId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      meetingId: meetingId,
      senderId: senderId,
      senderName: senderName,
      type: 'voice',
      content: localFilePath,
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
      isMine: true,
    );
    _localMessages.add(msg);

    await _createMessageNotification(
      senderName: senderName,
      content: '🎤 Voice message (${durationSeconds}s)',
      recipientId: recipientId,
    );

    return msg;
  }
}