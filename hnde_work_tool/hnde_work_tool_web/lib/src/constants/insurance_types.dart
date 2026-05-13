/// 4대보험 종류 및 Firestore 필드명
class InsuranceTypes {
  InsuranceTypes._();

  static const String national = 'national'; // 국민연금
  static const String health = 'health'; // 건강보험
  static const String employment = 'employment'; // 고용보험
  static const String industrial = 'industrial'; // 산재보험

  static const List<String> all = <String>[
    national,
    health,
    employment,
    industrial,
  ];

  static String label(String key) {
    switch (key) {
      case national:
        return '국민';
      case health:
        return '건강';
      case employment:
        return '고용';
      case industrial:
        return '산재';
      default:
        return key;
    }
  }

  /// 컬럼 헤더용 전체명 (예: 국민연금, 건강보험)
  static String fullLabel(String key) {
    switch (key) {
      case national:
        return '국민연금';
      case health:
        return '건강보험';
      case employment:
        return '고용보험';
      case industrial:
        return '산재보험';
      default:
        return label(key);
    }
  }

  /// 취득일 필드명
  static String acquiredField(String key) => '${key}AcquiredDate';

  /// 상실일 필드명
  static String lossField(String key) => '${key}LossDate';
}
