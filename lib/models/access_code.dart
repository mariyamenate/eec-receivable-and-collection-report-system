class AccessCode {
  final int id;
  final String code;
  final String role;
  // collector | senior_accountant | team_leader | finance_director |
  // management | top_management | superadmin
  final int? sectorId;
  final int? businessUnitId;
  final String? sectorName;
  final String? businessUnitName;
  final bool isUsed;
  final int? usedByUserId;
  final String? usedByName;
  final DateTime? usedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? note;
  final DateTime? createdAt;

  AccessCode({
    required this.id,
    required this.code,
    required this.role,
    this.sectorId,
    this.businessUnitId,
    this.sectorName,
    this.businessUnitName,
    this.isUsed = false,
    this.usedByUserId,
    this.usedByName,
    this.usedAt,
    this.expiresAt,
    this.isActive = true,
    this.note,
    this.createdAt,
  });

  factory AccessCode.fromJson(Map<String, dynamic> json) {
    return AccessCode(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      sectorId: json['sector_id'] is int
          ? json['sector_id']
          : int.tryParse(json['sector_id']?.toString() ?? ''),
      businessUnitId: json['business_unit_id'] is int
          ? json['business_unit_id']
          : int.tryParse(json['business_unit_id']?.toString() ?? ''),
      sectorName: json['sector_name']?.toString(),
      businessUnitName: json['business_unit_name']?.toString(),
      isUsed: json['is_used'] == true || json['is_used'] == 1 || json['is_used'] == '1',
      usedByUserId: json['used_by_user_id'] is int
          ? json['used_by_user_id']
          : int.tryParse(json['used_by_user_id']?.toString() ?? ''),
      usedByName: json['used_by_name']?.toString(),
      usedAt: json['used_at'] != null
          ? DateTime.tryParse(json['used_at'].toString())
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1' ||
          json['is_active'] == null,
      note: json['note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'role': role,
      'sector_id': sectorId,
      'business_unit_id': businessUnitId,
      'is_used': isUsed,
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
      'note': note,
    };
  }

  String get roleLabel {
    switch (role) {
      case 'collector':
        return 'Collector';
      case 'senior_accountant':
        return 'Senior Accountant';
      case 'team_leader':
        return 'Team Leader';
      case 'finance_director':
        return 'Finance Director';
      case 'management':
        return 'Management';
      case 'top_management':
        return 'Top Management';
      case 'superadmin':
        return 'Super Admin';
      default:
        return role;
    }
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get canBeUsed => isActive && !isUsed && !isExpired;
}
