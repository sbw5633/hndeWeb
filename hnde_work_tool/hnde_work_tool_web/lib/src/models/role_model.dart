import 'package:cloud_firestore/cloud_firestore.dart';

class RoleModel {
  RoleModel({
    required this.roleIdx,
    required this.roleName,
    required this.canAccessFiles,
    required this.canAccessSettings,
  });

  final int roleIdx;
  final String roleName;
  final bool canAccessFiles;
  final bool canAccessSettings;

  factory RoleModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return RoleModel(
      roleIdx: (data['roleIdx'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 1,
      roleName: data['roleName'] as String? ?? '',
      canAccessFiles: data['canAccessFiles'] as bool? ?? false,
      canAccessSettings: data['canAccessSettings'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'roleIdx': roleIdx,
      'roleName': roleName,
      'canAccessFiles': canAccessFiles,
      'canAccessSettings': canAccessSettings,
    };
  }
}

