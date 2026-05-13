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
}

// 고객이벤트 더미 데이터
class CustomerEventData {
  static List<CustomerEvent> getDummyData() {
    return [
      CustomerEvent(
        id: '1',
        title: '신규 고객 환영 이벤트',
        content: '신규 고객을 위한 특별 이벤트를 진행합니다...',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        isActive: true,
      ),
      CustomerEvent(
        id: '2',
        title: '여름 특별 프로모션',
        content: '여름 시즌 특별 프로모션을 진행합니다...',
        startDate: DateTime(2024, 6, 1),
        endDate: DateTime(2024, 8, 31),
        isActive: true,
      ),
      CustomerEvent(
        id: '3',
        title: '연말 감사 이벤트',
        content: '연말을 맞아 고객 여러분께 감사 이벤트를 진행합니다...',
        startDate: DateTime(2024, 12, 1),
        endDate: DateTime(2024, 12, 31),
        isActive: false,
      ),
      CustomerEvent(
        id: '4',
        title: '봄맞이 특가 이벤트',
        content: '봄을 맞아 특별 가격으로 제공하는 이벤트입니다...',
        startDate: DateTime(2024, 3, 1),
        endDate: DateTime(2024, 5, 31),
        isActive: true,
      ),
      CustomerEvent(
        id: '5',
        title: '가을 감사 이벤트',
        content: '가을을 맞아 고객 여러분께 감사 이벤트를 진행합니다...',
        startDate: DateTime(2024, 9, 1),
        endDate: DateTime(2024, 11, 30),
        isActive: true,
      ),
      CustomerEvent(
        id: '6',
        title: '크리스마스 특별 이벤트',
        content: '크리스마스 시즌 특별 이벤트를 진행합니다...',
        startDate: DateTime(2023, 12, 1),
        endDate: DateTime(2023, 12, 25),
        isActive: false,
      ),
      CustomerEvent(
        id: '7',
        title: '신년 기념 이벤트',
        content: '새해를 맞아 특별 이벤트를 진행합니다...',
        startDate: DateTime(2023, 12, 20),
        endDate: DateTime(2024, 1, 10),
        isActive: false,
      ),
      CustomerEvent(
        id: '8',
        title: '추석 명절 이벤트',
        content: '추석 명절을 맞아 특별 이벤트를 진행합니다...',
        startDate: DateTime(2023, 9, 15),
        endDate: DateTime(2023, 9, 30),
        isActive: false,
      ),
    ];
  }
}
