class BusinessUnit {
  final int id;
  final String name;
  final String? code;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final int? sectorCount;
  final int? projectCount;

  BusinessUnit({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.sectorCount,
    this.projectCount,
  });

  factory BusinessUnit.fromJson(Map<String, dynamic> json) {
    return BusinessUnit(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      description: json['description']?.toString(),
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1' ||
          json['is_active'] == null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      sectorCount: json['sector_count'] is int
          ? json['sector_count']
          : int.tryParse(json['sector_count']?.toString() ?? ''),
      projectCount: json['project_count'] is int
          ? json['project_count']
          : int.tryParse(json['project_count']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'is_active': isActive,
    };
  }
}
