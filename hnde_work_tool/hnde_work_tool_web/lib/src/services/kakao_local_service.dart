import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/kakao_api_config.dart';

/// 카카오 로컬 API 주소 검색 한 건 결과 (도로명/지번 + WGS84)
class KakaoAddressPick {
  KakaoAddressPick({
    required this.placeName,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
  });

  /// 장소명(키워드 검색) 또는 주소(주소 검색)
  final String placeName;
  /// 도로명/지번 주소
  final String addressLine;
  final double latitude;
  final double longitude;

  /// 기존 코드 호환: 기본 표시/저장 문자열은 주소를 우선합니다.
  String get displayLine =>
      addressLine.trim().isNotEmpty ? addressLine.trim() : placeName.trim();
}

/// 카카오 로컬 API: 주소 검색 + 키워드(장소) 검색
class KakaoLocalService {
  KakaoLocalService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _host = 'dapi.kakao.com';
  static const String _addressPath = '/v2/local/search/address.json';
  static const String _keywordPath = '/v2/local/search/keyword.json';

  Future<List<KakaoAddressPick>> searchAddress(String query) async {
    final String q = query.trim();
    if (q.isEmpty) {
      return <KakaoAddressPick>[];
    }

    // 일반 지도처럼 "장소명/키워드" 검색 결과도 같이 보여준다.
    final List<KakaoAddressPick> keyword = await _searchKeyword(q);
    final List<KakaoAddressPick> address = await _searchAddressOnly(q);

    final List<KakaoAddressPick> merged = <KakaoAddressPick>[];
    final Set<String> seen = <String>{};

    void addAll(List<KakaoAddressPick> src) {
      for (final KakaoAddressPick p in src) {
        final String k =
            '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}|${p.placeName}|${p.addressLine}';
        if (seen.add(k)) merged.add(p);
      }
    }

    addAll(keyword);
    addAll(address);
    return merged;
  }

  Future<List<KakaoAddressPick>> _searchAddressOnly(String q) async {
    final http.Response res = await _get(
      q,
      path: _addressPath,
      proxyUrl: KakaoApiConfig.effectiveAddressProxyUrl,
    );
    final Object? decoded = _decodeJson(res.body);
    if (res.statusCode != 200) {
      // 구버전 Worker일 때 catch-all 404 처리 — 빈 결과 폴백.
      if (res.statusCode == 404 &&
          decoded is Map<String, dynamic> &&
          decoded['error'] == 'not_found') {
        return <KakaoAddressPick>[];
      }
      _throwIfBadResponse(
        res,
        viaProxy: KakaoApiConfig.effectiveAddressProxyUrl.isNotEmpty,
      );
    }
    final List<Map<String, dynamic>> docs = _docs(decoded);
    final List<KakaoAddressPick> out = <KakaoAddressPick>[];
    for (final Map<String, dynamic> m in docs) {
      final KakaoAddressPick? pick = _parseAddressDoc(m);
      if (pick != null) out.add(pick);
    }
    return out;
  }

  Future<List<KakaoAddressPick>> _searchKeyword(String q) async {
    final http.Response res = await _get(
      q,
      path: _keywordPath,
      proxyUrl: KakaoApiConfig.effectiveKeywordProxyUrl,
    );
    final Object? decoded = _decodeJson(res.body);
    if (res.statusCode != 200) {
      // 구버전 Worker(`/v1/kakao/keyword` 미배포)일 때 발생하는 404 catch-all 응답:
      // `{"error":"not_found"}` — 사용자는 주소 검색만 되어도 충분하므로
      // 키워드 결과만 빈 배열로 폴백하고 주소 검색은 계속 진행한다.
      // (해결: `cd cloudflare-worker && npx wrangler deploy`)
      if (res.statusCode == 404 &&
          decoded is Map<String, dynamic> &&
          decoded['error'] == 'not_found') {
        return <KakaoAddressPick>[];
      }
      if (decoded is Map<String, dynamic> &&
          decoded['error'] == 'kakao_upstream') {
        final String body = decoded['kakaoBody']?.toString() ?? '';
        final bool mapLocalOff = body.contains('OPEN_MAP_AND_LOCAL') ||
            body.contains('NotAuthorizedError');
        final String mapLocalHint = mapLocalOff
            ? '카카오 개발자 콘솔(https://developers.kakao.com) → 내 애플리케이션 → '
                '해당 앱 선택 → **제품 설정**에서 **카카오맵 API(지도·로컬)** 사용을 '
                '**활성화(ON)** 하세요.\n'
            : '카카오 개발자 콘솔의 **REST API 키**(JavaScript·네이티브 앱 키 아님)를 '
                '`wrangler secret put KAKAO_REST_API_KEY` 로 넣은 뒤 `npx wrangler deploy` 하세요.\n';
        throw StateError(
          '카카오가 요청을 거부했습니다 (HTTP ${decoded['kakaoStatus']}).\n'
          '$mapLocalHint'
          '상세: $body',
        );
      }
      _throwIfBadResponse(
        res,
        viaProxy: KakaoApiConfig.effectiveKeywordProxyUrl.isNotEmpty,
      );
    }
    final List<Map<String, dynamic>> docs = _docs(decoded);
    final List<KakaoAddressPick> out = <KakaoAddressPick>[];
    for (final Map<String, dynamic> m in docs) {
      final KakaoAddressPick? pick = _parseKeywordDoc(m);
      if (pick != null) out.add(pick);
    }
    return out;
  }

  Future<http.Response> _get(
    String q, {
    required String path,
    required String proxyUrl,
  }) async {
    final bool viaProxy = proxyUrl.trim().isNotEmpty;
    if (viaProxy) {
      final Uri base = Uri.parse(proxyUrl.trim());
      final Uri uri = base.replace(
        queryParameters: <String, String>{
          ...base.queryParameters,
          'query': q,
          'size': '15',
        },
      );
      return _client.get(uri, headers: <String, String>{
        'Accept': 'application/json',
      });
    }
    final String key = KakaoApiConfig.restApiKey;
    if (key.isEmpty) {
      throw StateError(
        '실서버에서 지도 검색을 하려면 Worker 프록시 또는 REST 키가 필요합니다. '
        'env.worker 의 R2_WORKER_URL_PROD(권장) 또는 env.kakao 의 KAKAO_REST_API_KEY 를 설정하세요.',
      );
    }
    final Uri uri = Uri.https(_host, path, <String, String>{
      'query': q,
      'size': '15',
    });
    return _client.get(
      uri,
      headers: <String, String>{
        'Authorization': 'KakaoAK $key',
        'Accept': 'application/json',
      },
    );
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } on Object {
      return null;
    }
  }

  List<Map<String, dynamic>> _docs(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return <Map<String, dynamic>>[];
    final Object? docs = decoded['documents'];
    if (docs is! List) return <Map<String, dynamic>>[];
    return docs.whereType<Map<String, dynamic>>().toList();
  }

  static void _throwIfBadResponse(
    http.Response res, {
    required bool viaProxy,
  }) {
    if (res.statusCode == 200) {
      return;
    }
    if (res.statusCode == 403) {
      if (viaProxy) {
        throw StateError(
          '주소 검색 실패(403). Worker 코드를 반영했는지 `npx wrangler deploy` 했는지, '
          'REST API 키가 맞는지 확인하세요. 응답: ${_trimBody(res.body)}',
        );
      }
      throw StateError(
        '주소 검색이 거부되었습니다(403). env.worker 에 R2_WORKER_URL_PROD 가 있으면 '
        'Worker 프록시를 씁니다. 응답: ${_trimBody(res.body)}',
      );
    }
    throw StateError(
      '주소 검색 실패 (${res.statusCode}) ${_trimBody(res.body)}',
    );
  }

  static String _trimBody(String s) {
    final String t = s.trim();
    if (t.length > 280) {
      return '${t.substring(0, 280)}…';
    }
    return t;
  }

  KakaoAddressPick? _parseAddressDoc(Map<String, dynamic> m) {
    final double? lat = _parseCoord(m['y']);
    final double? lng = _parseCoord(m['x']);
    if (lat == null || lng == null) {
      return null;
    }
    final String addr = _addressLineFromAddressDoc(m);
    if (addr.isEmpty) {
      return null;
    }
    return KakaoAddressPick(
      placeName: addr,
      addressLine: addr,
      latitude: lat,
      longitude: lng,
    );
  }

  KakaoAddressPick? _parseKeywordDoc(Map<String, dynamic> m) {
    final double? lat = _parseCoord(m['y']);
    final double? lng = _parseCoord(m['x']);
    if (lat == null || lng == null) {
      return null;
    }
    final String name = (m['place_name'] as String?)?.trim() ?? '';
    final String road = (m['road_address_name'] as String?)?.trim() ?? '';
    final String jibun = (m['address_name'] as String?)?.trim() ?? '';
    final String addr = road.isNotEmpty ? road : jibun;
    if (name.isEmpty && addr.isEmpty) return null;
    return KakaoAddressPick(
      placeName: name.isEmpty ? addr : name,
      addressLine: addr.isEmpty ? name : addr,
      latitude: lat,
      longitude: lng,
    );
  }

  static String _addressLineFromAddressDoc(Map<String, dynamic> m) {
    final Object? road = m['road_address'];
    if (road is Map<String, dynamic>) {
      final String? n = road['address_name'] as String?;
      if (n != null && n.trim().isNotEmpty) {
        return n.trim();
      }
    }
    final String? jibun = m['address_name'] as String?;
    if (jibun != null && jibun.trim().isNotEmpty) {
      return jibun.trim();
    }
    return '';
  }

  static double? _parseCoord(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      return double.tryParse(v.trim());
    }
    return null;
  }
}
