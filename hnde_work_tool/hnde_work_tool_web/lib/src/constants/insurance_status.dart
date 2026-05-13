import 'package:cloud_firestore/cloud_firestore.dart';

import 'insurance_types.dart';

/// 4대보험 가입자명부 상태 (날짜 기반 파생)
///
/// - 취득: 취득일 있음, 상실일 없음 (현재 가입 중)
/// - 상실: 상실일이 오늘 이전 (보험 상실)
/// - 퇴사: 퇴사일이 오늘 이전 (퇴사)
class InsuranceStatus {
  InsuranceStatus._();

  static const String acquired = '취득';
  static const String lost = '상실';
  static const String resigned = '퇴사';

  /// Firestore dynamic → String
  static String? _str(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.trim().isEmpty ? null : v.trim();
    if (v is Timestamp) {
      final DateTime dt = v.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    if (v is DateTime) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    final String s = v.toString();
    return s.trim().isEmpty ? null : s.trim();
  }

  /// 날짜 파싱 (YYYY-MM-DD, YYYY.MM.DD, YYYYMMDD)
  static DateTime? _parseDate(String? s) {
    final String? t = _str(s);
    if (t == null || t.isEmpty) return null;
    try {
      if (RegExp(r'^\d{8}$').hasMatch(t)) {
        final int y = int.parse(t.substring(0, 4));
        final int m = int.parse(t.substring(4, 6));
        final int d = int.parse(t.substring(6, 8));
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
      final List<String> parts = t.split(RegExp(r'[-/.\s]'));
      if (parts.length < 3) return null;
      int? y, m, d;
      if (parts[0].length == 4) {
        y = int.tryParse(parts[0]);
        m = int.tryParse(parts[1]);
        d = int.tryParse(parts[2]);
      } else if (parts[2].length == 4) {
        y = int.tryParse(parts[2]);
        m = int.tryParse(parts[1]);
        d = int.tryParse(parts[0]);
      }
      if (y == null || m == null || d == null) return null;
      if (y < 1900 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
        return null;
      }
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  /// 오늘 이전인지 (오늘 포함, 미래 제외)
  static bool _isOnOrBeforeToday(DateTime? dt) {
    if (dt == null) return false;
    final DateTime today = DateTime.now();
    final DateTime todayStart = DateTime(today.year, today.month, today.day);
    final DateTime dtNorm = DateTime(dt.year, dt.month, dt.day);
    return dtNorm.isBefore(todayStart) || dtNorm.isAtSameMomentAs(todayStart);
  }

  /// Map에서 직접 파생 (Firestore 타입 호환)
  /// 새 구조(nationalAcquiredDate 등) 및 구구조(acquiredDate) 모두 지원
  static String deriveFromMap(Map<String, dynamic> data) {
    final String? resignationDate = _str(data['resignationDate']);
    final DateTime? resDt = _parseDate(resignationDate);
    if (resignationDate != null &&
        resignationDate.isNotEmpty &&
        resDt != null &&
        _isOnOrBeforeToday(resDt)) {
      return resigned;
    }

    // 새 구조: 4대보험별 취득/상실
    bool anyAcquired = false;
    bool anyLost = false;
    for (final key in InsuranceTypes.all) {
      final String? a = _str(data[InsuranceTypes.acquiredField(key)]);
      final String? l = _str(data[InsuranceTypes.lossField(key)]);
      final bool hasA = a != null && a.isNotEmpty;
      final bool hasL = l != null && l.isNotEmpty;
      if (hasA && !hasL) anyAcquired = true;
      if (hasL) {
        final DateTime? lossDt = _parseDate(l);
        if (lossDt != null && _isOnOrBeforeToday(lossDt)) anyLost = true;
      }
    }

    if (anyLost) return lost;
    if (anyAcquired) return acquired;

    // 구구조 호환
    final String? acquiredDate = _str(data['acquiredDate']);
    final String? lossDate = _str(data['lossDate']);
    return derive(
      acquiredDate: acquiredDate,
      lossDate: lossDate,
      resignationDate: resignationDate,
    );
  }

  /// 취득일·상실일·퇴사일로 상태 파생
  static String derive({
    required String? acquiredDate,
    required String? lossDate,
    required String? resignationDate,
  }) {
    final String? a = _str(acquiredDate);
    final String? l = _str(lossDate);
    final String? r = _str(resignationDate);

    final bool hasAcquired = a != null && a.isNotEmpty;
    final bool hasLoss = l != null && l.isNotEmpty;
    final bool hasResignation = r != null && r.isNotEmpty;

    final DateTime? lossDt = _parseDate(l);
    final DateTime? resDt = _parseDate(r);

    // 퇴사: 퇴사일이 있으면 우선 (오늘 이전)
    if (hasResignation) {
      if (resDt != null && _isOnOrBeforeToday(resDt)) return resigned;
    }
    // 상실: 상실일이 오늘 이전
    if (hasLoss) {
      if (lossDt != null && _isOnOrBeforeToday(lossDt)) return lost;
    }
    // 취득: 취득일 있고 상실일 없음
    if (hasAcquired && !hasLoss) return acquired;
    // 상실일/퇴사일 있음(파싱 실패 시에도) → 해당 상태 (퇴사 우선)
    if (hasResignation) return resigned;
    if (hasLoss) return lost;
    if (hasAcquired) return acquired;
    return acquired;
  }

  static bool isAcquired(String label) => label == acquired;
  static bool isLost(String label) => label == lost;
  static bool isResigned(String label) => label == resigned;
}
