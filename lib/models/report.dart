class Report {
  final int id;
  final int userId;
  final String title;
  final String? description;
  final String status; // draft | submitted | approved | rejected
  final String? fileUrl;
  final String? period; // e.g. 2026-08
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? submittedByName;

  Report({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.status,
    this.fileUrl,
    this.period,
    this.createdAt,
    this.updatedAt,
    this.submittedByName,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      fileUrl: json['file_url']?.toString(),
      period: json['period']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      submittedByName: json['submitted_by_name']?.toString() ?? json['user_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'status': status,
      'file_url': fileUrl,
      'period': period,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
