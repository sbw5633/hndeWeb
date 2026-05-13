import 'package:cloud_firestore/cloud_firestore.dart';

// 공지사항 모델
class Notice {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String? author;
  final bool isImportant;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.author,
    this.isImportant = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'author': author,
      'isImportant': isImportant,
    };
  }

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
      author: json['author'] as String?,
      isImportant: json['isImportant'] as bool? ?? false,
    );
  }

  factory Notice.fromFirestore(Map<String, dynamic> data, String id) {
    return Notice(
      id: id,
      title: data['title'] as String,
      content: data['content'] as String,
      date: (data['date'] as Timestamp).toDate(),
      author: data['author'] as String?,
      isImportant: data['isImportant'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'date': Timestamp.fromDate(date),
      'author': author,
      'isImportant': isImportant,
    };
  }
}

