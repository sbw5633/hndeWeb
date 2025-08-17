class AppUser {
  final String uid;
  final String name;
  final String email;
  final String affiliation;
  final String role; // main_admin, hq_admin, employee 등
  final bool approved;
  final bool isMainAdmin;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.affiliation,
    required this.role,
    required this.approved,
    required this.isMainAdmin,
    this.createdAt,
    this.lastLoginAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json, {String? uid}) {
    return AppUser(
      uid: uid ?? json['uid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      affiliation: json['affiliation'] as String? ?? '',
      role: json['role'] as String? ?? 'employee',
      approved: json['approved'] as bool? ?? false,
      isMainAdmin: json['isMainAdmin'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      lastLoginAt: json['lastLoginAt'] != null ? DateTime.tryParse(json['lastLoginAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'email': email,
    'affiliation': affiliation,
    'role': role,
    'approved': approved,
    'isMainAdmin': isMainAdmin,
    'createdAt': createdAt?.toIso8601String(),
    'lastLoginAt': lastLoginAt?.toIso8601String(),
  };
} 