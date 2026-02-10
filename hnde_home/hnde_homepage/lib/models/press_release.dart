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
}

// 보도자료 더미 데이터
class PressReleaseData {
  static List<PressRelease> getDummyData() {
    return [
      PressRelease(
        id: '1',
        title: 'H&DE, 새로운 휴게소 사업 시작',
        content: 'H&DE가 새로운 휴게소 사업을 시작했습니다...',
        date: DateTime(2024, 1, 15),
        author: '홍보팀',
      ),
      PressRelease(
        id: '2',
        title: 'H&DE, 경영이념 발표',
        content: 'H&DE가 새로운 경영이념을 발표했습니다...',
        date: DateTime(2024, 1, 10),
        author: '홍보팀',
      ),
      PressRelease(
        id: '3',
        title: 'H&DE, 고객 만족도 조사 결과 발표',
        content: 'H&DE의 고객 만족도 조사 결과가 발표되었습니다...',
        date: DateTime(2024, 1, 5),
        author: '마케팅팀',
      ),
      PressRelease(
        id: '4',
        title: 'H&DE, 신규 매장 오픈',
        content: 'H&DE가 새로운 매장을 오픈했습니다...',
        date: DateTime(2024, 1, 1),
        author: '사업팀',
      ),
      PressRelease(
        id: '5',
        title: 'H&DE, 사회공헌 활동 실시',
        content: 'H&DE가 지역사회를 위한 사회공헌 활동을 실시했습니다...',
        date: DateTime(2023, 12, 28),
        author: '홍보팀',
      ),
      PressRelease(
        id: '6',
        title: 'H&DE, 녹색경영 인증 획득',
        content: 'H&DE가 녹색경영 인증을 획득했습니다...',
        date: DateTime(2023, 12, 20),
        author: '경영팀',
      ),
      PressRelease(
        id: '7',
        title: 'H&DE, 신제품 출시',
        content: 'H&DE가 새로운 제품을 출시했습니다...',
        date: DateTime(2023, 12, 15),
        author: '기획팀',
      ),
      PressRelease(
        id: '8',
        title: 'H&DE, 글로벌 파트너십 체결',
        content: 'H&DE가 글로벌 파트너와 전략적 제휴를 체결했습니다...',
        date: DateTime(2023, 12, 10),
        author: '국제사업팀',
      ),
    ];
  }
}
