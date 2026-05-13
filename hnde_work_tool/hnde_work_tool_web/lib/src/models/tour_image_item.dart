import 'package:flutter/foundation.dart' show kIsWeb;

class TourImageItem {
  const TourImageItem({
    required this.originUrl,
    this.smallUrl,
    this.serialNum,
    this.cpyrhtDivCd,
  });

  final String originUrl;
  final String? smallUrl;
  final String? serialNum;
  final String? cpyrhtDivCd;

  static TourImageItem? tryFromJson(Map<String, dynamic> j) {
    String origin = _pickUrl(j, const <String>[
      'originimgurl',
      'originImgUrl',
      'img',
      'imageurl',
      'imageUrl',
    ]);
    String small = _pickUrl(j, const <String>[
      'smallimageurl',
      'smallImageUrl',
      'smallimageurl2',
      'smallImageUrl2',
    ]);
    origin = _normalizeHttpUrl(origin);
    small = _normalizeHttpUrl(small);
    if (origin.isEmpty && small.isEmpty) {
      return null;
    }
    if (origin.isEmpty) {
      origin = small;
    }
    final String serial = '${j['serialnum'] ?? j['serialNum'] ?? ''}'.trim();
    final String cp = '${j['cpyrhtDivCd'] ?? ''}'.trim();
    return TourImageItem(
      originUrl: origin,
      smallUrl: small.isEmpty ? null : small,
      serialNum: serial.isEmpty ? null : serial,
      cpyrhtDivCd: cp.isEmpty ? null : cp,
    );
  }

  static String _pickUrl(Map<String, dynamic> j, List<String> keys) {
    for (final String k in keys) {
      final Object? v = j[k] ?? j[k.toLowerCase()];
      if (v == null) continue;
      final String s = v.toString().trim();
      if (s.isNotEmpty) {
        return s;
      }
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'originUrl': originUrl,
      if (smallUrl != null) 'smallUrl': smallUrl,
      if (serialNum != null) 'serialNum': serialNum,
      if (cpyrhtDivCd != null) 'cpyrhtDivCd': cpyrhtDivCd,
    };
  }

  static TourImageItem fromJson(Map<String, dynamic> j) {
    final String? su = j['smallUrl'] as String?;
    final String? suT = su?.trim();
    return TourImageItem(
      originUrl: '${j['originUrl'] ?? ''}',
      smallUrl: (suT != null && suT.isNotEmpty) ? su : null,
      serialNum: j['serialNum'] as String?,
      cpyrhtDivCd: j['cpyrhtDivCd'] as String?,
    );
  }

  static String _normalizeHttpUrl(String raw) {
    String s = raw.trim();
    if (s.isEmpty) {
      return '';
    }
    s = s.replaceAll('&amp;', '&');
    if (s.startsWith('//')) {
      s = 'https:$s';
    }
    if (kIsWeb && s.startsWith('http://')) {
      return 'https://${s.substring(7)}';
    }
    return s;
  }
}

