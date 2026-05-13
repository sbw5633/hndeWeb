import 'package:cloud_firestore/cloud_firestore.dart';

// 공지사항 모델
class Notice {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String? author;
  final bool isImportant; // 중요 공지 여부

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
}

// 공지사항 더미 데이터
class NoticeData {
  static List<Notice> getDummyData() {
    return [
      Notice(
        id: '1',
        title: '2024년 신년 인사말',
        content: '2024년을 맞아 H&DE를 찾아주시는 모든 고객 여러분께 감사 인사를 드립니다...',
        date: DateTime(2024, 1, 1),
        author: '관리자',
        isImportant: true,
      ),
      Notice(
        id: '2',
        title: '휴게소 운영 시간 변경 안내',
        content: '고객 서비스 향상을 위해 일부 휴게소의 운영 시간이 변경되었습니다...',
        date: DateTime(2024, 1, 5),
        author: '운영팀',
      ),
      Notice(
        id: '3',
        title: '신규 매장 오픈 안내',
        content: '더 나은 서비스를 제공하기 위해 신규 매장을 오픈하였습니다...',
        date: DateTime(2024, 1, 10),
        author: '사업팀',
      ),
      Notice(
        id: '4',
        title: '시스템 점검 안내',
        content: '시스템 개선을 위한 점검 작업을 실시합니다...',
        date: DateTime(2024, 1, 15),
        author: 'IT팀',
      ),
      Notice(
        id: '5',
        title: '추석 명절 운영 안내',
        content: '추석 명절을 맞아 특별 운영 계획을 안내드립니다...',
        date: DateTime(2024, 1, 20),
        author: '운영팀',
      ),
      Notice(
        id: '6',
        title: '고객 만족도 조사 실시',
        content: '더 나은 서비스를 위해 고객 만족도 조사를 실시합니다...',
        date: DateTime(2024, 1, 25),
        author: '마케팅팀',
      ),
      Notice(
        id: '7',
        title: '환경 보호 캠페인 안내',
        content: '환경 보호를 위한 캠페인을 진행합니다...',
        date: DateTime(2024, 2, 1),
        author: '홍보팀',
      ),
      Notice(
        id: '8',
        title: '신규 서비스 런칭 안내',
        content: '고객 편의를 위한 신규 서비스를 런칭했습니다...',
        date: DateTime(2024, 2, 5),
        author: '기획팀',
      ),
    ];
  }
}
