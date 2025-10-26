import 'package:equatable/equatable.dart';
import '../const_value.dart';

/// 게시물 모델 (공지, 일반, 익명, 자료취합 등 확장 가능)
class BoardPost extends Equatable {
  /// 문서 ID
  final String id;

  /// 게시물 타입
  final MenuType type;

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

  /// 이미지 URL 리스트 (이제는 [{url, name}])
  final List<Map<String, String>> images;

  /// 파일 URL 리스트 (이제는 [{url, name}])
  final List<Map<String, String>> files;

  /// 조회수
  final int views;

  /// 좋아요 수
  final int likes;

  /// 좋아요한 사용자 ID 목록
  final List<String> likedBy;

  /// 댓글 수
  final int commentsCount;

  /// 확장 필드 (자료취합 등 추가 정보)
  final Map<String, dynamic> extra;

  /// 대상 사업소 (이제는 String 또는 Map 등 서버 데이터 기반)
  final String targetGroup;

  /// 사업소별 회신 데이터 (자료요청용)
  final Map<String, dynamic> responses;

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
    this.likedBy = const [],
    required this.commentsCount,
    required this.extra,
    required this.targetGroup,
    this.responses = const {},
  });

  /// JSON → BoardPost
  factory BoardPost.fromJson(Map<String, dynamic> json, {String? id}) {
    // 문자열 타입을 MenuType enum으로 변환
    MenuType parseType(String? typeString) {
      switch (typeString) {
        case 'notice':
          return MenuType.notice;
        case 'board':
          return MenuType.board;
        case 'anonymousBoard':
          return MenuType.anonymousBoard;
        case 'dataRequest':
          return MenuType.dataRequest;
        default:
          return MenuType.board;
      }
    }

    return BoardPost(
      id: id ?? json['id'] as String? ?? '',
      type: parseType(json['type'] as String?),
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
      images: (json['images'] as List?)?.map((e) => e is Map<String, dynamic> ? e.map((k, v) => MapEntry(k, v.toString())) : {'url': e.toString(), 'name': ''}).toList() ?? const [],
      files: (json['files'] as List?)?.map((e) => e is Map<String, dynamic> ? e.map((k, v) => MapEntry(k, v.toString())) : {'url': e.toString(), 'name': ''}).toList() ?? const [],
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      commentsCount: json['commentsCount'] as int? ?? 0,
      extra: (json['extra'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      targetGroup: json['targetGroup'] as String? ?? '',
      responses: (json['responses'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  /// BoardPost → JSON
  Map<String, dynamic> toJson() {
    // MenuType enum을 문자열로 변환
    String typeToString(MenuType menuType) {
      switch (menuType) {
        case MenuType.notice:
          return 'notice';
        case MenuType.board:
          return 'board';
        case MenuType.anonymousBoard:
          return 'anonymousBoard';
        case MenuType.dataRequest:
          return 'dataRequest';
        default:
          return 'board';
      }
    }

    return {
      'id': id,
      'type': typeToString(type),
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
      'likedBy': likedBy,
      'commentsCount': commentsCount,
      'extra': extra,
      'targetGroup': targetGroup,
      'responses': responses,
    };
  }

  /// 복사본 생성 (필드 일부만 변경)
  BoardPost copyWith({
    String? id,
    MenuType? type,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    bool? anonymity,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, String>>? images,
    List<Map<String, String>>? files,
    int? views,
    int? likes,
    List<String>? likedBy,
    int? commentsCount,
    Map<String, dynamic>? extra,
    String? targetGroup,
    Map<String, dynamic>? responses,
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
      likedBy: likedBy ?? this.likedBy,
      commentsCount: commentsCount ?? this.commentsCount,
      extra: extra ?? this.extra,
      targetGroup: targetGroup ?? this.targetGroup,
      responses: responses ?? this.responses,
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
        likedBy,
        commentsCount,
        extra,
        targetGroup,
        responses,
      ];
} 