class ChatMessage {
  final int? id;
  final int? meetingId;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final String type; // text | voice
  final String content; // text body or voice file URL / local path
  final int? durationSeconds; // for voice messages
  final DateTime createdAt;
  final bool isMine;

  ChatMessage({
    this.id,
    this.meetingId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.type = 'text',
    required this.content,
    this.durationSeconds,
    required this.createdAt,
    this.isMine = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {int? currentUserId}) {
    final senderId = json['sender_id'] as int? ?? 0;
    return ChatMessage(
      id: json['id'] as int?,
      meetingId: json['meeting_id'] as int?,
      senderId: senderId,
      senderName: json['sender_name'] as String? ?? 'Unknown',
      senderAvatar: json['sender_avatar'] as String?,
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isMine: currentUserId != null && senderId == currentUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (meetingId != null) 'meeting_id': meetingId,
      'sender_id': senderId,
      'sender_name': senderName,
      if (senderAvatar != null) 'sender_avatar': senderAvatar,
      'type': type,
      'content': content,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
