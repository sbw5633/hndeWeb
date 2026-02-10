import 'package:cloud_firestore/cloud_firestore.dart';

// 고객이벤트 모델
class CustomerEvent {
  final String id;
  final String title;
  final String content;
  final DateTime startDate;
  final DateTime endDate;
  final String? imageUrl;
  final bool isActive;

  CustomerEvent({
    required this.id,
    required this.title,
    required this.content,
    required this.startDate,
    required this.endDate,
    this.imageUrl,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }

  factory CustomerEvent.fromJson(Map<String, dynamic> json) {
    return CustomerEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  factory CustomerEvent.fromFirestore(Map<String, dynamic> data, String id) {
    return CustomerEvent(
      id: id,
      title: data['title'] as String,
      content: data['content'] as String,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }
}

