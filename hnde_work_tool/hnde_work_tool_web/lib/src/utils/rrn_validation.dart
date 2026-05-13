import 'package:flutter/services.dart';

/// 숫자+하이픈만 허용
List<TextInputFormatter> get digitHyphenFormatters => <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
];

/// 주민등록번호 유효성 검사 (형식 + 체크섬)
String? validateRrn(String? value) {
  if (value == null || value.trim().isEmpty) return '주민등록번호를 입력해 주세요.';
  final String s = value.replaceAll('-', '').replaceAll(' ', '');
  if (s.length != 13) return '주민등록번호는 13자리여야 합니다.';
  if (!RegExp(r'^\d{13}$').hasMatch(s)) return '숫자만 입력해 주세요.';

  final List<int> digits = s.split('').map((String c) => int.parse(c)).toList();
  const List<int> weights = <int>[2, 3, 4, 5, 6, 7, 8, 9, 2, 3, 4, 5];
  int sum = 0;
  for (int i = 0; i < 12; i++) {
    sum += digits[i] * weights[i];
  }
  int check = 11 - (sum % 11);
  if (check >= 10) check -= 10;
  if (digits[12] != check) return '유효하지 않은 주민등록번호입니다.';

  return null;
}

String formatRrn(String s) {
  final String cleaned = s.replaceAll(RegExp(r'\D'), '');
  if (cleaned.length <= 6) return cleaned;
  return '${cleaned.substring(0, 6)}-${cleaned.substring(6)}';
}
