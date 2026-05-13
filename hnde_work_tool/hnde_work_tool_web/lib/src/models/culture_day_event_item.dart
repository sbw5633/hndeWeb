/// 관리자 AI 파이프라인이 Firestore에 올려 둔 **문화의 날 행사 1건**.
///
/// 필드명은 외부(n8n/스크립트)에서 유연하게 넣을 수 있도록 여러 별칭을 허용합니다.
class CultureDayEventItem {
  const CultureDayEventItem({
    required this.id,
    required this.title,
    this.summary,
    this.venue,
    this.region,
    this.startDate,
    this.endDate,
    this.imageUrl,
    this.detailUrl,
    this.tags,
  });

  final String id;
  final String title;
  final String? summary;
  final String? venue;
  final String? region;
  /// yyyyMMdd 또는 자유 문자열
  final String? startDate;
  final String? endDate;
  final String? imageUrl;
  final String? detailUrl;
  final List<String>? tags;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        if (summary != null) 'summary': summary,
        if (venue != null) 'venue': venue,
        if (region != null) 'region': region,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (detailUrl != null) 'detailUrl': detailUrl,
        if (tags != null) 'tags': tags,
      };

  static CultureDayEventItem? tryFromMap(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    final String id = _str(m['id'] ?? m['eventId'] ?? m['contentId']) ?? '';
    final String title = _str(m['title'] ?? m['name']) ?? '';
    if (id.isEmpty || title.isEmpty) {
      return null;
    }
    return CultureDayEventItem(
      id: id,
      title: title,
      summary: _str(m['summary'] ?? m['overview'] ?? m['description']),
      venue: _str(m['venue'] ?? m['place'] ?? m['location']),
      region: _str(m['region'] ?? m['area'] ?? m['addr']),
      startDate: _str(
        m['startDate'] ??
            m['startdate'] ??
            m['eventstartdate'] ??
            m['eventStartDate'],
      ),
      endDate: _str(
        m['endDate'] ?? m['enddate'] ?? m['eventenddate'] ?? m['eventEndDate'],
      ),
      imageUrl: _str(
        m['imageUrl'] ??
            m['image'] ??
            m['firstImage'] ??
            m['firstimage'] ??
            m['thumbUrl'],
      ),
      detailUrl: _str(m['detailUrl'] ?? m['url'] ?? m['link'] ?? m['homepage']),
      tags: _stringList(m['tags'] ?? m['keyword']),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) {
      return null;
    }
    final String s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String>? _stringList(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is List) {
      final List<String> out = <String>[];
      for (final dynamic e in v) {
        final String? s = _str(e);
        if (s != null) {
          out.add(s);
        }
      }
      return out.isEmpty ? null : out;
    }
    final String? s = _str(v);
    return s == null ? null : <String>[s];
  }
}
