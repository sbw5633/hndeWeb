import 'package:cloud_firestore/cloud_firestore.dart';

/// 자료 송수신(본사 요청 ↔ 지점 제출) 문서
class SubmissionModel {
  const SubmissionModel({
    required this.id,
    required this.title,
    this.description = '',
    this.urgency = 'general',
    this.dueDate,
    this.createdByUid = '',
    this.createdAt,
    this.templateFileName,
    this.templateDownloadUrl,
    this.templateR2Key,
    this.departmentLabel = '',
  });

  final String id;
  final String title;
  final String description;
  /// urgent | general
  final String urgency;
  final Timestamp? dueDate;
  final String createdByUid;
  final Timestamp? createdAt;
  final String? templateFileName;
  final String? templateDownloadUrl;
  /// 양식 파일 R2 키 (다운로드 시 URL에서 파싱하지 않음)
  final String? templateR2Key;
  final String departmentLabel;

  bool get isUrgent => urgency == 'urgent';

  factory SubmissionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    return SubmissionModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      urgency: d['urgency'] as String? ?? 'general',
      dueDate: d['dueDate'] as Timestamp?,
      createdByUid: d['createdByUid'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp?,
      templateFileName: d['templateFileName'] as String?,
      templateDownloadUrl: d['templateDownloadUrl'] as String?,
      templateR2Key: d['templateR2Key'] as String?,
      departmentLabel: d['departmentLabel'] as String? ?? '',
    );
  }

  Map<String, dynamic> toCreateMap(String uid) {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'urgency': urgency,
      'dueDate': dueDate,
      'createdByUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'templateFileName': templateFileName,
      'templateDownloadUrl': templateDownloadUrl,
      if (templateR2Key != null && templateR2Key!.trim().isNotEmpty)
        'templateR2Key': templateR2Key!.trim(),
      'departmentLabel': departmentLabel,
    };
  }
}
