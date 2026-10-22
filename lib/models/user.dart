class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? avatar;
  final String? token;

  // For collectors
  final int? businessUnitId;
  final String? businessUnitName;
  final int? sectorId;
  final String? sectorName;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.avatar,
    this.token,
    this.businessUnitId,
    this.businessUnitName,
    this.sectorId,
    this.sectorName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      token: json['token']?.toString(),
      businessUnitId: json['business_unit_id'] != null
          ? (json['business_unit_id'] is int
          ? json['business_unit_id']
          : int.tryParse(json['business_unit_id'].toString()))
          : null,
      businessUnitName: json['business_unit_name']?.toString(),
      sectorId: json['sector_id'] != null
          ? (json['sector_id'] is int
          ? json['sector_id']
          : int.tryParse(json['sector_id'].toString()))
          : null,
      sectorName: json['sector_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'avatar': avatar,
      'token': token,
      'business_unit_id': businessUnitId,
      'business_unit_name': businessUnitName,
      'sector_id': sectorId,
      'sector_name': sectorName,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? avatar,
    String? token,
    int? businessUnitId,
    String? businessUnitName,
    int? sectorId,
    String? sectorName,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      token: token ?? this.token,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitName: businessUnitName ?? this.businessUnitName,
      sectorId: sectorId ?? this.sectorId,
      sectorName: sectorName ?? this.sectorName,
    );
  }
}