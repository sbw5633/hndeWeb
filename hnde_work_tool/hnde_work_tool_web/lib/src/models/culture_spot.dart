/// TourAPI `locationBasedList2` 목록 항목 (문화시설 contentTypeId=14)
class CultureSpot {
  const CultureSpot({
    required this.contentId,
    required this.title,
    this.firstImage,
    this.addr1,
    this.distMeters,
    this.mapX,
    this.mapY,
  });

  final String contentId;
  final String title;
  final String? firstImage;
  final String? addr1;
  /// API `dist` (m)
  final int? distMeters;
  final double? mapX;
  final double? mapY;

  static CultureSpot? tryFromJson(Map<String, dynamic> j) {
    final String id = '${j['contentid'] ?? j['contentId'] ?? ''}'.trim();
    if (id.isEmpty) {
      return null;
    }
    final String title =
        '${j['title'] ?? ''}'.trim().replaceAll('&amp;', '&');
    if (title.isEmpty) {
      return null;
    }
    final String? img = _str(j['firstimage'] ?? j['firstImage']);
    final String? addr = _str(j['addr1'] ?? j['addr']);
    final int? dist = _int(j['dist']);
    final double? mx = _double(j['mapx'] ?? j['mapX']);
    final double? my = _double(j['mapy'] ?? j['mapY']);
    return CultureSpot(
      contentId: id,
      title: title,
      firstImage: img,
      addr1: addr,
      distMeters: dist,
      mapX: mx,
      mapY: my,
    );
  }

  static String? _str(dynamic v) {
    if (v == null) {
      return null;
    }
    final String s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is int) {
      return v;
    }
    if (v is double) {
      return v.round();
    }
    final String s = v.toString().trim();
    if (s.isEmpty) {
      return null;
    }
    // KorService2 `dist`는 소수 문자열로 오는 경우가 많음 (예: "744.4687...")
    final double? d = double.tryParse(s);
    if (d != null) {
      return d.round();
    }
    return int.tryParse(s);
  }

  static double? _double(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is double) {
      return v;
    }
    if (v is int) {
      return v.toDouble();
    }
    return double.tryParse(v.toString().trim());
  }
}
