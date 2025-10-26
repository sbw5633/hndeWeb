import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Comment extends Equatable {
  final String id;
  final String postId;
  final String? parentId; // 대댓글인 경우 부모 댓글 ID
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAnonymous;
  final List<String> likes; // 좋아요한 사용자 ID 목록
  final bool isDeleted; // 삭제된 댓글인지 여부

  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isAnonymous = false,
    this.likes = const [],
    this.isDeleted = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json, {String? id}) {
    return Comment(
      id: id ?? json['id'] ?? '',
      postId: json['postId'] ?? '',
      parentId: json['parentId'],
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? '',
      content: json['content'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAnonymous: json['isAnonymous'] ?? false,
      likes: List<String>.from(json['likes'] ?? []),
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'parentId': parentId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isAnonymous': isAnonymous,
      'likes': likes,
      'isDeleted': isDeleted,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? parentId,
    String? authorId,
    String? authorName,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAnonymous,
    List<String>? likes,
    bool? isDeleted,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      parentId: parentId ?? this.parentId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      likes: likes ?? this.likes,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
    id,
    postId,
    parentId,
    authorId,
    authorName,
    content,
    createdAt,
    updatedAt,
    isAnonymous,
    likes,
    isDeleted,
  ];
}
