import 'package:cloud_firestore/cloud_firestore.dart';

/// Todo 문서 `type` 필드 값
abstract final class TodoTypes {
  static const String custom = 'custom';
  static const String calendar = 'calendar';
}

/// 사용자 Todo. 논리 건당 문서 1개 — 기간은 [dateKeys] 배열.
class TodoItemModel {
  const TodoItemModel({
    required this.id,
    required this.title,
    required this.dateKeys,
    this.completed = false,
    this.timeStr = '',
    this.type = TodoTypes.custom,
    this.linkedCalendarEventId,
    this.detail = '',
    this.createdAt,
    this.userId = '',
  });

  final String id;
  final String title;
  /// 세부 내용(여러 줄)
  final String detail;
  /// 포함 날짜 `yyyy-MM-dd` (정렬됨). 하루만이면 길이 1.
  final List<String> dateKeys;
  final bool completed;
  final String timeStr;
  final String type;
  final String? linkedCalendarEventId;
  final Timestamp? createdAt;
  final String userId;

  /// 하위 호환·단일 날짜 표시용 (첫 날)
  String get primaryDateKey => dateKeys.isNotEmpty ? dateKeys.first : '';

  factory TodoItemModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    final List<String> keys = _parseDateKeys(d);
    return TodoItemModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      dateKeys: keys,
      completed: d['completed'] as bool? ?? false,
      timeStr: d['timeStr'] as String? ?? '',
      type: d['type'] as String? ?? TodoTypes.custom,
      linkedCalendarEventId: d['linkedCalendarEventId'] as String?,
      detail: d['detail'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp?,
      userId: d['userId'] as String? ?? '',
    );
  }

  static List<String> _parseDateKeys(Map<String, dynamic> d) {
    final List<dynamic>? raw = d['dateKeys'] as List<dynamic>?;
    if (raw != null && raw.isNotEmpty) {
      final List<String> keys = raw
          .map((dynamic e) => e?.toString().trim() ?? '')
          .where((String s) => s.isNotEmpty)
          .toList();
      keys.sort();
      return keys;
    }
    final String? legacy = d['dateKey'] as String?;
    if (legacy != null && legacy.isNotEmpty) {
      return <String>[legacy];
    }
    return <String>[];
  }

  Map<String, dynamic> toWriteMap(String uid) {
    return <String, dynamic>{
      'title': title,
      'detail': detail,
      'dateKeys': dateKeys,
      'completed': completed,
      'timeStr': timeStr,
      'type': type,
      'linkedCalendarEventId': linkedCalendarEventId,
      'userId': uid,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  TodoItemModel copyWith({
    String? title,
    List<String>? dateKeys,
    bool? completed,
    String? timeStr,
    String? type,
    String? linkedCalendarEventId,
    String? detail,
  }) {
    return TodoItemModel(
      id: id,
      title: title ?? this.title,
      dateKeys: dateKeys ?? this.dateKeys,
      completed: completed ?? this.completed,
      timeStr: timeStr ?? this.timeStr,
      type: type ?? this.type,
      linkedCalendarEventId:
          linkedCalendarEventId ?? this.linkedCalendarEventId,
      detail: detail ?? this.detail,
      createdAt: createdAt,
      userId: userId,
    );
  }
}
