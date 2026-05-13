import 'package:cloud_firestore/cloud_firestore.dart';

class BranchGroupModel {
  BranchGroupModel({
    required this.key,
    required this.label,
    required this.branchNames,
  });

  final String key;
  final String label;
  final List<String> branchNames;

  factory BranchGroupModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final List<dynamic> raw = data['branchNames'] as List<dynamic>? ?? <dynamic>[];
    return BranchGroupModel(
      key: doc.id,
      label: data['label'] as String? ?? '',
      branchNames: raw.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'label': label,
      'branchNames': branchNames,
    };
  }
}

