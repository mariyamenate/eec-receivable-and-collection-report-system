class CollectionData {
  final int id;
  final int collectorId;
  final int? projectId;
  final int? sectorId;
  final int? businessUnitId;
  final String period;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final String status;
  final String? notes;
  final String? fileUrl;
  final Map<String, dynamic>? rows;
  final List<Map<String, dynamic>>? saLines;
  final String? collectorName;
  final String? projectName;
  final String? sectorName;
  final String? remark;
  final DateTime? createdAt;
  final DateTime? submittedAt;

  CollectionData({
    required this.id,
    required this.collectorId,
    this.projectId,
    this.sectorId,
    this.businessUnitId,
    required this.period,
    this.periodFrom,
    this.periodTo,
    this.status = 'draft',
    this.notes,
    this.fileUrl,
    this.rows,
    this.saLines,
    this.collectorName,
    this.projectName,
    this.sectorName,
    this.remark,
    this.createdAt,
    this.submittedAt,
  });

  factory CollectionData.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedRows;
    if (json['rows'] is Map) {
      parsedRows = Map<String, dynamic>.from(json['rows']);
    } else if (json['table_data'] is Map) {
      parsedRows = Map<String, dynamic>.from(json['table_data']);
    }

    List<Map<String, dynamic>>? parsedSaLines;
    if (json['sa_lines'] is List) {
      parsedSaLines = (json['sa_lines'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return CollectionData(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      collectorId: json['collector_id'] is int
          ? json['collector_id']
          : int.tryParse(json['collector_id']?.toString() ?? '') ?? 0,
      projectId: json['project_id'] is int
          ? json['project_id']
          : int.tryParse(json['project_id']?.toString() ?? ''),
      sectorId: json['sector_id'] is int
          ? json['sector_id']
          : int.tryParse(json['sector_id']?.toString() ?? ''),
      businessUnitId: json['business_unit_id'] is int
          ? json['business_unit_id']
          : int.tryParse(json['business_unit_id']?.toString() ?? ''),
      period: json['period']?.toString() ?? '',
      periodFrom: json['period_from'] != null
          ? DateTime.tryParse(json['period_from'].toString())
          : null,
      periodTo: json['period_to'] != null
          ? DateTime.tryParse(json['period_to'].toString())
          : null,
      status: json['status']?.toString() ?? 'draft',
      notes: json['notes']?.toString(),
      fileUrl: json['file_url']?.toString(),
      rows: parsedRows,
      saLines: parsedSaLines,
      collectorName: json['collector_name']?.toString(),
      projectName: json['project_name']?.toString(),
      sectorName: json['sector_name']?.toString(),
      remark: json['remark']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collector_id': collectorId,
      'project_id': projectId,
      'sector_id': sectorId,
      'business_unit_id': businessUnitId,
      'period': period,
      'period_from': periodFrom?.toIso8601String().split('T').first,
      'period_to': periodTo?.toIso8601String().split('T').first,
      'status': status,
      'notes': notes,
      'file_url': fileUrl,
      'rows': rows,
      'table_data': rows,
      'sa_lines': saLines,
    };
  }

  CollectionRows get financials => CollectionRows.fromMap(rows);
}

class CollectionRows {
  final DateTime? receivableDate;
  final double amountRequested;
  final double weeklyPlanAmount;
  final double weeklyCollectedAmount;
  final bool isAdvancePayment;

  const CollectionRows({
    this.receivableDate,
    this.amountRequested = 0,
    this.weeklyPlanAmount = 0,
    this.weeklyCollectedAmount = 0,
    this.isAdvancePayment = false,
  });

  factory CollectionRows.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CollectionRows();
    double _num(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return CollectionRows(
      receivableDate: map['receivable_date'] != null
          ? DateTime.tryParse(map['receivable_date'].toString())
          : null,
      amountRequested: _num(map['amount_requested']),
      weeklyPlanAmount: _num(map['weekly_plan_amount']),
      weeklyCollectedAmount: _num(map['weekly_collected_amount']),
      isAdvancePayment: map['is_advance_payment'] == true ||
          map['is_advance_payment']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receivable_date': receivableDate?.toIso8601String().split('T').first,
      'amount_requested': amountRequested,
      'weekly_plan_amount': weeklyPlanAmount,
      'weekly_collected_amount': weeklyCollectedAmount,
      'is_advance_payment': isAdvancePayment,
    };
  }

  bool isPreviousYears(DateTime fiscalCutoff) {
    if (receivableDate == null) return false;
    return receivableDate!.isBefore(fiscalCutoff);
  }
}