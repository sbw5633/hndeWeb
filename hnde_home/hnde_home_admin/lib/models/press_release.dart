import 'package:cloud_firestore/cloud_firestore.dart';

// 보도자료 모델
class PressRelease {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String? imageUrl;
  final String? author;

  PressRelease({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.imageUrl,
    this.author,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
      'author': author,
    };
  }

  factory PressRelease.fromJson(Map<String, dynamic> json) {
    return PressRelease(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
      imageUrl: json['imageUrl'] as String?,
      author: json['author'] as String?,
    );
  }

  factory PressRelease.fromFirestore(Map<String, dynamic> data, String id) {
    return PressRelease(
      id: id,
      title: data['title'] as String,
      content: data['content'] as String,
      date: (data['date'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'] as String?,
      author: data['author'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'date': Timestamp.fromDate(date),
      'imageUrl': imageUrl,
      'author': author,
    };
  }
}
