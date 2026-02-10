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

  // 정렬을 위한 날짜 키 생성 (년도.월 형식, 월이 없으면 .0)
  String get sortKey {
    if (month != null && month!.isNotEmpty) {
      final monthNum = int.tryParse(month!) ?? 0;
      return '$year.${monthNum.toString().padLeft(2, '0')}';
    }
    return '$year.00';
  }
}

class HistoryData {
  static List<HistoryItem> getDummyData() {
    return [
      HistoryItem(
        id: '1',
        year: '2024',
        content: 'H&DE 설립',
      ),
      HistoryItem(
        id: '2',
        year: '2024',
        content: '첫 번째 프로젝트 완료',
      ),
      HistoryItem(
        id: '3',
        year: '2023',
        content: '회사 준비 과정',
      ),
      HistoryItem(
        id: '4',
        year: '2023',
        content: '초기 팀 구성',
      ),
    ];
  }

  // 연도별로 그룹핑 (월 정보 고려)
  static Map<String, List<HistoryItem>> groupByYear(List<HistoryItem> items) {
    // 먼저 날짜 순으로 정렬 (최신순)
    final sortedItems = List<HistoryItem>.from(items)
      ..sort((a, b) {
        // 연도 비교
        final yearCompare = b.year.compareTo(a.year);
        if (yearCompare != 0) return yearCompare;
        
        // 같은 연도면 월 비교 (월이 없으면 뒤로)
        final aMonth = a.month != null && a.month!.isNotEmpty 
            ? int.tryParse(a.month!) ?? 0 
            : 0;
        final bMonth = b.month != null && b.month!.isNotEmpty 
            ? int.tryParse(b.month!) ?? 0 
            : 0;
        
        return bMonth.compareTo(aMonth);
      });
    
    // 연도별로 그룹핑
    final Map<String, List<HistoryItem>> grouped = {};
    for (var item in sortedItems) {
      if (!grouped.containsKey(item.year)) {
        grouped[item.year] = [];
      }
      grouped[item.year]!.add(item);
    }
    
    // 연도순 정렬 (최신순)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedMap = <String, List<HistoryItem>>{};
    for (var key in sortedKeys) {
      // 같은 연도 내에서도 월 순서 유지 (이미 정렬됨)
      sortedMap[key] = grouped[key]!;
    }
    return sortedMap;
  }
}
