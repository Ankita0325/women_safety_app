class UserModel {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String role;
  final List<EmergencyContact> emergencyContacts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    this.role = 'user',
    this.emergencyContacts = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'user',
      emergencyContacts: (json['emergency_contacts'] as List?)
              ?.map((e) => EmergencyContact.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'emergency_contacts': emergencyContacts.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_verified': isVerified,
    };
  }
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
    this.isPrimary = false,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relation: json['relation'] ?? '',
      isPrimary: json['is_primary'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
      'is_primary': isPrimary,
    };
  }
}
