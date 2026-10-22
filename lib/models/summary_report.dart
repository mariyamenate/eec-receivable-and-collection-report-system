class SummaryReport {
  final int id;
  final int preparedBy;
  final String title;
  final String? content;
  final String status;
  final String? period;
  final String? fileUrl;
  final DateTime? createdAt;
  final String? preparedByName;

  SummaryReport({
    required this.id,
    required this.preparedBy,
    required this.title,
    this.content,
    required this.status,
    this.period,
    this.fileUrl,
    this.createdAt,
    this.preparedByName,
  });

  factory SummaryReport.fromJson(Map<String, dynamic> json) {
    return SummaryReport(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      preparedBy: json['prepared_by'] is int
          ? json['prepared_by']
          : int.tryParse(json['prepared_by']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      period: json['period']?.toString(),
      fileUrl: json['file_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      preparedByName: json['prepared_by_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prepared_by': preparedBy,
      'title': title,
      'content': content,
      'status': status,
      'period': period,
      'file_url': fileUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
