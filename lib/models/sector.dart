class Sector {
  final int id;
  final int businessUnitId;
  final String name;
  final String? code;
  final String? description;
  final bool isActive;
  final String? businessUnitName;
  final int? projectCount;
  final DateTime? createdAt;

  Sector({
    required this.id,
    required this.businessUnitId,
    required this.name,
    this.code,
    this.description,
    this.isActive = true,
    this.businessUnitName,
    this.projectCount,
    this.createdAt,
  });

  factory Sector.fromJson(Map<String, dynamic> json) {
    return Sector(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      businessUnitId: json['business_unit_id'] is int
          ? json['business_unit_id']
          : int.tryParse(json['business_unit_id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      description: json['description']?.toString(),
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1' ||
          json['is_active'] == null,
      businessUnitName: json['business_unit_name']?.toString(),
      projectCount: json['project_count'] is int
          ? json['project_count']
          : int.tryParse(json['project_count']?.toString() ?? ''),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_unit_id': businessUnitId,
      'name': name,
      'code': code,
      'description': description,
      'is_active': isActive,
    };
  }
}
