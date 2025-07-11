class AppUser {
  final String uid;
  final String name;
  final String email;
  final String affiliation;
  final String role;
  final bool approved;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.affiliation,
    required this.role,
    required this.approved,
    this.createdAt,
    this.lastLoginAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      affiliation: map['affiliation'] ?? '',
      role: map['role'] ?? 'employee',
      approved: map['approved'] ?? false,
      createdAt: map['createdAt']?.toDate(),
      lastLoginAt: map['lastLoginAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'affiliation': affiliation,
      'role': role,
      'approved': approved,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
    };
  }
} 