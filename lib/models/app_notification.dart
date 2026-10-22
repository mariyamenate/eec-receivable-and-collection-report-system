class AppNotification {
  final int? id;
  final String title;
  final String body;
  final String type; // meeting | project | system | collection
  final bool isRead;
  final Map<String, dynamic>? data; // extra payload (meeting_id, project_id …)
  final DateTime createdAt;

  AppNotification({
    this.id,
    required this.title,
    required this.body,
    this.type = 'system',
    this.isRead = false,
    this.data,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      isRead: json['is_read'] as bool? ?? false,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'body': body,
      'type': type,
      'is_read': isRead,
      if (data != null) 'data': data,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      data: data,
      createdAt: createdAt,
    );
  }
}
