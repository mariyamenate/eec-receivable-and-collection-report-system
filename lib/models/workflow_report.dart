import 'dart:convert';
class WorkflowReport {
  final int id;
  final int? preparedBy; // senior accountant
  final int? projectId;
  final int? sectorId;
  final int? businessUnitId;
  final String title;
  final String? periodLabel;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final String status;
  final String? templateFileUrl;
  final String? summaryFileUrl;
  final String? teamLeaderRemark;
  final String? managementRemark;
  final String? preparedByName;
  final String? sectorName;
  final String? businessUnitName;
  final DateTime? createdAt;
  final DateTime? updatedAt;


  final Map<String, dynamic>? templateData;

  WorkflowReport({
    required this.id,
    this.preparedBy,
    this.projectId,
    this.sectorId,
    this.businessUnitId,
    required this.title,
    this.periodLabel,
    this.periodFrom,
    this.periodTo,
    this.status = 'draft',
    this.templateFileUrl,
    this.summaryFileUrl,
    this.teamLeaderRemark,
    this.managementRemark,
    this.preparedByName,
    this.sectorName,
    this.businessUnitName,
    this.createdAt,
    this.updatedAt,
    this.templateData,
  });

  factory WorkflowReport.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedTemplateData;
    final raw = json['template_data'];
    if (raw is Map) {
      parsedTemplateData = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          parsedTemplateData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        parsedTemplateData = null;
      }
    }

    return WorkflowReport(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      preparedBy: json['prepared_by'] is int
          ? json['prepared_by']
          : int.tryParse(json['prepared_by']?.toString() ?? ''),
      projectId: json['project_id'] is int
          ? json['project_id']
          : int.tryParse(json['project_id']?.toString() ?? ''),
      sectorId: json['sector_id'] is int
          ? json['sector_id']
          : int.tryParse(json['sector_id']?.toString() ?? ''),
      businessUnitId: json['business_unit_id'] is int
          ? json['business_unit_id']
          : int.tryParse(json['business_unit_id']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      periodLabel: json['period_label']?.toString(),
      periodFrom: json['period_from'] != null
          ? DateTime.tryParse(json['period_from'].toString())
          : null,
      periodTo: json['period_to'] != null
          ? DateTime.tryParse(json['period_to'].toString())
          : null,
      status: json['status']?.toString() ?? 'draft',
      templateFileUrl: json['template_file_url']?.toString(),
      summaryFileUrl: json['summary_file_url']?.toString(),
      teamLeaderRemark: json['team_leader_remark']?.toString(),
      managementRemark: json['management_remark']?.toString(),
      preparedByName: json['prepared_by_name']?.toString(),
      sectorName: json['sector_name']?.toString(),
      businessUnitName: json['business_unit_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      templateData: parsedTemplateData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prepared_by': preparedBy,
      'project_id': projectId,
      'sector_id': sectorId,
      'business_unit_id': businessUnitId,
      'title': title,
      'period_label': periodLabel,
      'period_from': periodFrom?.toIso8601String().split('T').first,
      'period_to': periodTo?.toIso8601String().split('T').first,
      'status': status,
      'template_file_url': templateFileUrl,
      'summary_file_url': summaryFileUrl,
      'team_leader_remark': teamLeaderRemark,
      'management_remark': managementRemark,
      'template_data': templateData,
    };
  }

  bool get isPendingTeamLeader => status == 'sent_to_team_leader';
  bool get isPendingManagement =>
      status == 'approved_by_team_leader' || status == 'sent_to_management';
  bool get isFinal =>
      status == 'sent_to_top_management' || status == 'approved_by_management';
}