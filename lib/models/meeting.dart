import 'package:intl/intl.dart';

class Meeting {
  final int? id;
  final String title;
  final DateTime scheduledAt;
  final String jitsiRoom; // room name only, e.g. "construction-team-2026"
  final String status; // scheduled | live | ended | cancelled
  final String? notes;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Meeting({
    this.id,
    required this.title,
    required this.scheduledAt,
    required this.jitsiRoom,
    this.status = 'scheduled',
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  String get jitsiUrl => 'https://meet.jit.si/$jitsiRoom';

  String get formattedDate {
    return DateFormat('EEE, MMM d • HH:mm').format(scheduledAt);
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : DateTime.now(),
      jitsiRoom: json['jitsi_room'] as String? ?? '',
      status: json['status'] as String? ?? 'scheduled',
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'scheduled_at': scheduledAt.toIso8601String(),
      'jitsi_room': jitsiRoom,
      'status': status,
      if (notes != null) 'notes': notes,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  Meeting copyWith({
    int? id,
    String? title,
    DateTime? scheduledAt,
    String? jitsiRoom,
    String? status,
    String? notes,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      jitsiRoom: jitsiRoom ?? this.jitsiRoom,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
