/// A single row in the report history / audit log
/// (one action taken by one actor on one report).
class ReportHistoryEntry {
  final int id;
  final DateTime when;
  final String actorName;
  final String role;
  final String? projectName;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? remark;

  ReportHistoryEntry({
    required this.id,
    required this.when,
    required this.actorName,
    required this.role,
    required this.action,
    this.projectName,
    this.fromStatus,
    this.toStatus,
    this.remark,
  });

  /// Adjust the key names below to match your actual backend response.
  factory ReportHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReportHistoryEntry(
      id: json['id'] as int,
      when: DateTime.parse(json['when'] ?? json['created_at']),
      actorName: (json['actor_name'] ?? json['actor'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      projectName: json['project_name'] as String?,
      action: (json['action'] ?? '') as String,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String?,
      remark: json['remark'] as String?,
    );
  }
}

/// Paged result for a report-history query.
class ReportHistoryPage {
  final List<ReportHistoryEntry> entries;
  final int total;

  ReportHistoryPage({required this.entries, required this.total});

  static ReportHistoryPage empty() => ReportHistoryPage(entries: [], total: 0);
}