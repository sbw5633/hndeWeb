import 'package:cloud_firestore/cloud_firestore.dart';

/// 사규집 Firestore `company_rule_files` 문서
class CompanyRuleFileModel {
  const CompanyRuleFileModel({
    required this.id,
    required this.category,
    required this.fileName,
    required this.fileUrl,
    required this.r2Key,
    this.createdAt,
  });

  /// `regulation` (규정) | `guideline` (지침)
  final String category;
  final String fileName;
  final String fileUrl;
  final String r2Key;
  final DateTime? createdAt;
  final String id;

  static CompanyRuleFileModel fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final Map<String, dynamic> m = d.data();
    final Timestamp? ts = m['createdAt'] as Timestamp?;
    return CompanyRuleFileModel(
      id: d.id,
      category: (m['category'] as String?)?.trim() ?? 'regulation',
      fileName: (m['fileName'] as String?)?.trim() ?? d.id,
      fileUrl: (m['fileUrl'] as String?)?.trim() ?? '',
      r2Key: (m['r2Key'] as String?)?.trim() ?? '',
      createdAt: ts?.toDate(),
    );
  }
}
