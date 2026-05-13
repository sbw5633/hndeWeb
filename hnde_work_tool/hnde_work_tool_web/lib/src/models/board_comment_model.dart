import 'package:cloud_firestore/cloud_firestore.dart';

/// 게시글 서브컬렉션 `comments` 문서
class BoardCommentModel {
  const BoardCommentModel({
    required this.id,
    required this.body,
    this.authorUid,
    this.authorDisplay = '',
    this.authorPhotoUrl,
    this.createdAt,
  });

  final String id;
  final String body;
  final String? authorUid;
  final String authorDisplay;
  final String? authorPhotoUrl;
  final Timestamp? createdAt;

  factory BoardCommentModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    return BoardCommentModel(
      id: doc.id,
      body: d['body'] as String? ?? '',
      authorUid: d['authorUid'] as String?,
      authorDisplay: d['authorDisplay'] as String? ?? '',
      authorPhotoUrl: (d['authorPhotoUrl'] as String?)?.trim().isNotEmpty == true
          ? (d['authorPhotoUrl'] as String).trim()
          : null,
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toCreateMap({
    required String? authorUid,
    required String authorDisplay,
    String? authorPhotoUrl,
  }) {
    return <String, dynamic>{
      'body': body,
      'authorUid': authorUid,
      'authorDisplay': authorDisplay,
      if (authorPhotoUrl != null && authorPhotoUrl.trim().isNotEmpty)
        'authorPhotoUrl': authorPhotoUrl.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
