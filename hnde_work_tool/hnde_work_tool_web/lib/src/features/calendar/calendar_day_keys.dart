import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../utils/app_date_key.dart';

/// 로컬 달력 기준 `yyyy-MM-dd` (Todo·쿼리와 동일 규칙 — [appDateKeyFromDateTime])
String calendarDayKeyString(DateTime d) => appDateKeyFromDateTime(d);

/// [start]~[end] 구간과 겹치는 모든 로컬 달력 날짜 키 (양 끝 포함 구간)
List<String> calendarDayKeysTouchingInterval(DateTime start, DateTime end) {
  if (end.isBefore(start)) {
    return <String>[];
  }
  final DateTime s = start.isUtc ? start.toLocal() : start;
  final DateTime e = end.isUtc ? end.toLocal() : end;
  final DateFormat fmt = DateFormat('yyyy-MM-dd');
  final List<String> out = <String>[];
  DateTime d = DateTime(s.year, s.month, s.day);
  final DateTime limit = DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
  while (d.isBefore(limit)) {
    final DateTime next = d.add(const Duration(days: 1));
    if (s.isBefore(next) && !e.isBefore(d)) {
      out.add(fmt.format(d));
    }
    d = next;
    if (out.length > 400) {
      break;
    }
  }
  return out;
}

/// 캐시된 일정 문서가 [dayKey](`yyyy-MM-dd`) 날짜와 겹치는지 (`dayKeys` 우선, 없으면 start/end)
bool calendarEventTouchesDayKey(Map<String, dynamic> data, String dayKey) {
  final List<dynamic>? keys = data['dayKeys'] as List<dynamic>?;
  if (keys != null && keys.isNotEmpty) {
    for (final dynamic k in keys) {
      if (k?.toString() == dayKey) {
        return true;
      }
    }
    return false;
  }
  final Timestamp? ts = data['start'] as Timestamp?;
  final Timestamp? te = data['end'] as Timestamp?;
  if (ts == null || te == null) {
    return false;
  }
  final DateTime s = ts.toDate();
  final DateTime e = te.toDate();
  final List<String> parts = dayKey.split('-');
  if (parts.length != 3) {
    return false;
  }
  final int y = int.tryParse(parts[0]) ?? 0;
  final int mo = int.tryParse(parts[1]) ?? 0;
  final int da = int.tryParse(parts[2]) ?? 0;
  final DateTime dayStart = DateTime(y, mo, da);
  final DateTime dayEnd = dayStart.add(const Duration(days: 1));
  return s.isBefore(dayEnd) && !e.isBefore(dayStart);
}
