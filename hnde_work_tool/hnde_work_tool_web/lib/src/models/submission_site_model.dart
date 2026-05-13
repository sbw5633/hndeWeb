import 'package:cloud_firestore/cloud_firestore.dart';

/// 제출된 파일 한 건
class SubmittedFileItem {
  const SubmittedFileItem({
    required this.fileUrl,
    required this.fileName,
    this.fileKey,
  });

  final String fileUrl;
  final String fileName;
  /// R2 객체 키 (있으면 다운로드 시 URL 파싱 없이 사용)
  final String? fileKey;

  factory SubmittedFileItem.fromMap(Map<String, dynamic> m) {
    final String? fk = m['fileKey'] as String?;
    return SubmittedFileItem(
      fileUrl: m['fileUrl'] as String? ?? '',
      fileName: m['fileName'] as String? ?? '',
      fileKey: fk != null && fk.trim().isNotEmpty ? fk.trim() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fileUrl': fileUrl,
      'fileName': fileName,
      if (fileKey != null && fileKey!.isNotEmpty) 'fileKey': fileKey,
    };
  }
}

/// 자료 송수신 요청별 지점/사업소 진행 상태 (`submissions/{id}/sites/{siteId}`)
class SubmissionSiteModel {
  const SubmissionSiteModel({
    required this.id,
    required this.label,
    this.status = 'pending',
    this.updatedAt,
    this.submittedFileUrl,
    this.submittedFileName,
    this.submittedFiles = const <SubmittedFileItem>[],
    this.reRequestComment,
    this.reRequestAt,
  });

  final String id;
  final String label;
  /// pending | submitted | approved | rejected | re_requested
  final String status;
  final Timestamp? updatedAt;
  /// 구버전 단일 파일 (submittedFiles 비어 있을 때만 사용)
  final String? submittedFileUrl;
  final String? submittedFileName;
  final List<SubmittedFileItem> submittedFiles;
  /// 재요청 시 요청처 코멘트
  final String? reRequestComment;
  final Timestamp? reRequestAt;

  /// 단일/다중 통합 목록 (표시·다운로드용)
  List<SubmittedFileItem> get allSubmittedFiles {
    if (submittedFiles.isNotEmpty) return submittedFiles;
    if (submittedFileUrl != null && submittedFileUrl!.isNotEmpty) {
      return <SubmittedFileItem>[
        SubmittedFileItem(
          fileUrl: submittedFileUrl!,
          fileName: submittedFileName ?? '파일',
        ),
      ];
    }
    return <SubmittedFileItem>[];
  }

  bool get hasSubmittedFiles => allSubmittedFiles.isNotEmpty;

  factory SubmissionSiteModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    final List<SubmittedFileItem> files = <SubmittedFileItem>[];
    final List<dynamic>? raw = d['submittedFiles'] as List<dynamic>?;
    if (raw != null) {
      for (final dynamic e in raw) {
        if (e is Map<String, dynamic>) {
          files.add(SubmittedFileItem.fromMap(e));
        } else if (e is Map) {
          files.add(SubmittedFileItem.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    return SubmissionSiteModel(
      id: doc.id,
      label: d['label'] as String? ?? doc.id,
      status: d['status'] as String? ?? 'pending',
      updatedAt: d['updatedAt'] as Timestamp?,
      submittedFileUrl: d['submittedFileUrl'] as String?,
      submittedFileName: d['submittedFileName'] as String?,
      submittedFiles: files,
      reRequestComment: d['reRequestComment'] as String?,
      reRequestAt: d['reRequestAt'] as Timestamp?,
    );
  }

  /// 상태 한글 표시
  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '대기';
      case 'submitted':
        return '제출됨';
      case 'approved':
        return '확인됨';
      case 'rejected':
        return '반려됨';
      case 're_requested':
        return '재요청';
      default:
        return status;
    }
  }
}
