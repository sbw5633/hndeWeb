/// TourAPI KorService2 공통 목록 아이템 (location/searchFestival/searchKeyword 등)
class TourItem {
  const TourItem({
    required this.contentId,
    required this.title,
    required this.contentTypeId,
    this.firstImage,
    this.firstImage2,
    this.addr1,
    this.mapX,
    this.mapY,
    this.distMeters,
    this.eventStartDate,
    this.eventEndDate,
  });

  final String contentId;
  final String title;
  /// contentTypeId: 관광지12/문화시설14/행사15/코스25/레포츠28/숙박32/쇼핑38/음식39
  final int contentTypeId;

  final String? firstImage;
  final String? firstImage2;
  final String? addr1;
  final double? mapX;
  final double? mapY;
  /// API dist (m). 소수 문자열로 올 수 있어 반올림 처리.
  final int? distMeters;

  /// 행사(15)일 때 주로 제공: yyyyMMdd
  final String? eventStartDate;
  final String? eventEndDate;

  bool get isEvent => contentTypeId == 15;

  static TourItem? tryFromJson(Map<String, dynamic> j) {
    final String id = '${j['contentid'] ?? j['contentId'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    final String title = '${j['title'] ?? ''}'.trim().replaceAll('&amp;', '&');
    if (title.isEmpty) return null;

    final int? ctid = _intStrict(j['contenttypeid'] ?? j['contentTypeId']);
    if (ctid == null) return null;

    return TourItem(
      contentId: id,
      title: title,
      contentTypeId: ctid,
      firstImage: _str(
        j['firstimage'] ??
            j['firstImage'] ??
            j['originimgurl'] ??
            j['originImgUrl'] ??
            j['img'],
      ),
      firstImage2: _str(
        j['firstimage2'] ??
            j['firstImage2'] ??
            j['smallimageurl'] ??
            j['smallImageUrl'],
      ),
      addr1: _str(j['addr1'] ?? j['addr']),
      // searchFestival2 등: 보통 mapx=경도·mapy=위도. 일부 필드명 변형 대비.
      mapX: _double(
        j['mapx'] ??
            j['mapX'] ??
            j['longitude'] ??
            j['lng'] ??
            j['lon'],
      ),
      mapY: _double(
        j['mapy'] ??
            j['mapY'] ??
            j['latitude'] ??
            j['lat'],
      ),
      distMeters: _intLoosely(j['dist']),
      eventStartDate: _str(j['eventstartdate'] ?? j['eventStartDate']),
      eventEndDate: _str(j['eventenddate'] ?? j['eventEndDate']),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final String s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _intStrict(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString().trim());
  }

  static int? _intLoosely(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    final String s = v.toString().trim();
    if (s.isEmpty) return null;
    final double? d = double.tryParse(s);
    if (d != null) return d.round();
    return int.tryParse(s);
  }

  static double? _double(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }
}

