import 'package:cloud_firestore/cloud_firestore.dart';

/// 공지 / 자유 / 익명 게시판 공통 모델
class PostModel {
  const PostModel({
    required this.id,
    required this.title,
    required this.body,
    required this.boardType,
    this.authorUid,
    this.authorDisplay = '',
    this.authorPhotoUrl,
    this.createdAt,
    this.editedAt,
    this.readCount = 0,
    this.isOfficial = false,
    this.imageUrls = const <String>[],
    this.deleted = false,
    this.deletedAt,
    this.deletedByUid,
    this.isLatest = true,
    this.revisionOf,
    this.rootPostId,
  });

  final String id;
  final String title;
  final String body;
  /// notice | freeboard | anonymous
  final String boardType;
  final String? authorUid;
  final String authorDisplay;
  final String? authorPhotoUrl;
  final Timestamp? createdAt;
  /// 리비전(수정) 생성 시각 (원본은 null)
  final Timestamp? editedAt;
  final int readCount;
  final bool isOfficial;
  /// 본문에 첨부된 이미지 URL (최대 5개, R2 등)
  final List<String> imageUrls;
  /// 소프트 삭제 여부(목록/일반 사용자 뷰에서 숨김)
  final bool deleted;
  final Timestamp? deletedAt;
  final String? deletedByUid;
  /// 게시판 목록에 노출되는 최신본 여부 (수정 시 이전 리비전은 false)
  final bool isLatest;
  /// 수정 리비전인 경우, 바로 이전 글 id
  final String? revisionOf;
  /// 최초 글 id(루트). 수정 리비전도 동일 루트로 묶기 위함
  final String? rootPostId;

  factory PostModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    final List<String> urls = <String>[];
    final dynamic raw = d['imageUrls'];
    if (raw is List) {
      for (final dynamic e in raw) {
        if (e is String && e.trim().isNotEmpty) {
          urls.add(e.trim());
        }
      }
    }
    return PostModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      boardType: d['boardType'] as String? ?? 'freeboard',
      authorUid: d['authorUid'] as String?,
      authorDisplay: d['authorDisplay'] as String? ?? '',
      authorPhotoUrl: (d['authorPhotoUrl'] as String?)?.trim().isNotEmpty == true
          ? (d['authorPhotoUrl'] as String).trim()
          : null,
      createdAt: d['createdAt'] as Timestamp?,
      editedAt: d['editedAt'] as Timestamp?,
      readCount: (d['readCount'] as num?)?.toInt() ?? 0,
      isOfficial: d['isOfficial'] as bool? ?? false,
      imageUrls: urls,
      deleted: d['deleted'] as bool? ?? false,
      deletedAt: d['deletedAt'] as Timestamp?,
      deletedByUid: d['deletedByUid'] as String?,
      isLatest: d['isLatest'] as bool? ?? true,
      revisionOf: (d['revisionOf'] as String?)?.trim().isNotEmpty == true
          ? (d['revisionOf'] as String).trim()
          : null,
      rootPostId: (d['rootPostId'] as String?)?.trim().isNotEmpty == true
          ? (d['rootPostId'] as String).trim()
          : null,
    );
  }

  Map<String, dynamic> toCreateMap({
    required String boardType,
    required String? authorUid,
    required String authorDisplay,
    String? authorPhotoUrl,
  }) {
    return <String, dynamic>{
      'title': title,
      'body': body,
      'boardType': boardType,
      'authorUid': authorUid,
      'authorDisplay': authorDisplay,
      if (authorPhotoUrl != null && authorPhotoUrl.trim().isNotEmpty)
        'authorPhotoUrl': authorPhotoUrl.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'readCount': 0,
      'isOfficial': isOfficial,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      'deleted': false,
      'deletedAt': null,
      'deletedByUid': null,
      'isLatest': true,
      'revisionOf': null,
      'rootPostId': null,
    };
  }
}
