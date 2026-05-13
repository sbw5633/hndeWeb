import '../extensions/string_html_extension.dart';

/// `detailCommon2` + `detailIntro2` (문화시설) 병합 결과
class CultureDetail {
  const CultureDetail({
    required this.contentId,
    this.title,
    this.overview,
    this.usetime,
    this.usefee,
    this.restdate,
    this.infocenterculture,
    this.parkingculture,
    this.firstImage,
  });

  final String contentId;
  final String? title;
  final String? overview;
  final String? usetime;
  final String? usefee;
  final String? restdate;
  final String? infocenterculture;
  final String? parkingculture;
  final String? firstImage;

  String? get overviewPlain =>
      overview?.stripHtml();
  String? get usetimePlain => usetime?.stripHtml();
  String? get usefeePlain => usefee?.stripHtml();
  String? get restdatePlain => restdate?.stripHtml();
  String? get infocenterPlain => infocenterculture?.stripHtml();
  String? get parkingPlain => parkingculture?.stripHtml();

  static CultureDetail merge({
    required String contentId,
    Map<String, dynamic>? common,
    Map<String, dynamic>? intro,
  }) {
    String? tit;
    String? ov;
    String? fi;
    if (common != null) {
      tit = _str(common['title']);
      ov = _str(common['overview']);
      fi = _str(
        common['firstimage'] ??
            common['firstImage'] ??
            common['firstimage2'] ??
            common['firstImage2'] ??
            common['originimgurl'] ??
            common['originImgUrl'] ??
            common['smallimageurl'] ??
            common['smallImageUrl'] ??
            common['img'],
      );
    }
    String? ut;
    String? uf;
    String? rd;
    String? info;
    String? pk;
    if (intro != null) {
      ut = _str(intro['usetime']);
      uf = _str(intro['usefee']);
      rd = _str(intro['restdate']);
      info = _str(intro['infocenterculture']);
      pk = _str(intro['parkingculture']);
    }
    return CultureDetail(
      contentId: contentId,
      title: tit,
      overview: ov,
      usetime: ut,
      usefee: uf,
      restdate: rd,
      infocenterculture: info,
      parkingculture: pk,
      firstImage: fi,
    );
  }

  static String? _str(dynamic v) {
    if (v == null) {
      return null;
    }
    final String s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
