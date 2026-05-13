// 연혁 모델
class HistoryItem {
  final String id;
  final String year;
  final String? month; // 월 (1-12, 선택사항)
  final String content;

  HistoryItem({
    required this.id,
    required this.year,
    this.month,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'content': content,
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      year: json['year'] as String,
      month: json['month'] as String?,
      content: json['content'] as String,
    );
  }

  factory HistoryItem.fromFirestore(Map<String, dynamic> data, String id) {
    return HistoryItem(
      id: id,
      year: data['year'] as String,
      month: data['month'] as String?,
      content: data['content'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'year': year,
      'month': month,
      'content': content,
    };
  }

  // 정렬을 위한 날짜 키 생성 (년도.월 형식, 월이 없으면 .0)
  String get sortKey {
    if (month != null && month!.isNotEmpty) {
      final monthNum = int.tryParse(month!) ?? 0;
      return '$year.${monthNum.toString().padLeft(2, '0')}';
    }
    return '$year.00';
  }
}

