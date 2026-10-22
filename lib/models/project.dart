class Project {
  final int id;
  final int sectorId;
  final int? businessUnitId;
  final String name;
  final String? code;
  final String? description;
  final String status; // active | completed | on_hold | cancelled
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? sectorName;
  final String? businessUnitName;
  final DateTime? createdAt;

  Project({
    required this.id,
    required this.sectorId,
    this.businessUnitId,
    required this.name,
    this.code,
    this.description,
    this.status = 'active',
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.sectorName,
    this.businessUnitName,
    this.createdAt,

  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      sectorId: json['sector_id'] is int
          ? json['sector_id']
          : int.tryParse(json['sector_id']?.toString() ?? '') ?? 0,
      businessUnitId: json['business_unit_id'] is int
          ? json['business_unit_id']
          : int.tryParse(json['business_unit_id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'active',
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : null,
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1' ||
          json['is_active'] == null,
      sectorName: json['sector_name']?.toString(),
      businessUnitName: json['business_unit_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sector_id': sectorId,
      'business_unit_id': businessUnitId,
      'name': name,
      'code': code,
      'description': description,
      'status': status,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'is_active': isActive,
    };
  }
}
