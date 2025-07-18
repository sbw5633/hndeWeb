import 'package:equatable/equatable.dart';

/// 사업장 enum (확장성 확보 및 오타 방지)
enum BusinessLocation {
  /// 전체
  all('전체'),
  /// 본사
  headquarters('본사'),
  /// 만남(부산)휴
  mannaeBusanRest('만남(부산)휴'),
  /// 진영(순천)휴
  jinYoungSoonChunRest('진영(순천)휴'),
  /// 장안(울산)휴
  jangAnUlsanRest('장안(울산)휴'),
  /// 장안(부산)휴
  jangAnBusanRest('장안(부산)휴'),
  /// 동명(춘천)휴
  dongMyungChunChunRest('동명(춘천)휴'),
  /// 동명(부산)휴
  dongMyungBusanRest('동명(부산)휴'),
  /// 송산휴게소
  songSanRestArea('송산휴게소'),
  /// 만남(부산)주
  mannaeBusanSub('만남(부산)주'),
  /// 더웨이유통
  deweyDistribution('더웨이유통'),
  /// 더웨이본사
  deweyHeadquarters('더웨이본사'),
  /// 진안(장수)휴/주
  jinAnJangSuRestSub('진안(장수)휴/주'),
  /// 선산주유소
  sunSanGasStation('선산주유소');

  const BusinessLocation(this.displayName);
  final String displayName;

  @override
  String toString() => displayName;
}

/// 게시물 모델 (공지, 일반, 익명, 자료취합 등 확장 가능)
class BoardPost extends Equatable {
  /// 문서 ID
  final String id;

  /// 게시물 타입 ('notice', 'post', 'anonymous', 'gathering' 등)
  final String type;

  /// 제목
  final String title;

  /// 내용
  final String content;

  /// 작성자 ID (익명이어도 DB에는 저장)
  final String authorId;

  /// 작성자 이름 (익명일 경우 '익명' 등으로 표시)
  final String authorName;

  /// 익명 여부
  final bool anonymity;

  /// 생성일시
  final DateTime createdAt;

  /// 수정일시
  final DateTime updatedAt;

  /// 이미지 URL 리스트
  final List<String> images;

  /// 파일 URL 리스트
  final List<String> files;

  /// 조회수
  final int views;

  /// 좋아요 수
  final int likes;

  /// 댓글 수
  final int commentsCount;

  /// 확장 필드 (자료취합 등 추가 정보)
  final Map<String, dynamic> extra;

  /// 대상 사업장
  final BusinessLocation targetGroup;

  const BoardPost({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.anonymity,
    required this.createdAt,
    required this.updatedAt,
    required this.images,
    required this.files,
    required this.views,
    required this.likes,
    required this.commentsCount,
    required this.extra,
    required this.targetGroup,
  });

  /// JSON → BoardPost
  factory BoardPost.fromJson(Map<String, dynamic> json, {String? id}) {
    // targetGroup 파싱
    BusinessLocation parseTargetGroup(dynamic value) {
      if (value == null) return BusinessLocation.all;
      final stringValue = value.toString();
      return BusinessLocation.values.firstWhere(
        (location) => location.displayName == stringValue,
        orElse: () => BusinessLocation.all,
      );
    }

    return BoardPost(
      id: id ?? json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'post',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      anonymity: json['anonymity'] as bool? ?? false,
      createdAt: (json['createdAt'] is DateTime)
          ? json['createdAt'] as DateTime
          : DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: (json['updatedAt'] is DateTime)
          ? json['updatedAt'] as DateTime
          : DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      files: (json['files'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      extra: (json['extra'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      targetGroup: parseTargetGroup(json['targetGroup']),
    );
  }

  /// BoardPost → JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'anonymity': anonymity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'images': images,
      'files': files,
      'views': views,
      'likes': likes,
      'commentsCount': commentsCount,
      'extra': extra,
      'targetGroup': targetGroup.displayName,
    };
  }

  /// 복사본 생성 (필드 일부만 변경)
  BoardPost copyWith({
    String? id,
    String? type,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    bool? anonymity,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? images,
    List<String>? files,
    int? views,
    int? likes,
    int? commentsCount,
    Map<String, dynamic>? extra,
    BusinessLocation? targetGroup,
  }) {
    return BoardPost(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      anonymity: anonymity ?? this.anonymity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      files: files ?? this.files,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      extra: extra ?? this.extra,
      targetGroup: targetGroup ?? this.targetGroup,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        content,
        authorId,
        authorName,
        anonymity,
        createdAt,
        updatedAt,
        images,
        files,
        views,
        likes,
        commentsCount,
        extra,
        targetGroup,
      ];
} 