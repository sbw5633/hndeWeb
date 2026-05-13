import 'package:intl/intl.dart';

/// 앱 전역 `yyyy-MM-dd` 키 (Todo·캘린더 dayKeys와 동일 규칙)
String appDateKeyFromDateTime(DateTime d) {
  final DateTime x = d.isUtc ? d.toLocal() : d;
  final DateTime day = DateTime(x.year, x.month, x.day);
  return DateFormat('yyyy-MM-dd').format(day);
}
