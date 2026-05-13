import 'dart:convert';

import 'tour_image_item.dart';

class TourDetailBundle {
  const TourDetailBundle({
    required this.contentId,
    required this.common,
    required this.intro,
    required this.images,
    this.requestUrlDetailCommon2,
    this.requestUrlDetailIntro2,
    this.requestUrlDetailImage2,
  });

  final String contentId;
  final Map<String, dynamic>? common;
  final Map<String, dynamic>? intro;
  final List<TourImageItem> images;

  /// 앱이 실제로 호출한 GET URL (복사·디버그용). `serviceKey`는 직접 호출 시 플레이스홀더.
  final String? requestUrlDetailCommon2;
  final String? requestUrlDetailIntro2;
  final String? requestUrlDetailImage2;

  String? get title => _str(common?['title']);
  String? get overview => _str(common?['overview']);
  /// [detailCommon2] 대표 이미지 (매뉴얼 `firstimage` 외 `originimgurl` 등 변형 필드 포함)
  String? get firstImage => _str(
        common?['firstimage'] ??
            common?['firstImage'] ??
            common?['originimgurl'] ??
            common?['originImgUrl'] ??
            common?['img'],
      );
  String? get firstImage2 => _str(
        common?['firstimage2'] ??
            common?['firstImage2'] ??
            common?['smallimageurl'] ??
            common?['smallImageUrl'],
      );
  /// [detailCommon2] 약도(위치도) — `mapinfoYN=Y` 일 때 제공되는 경우가 많음
  String? get mapImage => _str(
        common?['mapimage'] ??
            common?['mapImage'] ??
            common?['mapimgurl'] ??
            common?['mapImgUrl'] ??
            common?['direction'] ??
            common?['treatmap'] ??
            common?['treatMap'],
      );

  /// 상단 히어로·썸네일 후보 (대표 → 보조)
  String? get representativeImageUrl =>
      _nonEmpty(firstImage) ?? _nonEmpty(firstImage2);

  String? get addr1 => _str(common?['addr1'] ?? common?['addr']);
  String? get addr2 => _str(common?['addr2']);
  String? get addrCombined {
    final String? a1 = addr1;
    final String? a2 = addr2;
    if ((a1 == null || a1.isEmpty) && (a2 == null || a2.isEmpty)) {
      return null;
    }
    if (a1 == null || a1.isEmpty) {
      return a2;
    }
    if (a2 == null || a2.isEmpty) {
      return a1;
    }
    return '$a1 $a2';
  }

  String? get tel => _str(common?['tel'] ?? common?['Tel']);
  String? get homepage => _str(common?['homepage'] ?? common?['homePage']);
  String? get zipcode => _str(common?['zipcode'] ?? common?['zipCode']);

  static String? _nonEmpty(String? s) {
    if (s == null) return null;
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final String s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'contentId': contentId,
      if (common != null) 'common': common,
      if (intro != null) 'intro': intro,
      'images': images.map((TourImageItem e) => e.toJson()).toList(),
      if (requestUrlDetailCommon2 != null)
        'requestUrlDetailCommon2': requestUrlDetailCommon2,
      if (requestUrlDetailIntro2 != null)
        'requestUrlDetailIntro2': requestUrlDetailIntro2,
      if (requestUrlDetailImage2 != null)
        'requestUrlDetailImage2': requestUrlDetailImage2,
    };
  }

  factory TourDetailBundle.fromJson(Map<String, dynamic> j) {
    final List<dynamic>? rawImgs = j['images'] as List<dynamic>?;
    final List<TourImageItem> imgs = <TourImageItem>[];
    if (rawImgs != null) {
      for (final dynamic e in rawImgs) {
        if (e is Map<String, dynamic>) {
          imgs.add(TourImageItem.fromJson(e));
        }
      }
    }
    return TourDetailBundle(
      contentId: '${j['contentId'] ?? ''}',
      common: j['common'] != null
          ? Map<String, dynamic>.from(j['common'] as Map)
          : null,
      intro: j['intro'] != null
          ? Map<String, dynamic>.from(j['intro'] as Map)
          : null,
      images: imgs,
      requestUrlDetailCommon2: j['requestUrlDetailCommon2'] as String?,
      requestUrlDetailIntro2: j['requestUrlDetailIntro2'] as String?,
      requestUrlDetailImage2: j['requestUrlDetailImage2'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}

