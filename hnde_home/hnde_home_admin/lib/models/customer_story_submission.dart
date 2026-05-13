import 'package:cloud_firestore/cloud_firestore.dart';

// 고객의 이야기 제출 모델 (조회용)
class CustomerStorySubmission {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String title;
  final String content;
  final DateTime createdAt;
  final String? restAreaId; // 사업소 ID

  CustomerStorySubmission({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.title,
    required this.content,
    required this.createdAt,
    this.restAreaId,
  });

  factory CustomerStorySubmission.fromFirestore(
      Map<String, dynamic> data, String id) {
    return CustomerStorySubmission(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      restAreaId: data['restAreaId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'restAreaId': restAreaId,
    };
  }
}

