import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/tour_api_config.dart';
import '../../config/secrets.dart';
import '../models/culture_detail.dart';
import '../models/culture_spot.dart';
import '../models/tour_image_item.dart';
import '../models/tour_item.dart';
import '../models/tour_detail_bundle.dart';

class PublicDataException implements Exception {
  PublicDataException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 한국관광공사 TourAPI 4.0 KorService2 (http JSON)
///
/// 웹 브라우저에서는 공공 API CORS 정책으로 직접 호출이 막힐 수 있습니다.
/// 그 경우 백엔드 프록시 또는 `--web-browser-flag` 환경에서만 테스트하세요.
class PublicDataService {
  PublicDataService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const int _cultureTypeId = 14;

  /// 기본 행사 기간: 오늘 ~ 1개월
  static DateTimeRange defaultEventRange() {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final DateTime end = DateTime(start.year, start.month + 1, start.day);
    return DateTimeRange(start: start, end: end);
  }

  static String _yyyymmdd(DateTime d) {
    final int y = d.year;
    final String m = d.month.toString().padLeft(2, '0');
    final String dd = d.day.toString().padLeft(2, '0');
    return '$y$m$dd';
  }

  /// TourAPI 이미지 URL 정리 (공백·`//`·`&amp;` 등). 웹에서는 혼합 콘텐츠 방지로 http→https.
  static String? normalizeTourMediaUrl(String? raw) {
    if (raw == null) {
      return null;
    }
    String s = raw.trim();
    if (s.isEmpty) {
      return null;
    }
    s = s.replaceAll('&amp;', '&');
    if (s.startsWith('//')) {
      s = 'https:$s';
    }
    // 이미 Worker 프록시/우리 API URL이면 그대로 사용 (이중 프록시 방지)
    if (kIsWeb && Secrets.isR2Configured) {
      final String base =
          Secrets.effectiveR2WorkerUrl.replaceAll(RegExp(r'/$'), '');
      if (s.startsWith('$base/v1/tour/media?url=')) {
        return s;
      }
      if (s.startsWith('$base/v1/')) {
        return s;
      }
    }
    // Flutter Web: http 혼합콘텐츠/CORS로 이미지가 깨지는 경우가 있어 Worker 프록시를 우선 사용
    if (kIsWeb && Secrets.isR2Configured) {
      if (s.startsWith('http://') || s.startsWith('https://')) {
        final String base =
            Secrets.effectiveR2WorkerUrl.replaceAll(RegExp(r'/$'), '');
        final String enc = Uri.encodeComponent(s);
        return '$base/v1/tour/media?url=$enc';
      }
    }
    if (kIsWeb && s.startsWith('http://')) {
      return 'https://${s.substring(7)}';
    }
    return s;
  }

  static String _workerTourKorUrl(String endpoint) {
    final String base = Secrets.effectiveR2WorkerUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/v1/tour/kor/$endpoint';
  }

  Future<Map<String, dynamic>> _korService2Get(
    String endpoint,
    Map<String, String> queryParams,
    String errorLabel,
  ) async {
    final http.Response res;
    if (kIsWeb && Secrets.isR2Configured) {
      final Uri uri = Uri.parse(_workerTourKorUrl(endpoint))
          .replace(queryParameters: queryParams);
      res = await _client.get(uri, headers: const <String, String>{
        'Accept': 'application/json',
      });
    } else {
      final Uri uri = Uri.https(
        TourApiConfig.baseHost,
        '${TourApiConfig.korServicePath}/$endpoint',
        <String, String>{
          ...queryParams,
          'serviceKey': TourApiConfig.serviceKey,
        },
      );
      res = await _client.get(uri);
    }
    _throwIfBadHttp(res, errorLabel);
    final Map<String, dynamic> root =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _throwIfHeaderError(root);
    return root;
  }

  static int _bodyTotalCount(dynamic body) {
    if (body is! Map) {
      return 0;
    }
    final Object? v = body['totalCount'];
    if (v == null) {
      return 0;
    }
    if (v is int) {
      return v;
    }
    if (v is String) {
      return int.tryParse(v) ?? 0;
    }
    return int.tryParse(v.toString()) ?? 0;
  }

  static List<TourItem> _tourItemsFromRoot(Map<String, dynamic> root) {
    final List<Map<String, dynamic>> rawItems =
        _itemsFromBody(root['response']?['body']);
    final List<TourItem> out = <TourItem>[];
    for (final Map<String, dynamic> j in rawItems) {
      final TourItem? it = TourItem.tryFromJson(j);
      if (it != null) {
        out.add(it);
      }
    }
    return out;
  }

  /// Worker가 반환한 `tour_upstream` / `tour_not_configured` 등을 사람이 읽을 수 있게
  static void _throwIfBadHttp(http.Response res, String label) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final String err = '${decoded['error'] ?? ''}'.trim();
        if (err == 'tour_not_configured') {
          throw PublicDataException(
            '$label 실패: Worker에 TOUR_API_SERVICE_KEY 가 없습니다. '
            'cloudflare-worker 에서 `wrangler secret put TOUR_API_SERVICE_KEY` 후 '
            '`npx wrangler deploy` 하세요.',
          );
        }
        if (err == 'tour_upstream') {
          final Object? st = decoded['tourStatus'];
          final Object? body = decoded['tourBody'];
          throw PublicDataException(
            '$label 실패: TourAPI(공공데이터)가 HTTP $st 로 응답했습니다. '
            '(엔드포인트는 「국문 관광정보 서비스_GW」와 동일한 B551011/KorService2 입니다.) '
            '500·502는 공공 API 쪽 일시 오류인 경우가 많습니다. 잠시 후 다시 시도하거나, '
            '포털에서 키·일일 한도·활용신청 상태를 확인하세요.\n'
            '본문: $body',
          );
        }
      }
    } on PublicDataException {
      rethrow;
    } on Object {
      // JSON 아님
    }
    String bodyHint = '';
    try {
      bodyHint = res.bodyBytes.isEmpty
          ? ''
          : utf8.decode(res.bodyBytes).trim().replaceAll(RegExp(r'\s+'), ' ');
    } on Object {
      bodyHint = '';
    }
    final String tail = bodyHint.length > 200
        ? '${bodyHint.substring(0, 200)}…'
        : bodyHint;
    if (tail.isNotEmpty) {
      throw PublicDataException(
        '$label 실패 (HTTP ${res.statusCode})\n$tail',
      );
    }
    throw PublicDataException('$label 실패 (HTTP ${res.statusCode})');
  }

  /// [mapX] 경도, [mapY] 위도 (WGS84)
  /// [radiusMeters] API 상한에 맞춰 최대 20000m 권장
  Future<List<CultureSpot>> fetchNearbySpots(
    double mapX,
    double mapY, {
    int radiusMeters = 2000,
    int numOfRows = 100,
    int pageNo = 1,
  }) async {
    final int r = radiusMeters.clamp(500, 20000);
    final Map<String, String> qp = <String, String>{
      'mapX': mapX.toString(),
      'mapY': mapY.toString(),
      'radius': '$r',
      'contentTypeId': '$_cultureTypeId',
      '_type': 'json',
      'MobileOS': 'ETC',
      'MobileApp': 'HndeWorkTool',
      'arrange': 'E',
      'numOfRows': '$numOfRows',
      'pageNo': '$pageNo',
    };

    final http.Response res;
    if (kIsWeb && Secrets.isR2Configured) {
      // 웹: CORS 회피용 Worker 프록시 (Worker가 serviceKey를 주입)
      final Uri uri = Uri.parse(_workerTourKorUrl('locationBasedList2'))
          .replace(queryParameters: qp);
      res = await _client.get(uri, headers: const <String, String>{
        'Accept': 'application/json',
      });
    } else {
      // 모바일/데스크톱: 직접 호출 (dart-define 키 필요)
      final Uri uri = Uri.https(
        TourApiConfig.baseHost,
        '${TourApiConfig.korServicePath}/locationBasedList2',
        <String, String>{
          ...qp,
          'serviceKey': TourApiConfig.serviceKey,
        },
      );
      res = await _client.get(uri);
    }
    _throwIfBadHttp(res, '목록 요청');
    final Map<String, dynamic> root =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _throwIfHeaderError(root);

    final List<Map<String, dynamic>> rawItems =
        _itemsFromBody(root['response']?['body']);
    final List<CultureSpot> out = <CultureSpot>[];
    for (final Map<String, dynamic> j in rawItems) {
      final CultureSpot? s = CultureSpot.tryFromJson(j);
      if (s != null) {
        out.add(s);
      }
    }
    return out;
  }

  /// 위치 기반 관광 목록: `locationBasedList2` → [TourItem]
  /// [contentTypeId]가 null이면 유형 제한 없이 주변 항목을 가져옵니다.
  ///
  /// 공공 API는 [numOfRowsPerPage]건씩만 내려주므로 `totalCount`까지 **페이지를 넘겨** 합칩니다.
  /// (이전에는 1페이지(예: 100건)만 받아 반경 안 먼 행사가 빠진 것처럼 보일 수 있음)
  Future<List<TourItem>> fetchLocationBasedTourItems(
    double mapX,
    double mapY, {
    int radiusMeters = 2000,
    int? contentTypeId,
    int numOfRowsPerPage = 100,
  }) async {
    final int r = radiusMeters.clamp(500, 20000);
    final List<TourItem> all = <TourItem>[];
    final Set<String> seen = <String>{};
    int pageNo = 1;
    const int maxPages = 50;

    while (pageNo <= maxPages) {
      final Map<String, String> qp = <String, String>{
        'mapX': mapX.toString(),
        'mapY': mapY.toString(),
        'radius': '$r',
        '_type': 'json',
        'MobileOS': 'ETC',
        'MobileApp': 'HndeWorkTool',
        'arrange': 'E',
        'numOfRows': '$numOfRowsPerPage',
        'pageNo': '$pageNo',
        if (contentTypeId != null) 'contentTypeId': '$contentTypeId',
      };
      final Map<String, dynamic> root =
          await _korService2Get('locationBasedList2', qp, '위치 기반 목록');
      final dynamic body = root['response']?['body'];
      final int totalCount = _bodyTotalCount(body);
      final List<TourItem> batch = _tourItemsFromRoot(root);
      if (batch.isEmpty) {
        break;
      }
      for (final TourItem it in batch) {
        if (seen.add(it.contentId)) {
          all.add(it);
        }
      }
      if (batch.length < numOfRowsPerPage) {
        break;
      }
      if (totalCount > 0 && all.length >= totalCount) {
        break;
      }
      pageNo++;
    }
    return all;
  }

  /// 행사정보(축제/공연/행사) 조회: `searchFestival2`
  ///
  /// 공공 API는 [numOfRowsPerPage]건씩만 내려주므로 `totalCount`까지 페이지를 넘겨 합칩니다.
  Future<List<TourItem>> searchFestivals({
    required double mapX,
    required double mapY,
    required int radiusMeters,
    required DateTimeRange range,
    int numOfRowsPerPage = 100,
  }) async {
    final int r = radiusMeters.clamp(500, 20000);
    final List<TourItem> all = <TourItem>[];
    final Set<String> seen = <String>{};
    int pageNo = 1;
    const int maxPages = 50;

    while (pageNo <= maxPages) {
      final Map<String, String> qp = <String, String>{
        'eventStartDate': _yyyymmdd(range.start),
        'eventEndDate': _yyyymmdd(range.end),
        'mapX': mapX.toString(),
        'mapY': mapY.toString(),
        'radius': '$r',
        '_type': 'json',
        'MobileOS': 'ETC',
        'MobileApp': 'HndeWorkTool',
        'arrange': 'E',
        'numOfRows': '$numOfRowsPerPage',
        'pageNo': '$pageNo',
      };
      final Map<String, dynamic> root =
          await _korService2Get('searchFestival2', qp, '행사 조회');
      final dynamic body = root['response']?['body'];
      final int totalCount = _bodyTotalCount(body);
      final List<TourItem> batch = _tourItemsFromRoot(root);
      if (batch.isEmpty) {
        break;
      }
      for (final TourItem it in batch) {
        if (seen.add(it.contentId)) {
          all.add(it);
        }
      }
      if (batch.length < numOfRowsPerPage) {
        break;
      }
      if (totalCount > 0 && all.length >= totalCount) {
        break;
      }
      pageNo++;
    }
    return all;
  }

  /// 키워드 검색: `searchKeyword2`
  Future<List<TourItem>> searchByKeyword({
    required String keyword,
    int? contentTypeId,
    int numOfRows = 60,
    int pageNo = 1,
  }) async {
    final String q = keyword.trim();
    if (q.isEmpty) return <TourItem>[];
    final Map<String, String> qp = <String, String>{
      'keyword': q,
      '_type': 'json',
      'MobileOS': 'ETC',
      'MobileApp': 'HndeWorkTool',
      'arrange': 'E',
      'numOfRows': '$numOfRows',
      'pageNo': '$pageNo',
      if (contentTypeId != null) 'contentTypeId': '$contentTypeId',
    };

    final http.Response res;
    if (kIsWeb && Secrets.isR2Configured) {
      final Uri uri = Uri.parse(_workerTourKorUrl('searchKeyword2'))
          .replace(queryParameters: qp);
      res = await _client.get(uri, headers: const <String, String>{
        'Accept': 'application/json',
      });
    } else {
      final Uri uri = Uri.https(
        TourApiConfig.baseHost,
        '${TourApiConfig.korServicePath}/searchKeyword2',
        <String, String>{
          ...qp,
          'serviceKey': TourApiConfig.serviceKey,
        },
      );
      res = await _client.get(uri);
    }
    _throwIfBadHttp(res, '키워드 검색');
    final Map<String, dynamic> root =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _throwIfHeaderError(root);
    final List<Map<String, dynamic>> rawItems =
        _itemsFromBody(root['response']?['body']);
    final List<TourItem> out = <TourItem>[];
    for (final Map<String, dynamic> j in rawItems) {
      final TourItem? it = TourItem.tryFromJson(j);
      if (it != null) out.add(it);
    }
    return out;
  }

  /// `locationBasedList2` 페이지마다 **누적** 목록을보냄 (문화의 날 점진 로딩용).
  Stream<List<TourItem>> streamLocationBasedTourItemsCumulative(
    double mapX,
    double mapY, {
    int radiusMeters = 2000,
    int? contentTypeId,
    int numOfRowsPerPage = 100,
  }) async* {
    final int r = radiusMeters.clamp(500, 20000);
    final List<TourItem> all = <TourItem>[];
    final Set<String> seen = <String>{};
    for (int pageNo = 1; pageNo <= 50; pageNo++) {
      final Map<String, String> qp = <String, String>{
        'mapX': mapX.toString(),
        'mapY': mapY.toString(),
        'radius': '$r',
        '_type': 'json',
        'MobileOS': 'ETC',
        'MobileApp': 'HndeWorkTool',
        'arrange': 'E',
        'numOfRows': '$numOfRowsPerPage',
        'pageNo': '$pageNo',
        if (contentTypeId != null) 'contentTypeId': '$contentTypeId',
      };
      final Map<String, dynamic> root =
          await _korService2Get('locationBasedList2', qp, '위치 기반 목록');
      final dynamic body = root['response']?['body'];
      final int totalCount = _bodyTotalCount(body);
      final List<TourItem> batch = _tourItemsFromRoot(root);
      if (batch.isEmpty) {
        break;
      }
      for (final TourItem it in batch) {
        if (seen.add(it.contentId)) {
          all.add(it);
        }
      }
      yield List<TourItem>.from(all);
      if (batch.length < numOfRowsPerPage) {
        break;
      }
      if (totalCount > 0 && all.length >= totalCount) {
        break;
      }
    }
  }

  /// `locationBasedList2` 페이지마다 **contentId → 항목** 누적 맵을보냄 (행사+LBL 병합용).
  Stream<Map<String, TourItem>> streamLocationBasedTourItemsMaps(
    double mapX,
    double mapY, {
    int radiusMeters = 2000,
    int? contentTypeId,
    int numOfRowsPerPage = 100,
  }) async* {
    final int r = radiusMeters.clamp(500, 20000);
    final Map<String, TourItem> byId = <String, TourItem>{};
    for (int pageNo = 1; pageNo <= 50; pageNo++) {
      final Map<String, String> qp = <String, String>{
        'mapX': mapX.toString(),
        'mapY': mapY.toString(),
        'radius': '$r',
        '_type': 'json',
        'MobileOS': 'ETC',
        'MobileApp': 'HndeWorkTool',
        'arrange': 'E',
        'numOfRows': '$numOfRowsPerPage',
        'pageNo': '$pageNo',
        if (contentTypeId != null) 'contentTypeId': '$contentTypeId',
      };
      final Map<String, dynamic> root =
          await _korService2Get('locationBasedList2', qp, '위치 기반 목록');
      final dynamic body = root['response']?['body'];
      final int totalCount = _bodyTotalCount(body);
      final List<TourItem> batch = _tourItemsFromRoot(root);
      if (batch.isEmpty) {
        break;
      }
      for (final TourItem it in batch) {
        byId[it.contentId] = it;
      }
      yield Map<String, TourItem>.from(byId);
      if (batch.length < numOfRowsPerPage) {
        break;
      }
      if (totalCount > 0 && byId.length >= totalCount) {
        break;
      }
    }
  }

  /// `searchFestival2` 페이지마다 **누적** 목록을보냄.
  Stream<List<TourItem>> streamSearchFestivalsCumulative({
    required double mapX,
    required double mapY,
    required int radiusMeters,
    required DateTimeRange range,
    int numOfRowsPerPage = 100,
  }) async* {
    final int r = radiusMeters.clamp(500, 20000);
    final List<TourItem> all = <TourItem>[];
    final Set<String> seen = <String>{};
    for (int pageNo = 1; pageNo <= 50; pageNo++) {
      final Map<String, String> qp = <String, String>{
        'eventStartDate': _yyyymmdd(range.start),
        'eventEndDate': _yyyymmdd(range.end),
        'mapX': mapX.toString(),
        'mapY': mapY.toString(),
        'radius': '$r',
        '_type': 'json',
        'MobileOS': 'ETC',
        'MobileApp': 'HndeWorkTool',
        'arrange': 'E',
        'numOfRows': '$numOfRowsPerPage',
        'pageNo': '$pageNo',
      };
      final Map<String, dynamic> root =
          await _korService2Get('searchFestival2', qp, '행사 조회');
      final dynamic body = root['response']?['body'];
      final int totalCount = _bodyTotalCount(body);
      final List<TourItem> batch = _tourItemsFromRoot(root);
      if (batch.isEmpty) {
        break;
      }
      for (final TourItem it in batch) {
        if (seen.add(it.contentId)) {
          all.add(it);
        }
      }
      yield List<TourItem>.from(all);
      if (batch.length < numOfRowsPerPage) {
        break;
      }
      if (totalCount > 0 && all.length >= totalCount) {
        break;
      }
    }
  }

  /// `searchKeyword2` 페이지마다 **누적** 목록을보냄.
  Stream<List<TourItem>> streamSearchByKeywordCumulative({
    required String keyword,
    int? contentTypeId,
    int numOfRowsPerPage = 60,
  }) async* {
    final String q = keyword.trim();
    if (q.isEmpty) {
      return;
    }
    final List<TourItem> all = <TourItem>[];
    final Set<String> seen = <String>{};
    for (int pageNo = 1; pageNo <= 50; pageNo++) {
      final Map<String, String> qp = <String, String>{
        'keyword': q,
        '_type': 'json',
        'MobileOS': 'ETC',
        'MobileApp': 'HndeWorkTool',
        'arrange': 'E',
        'numOfRows': '$numOfRowsPerPage',
        'pageNo': '$pageNo',
        if (contentTypeId != null) 'contentTypeId': '$contentTypeId',
      };
      final Map<String, dynamic> root =
          await _korService2Get('searchKeyword2', qp, '키워드 검색');
      final dynamic body = root['response']?['body'];
      final int totalCount = _bodyTotalCount(body);
      final List<TourItem> batch = _tourItemsFromRoot(root);
      if (batch.isEmpty) {
        break;
      }
      for (final TourItem it in batch) {
        if (seen.add(it.contentId)) {
          all.add(it);
        }
      }
      yield List<TourItem>.from(all);
      if (batch.length < numOfRowsPerPage) {
        break;
      }
      if (totalCount > 0 && all.length >= totalCount) {
        break;
      }
    }
  }

  /// 이미지 목록: `detailImage2` (갤러리·추가 사진 — 대표/약도는 [detailCommon2])
  ///
  /// 공공 API `detailImage2`는 [contentId]만 허용하는 경우가 많아 `contentTypeId`를 붙이면
  /// HTTP 400(파라미터 오류)이 나는 환경이 있어 보내지 않습니다.
  Map<String, String> _queryParamsDetailImage2(String contentId) {
    return <String, String>{
      'contentId': contentId,
      'MobileOS': 'ETC',
      'MobileApp': 'HndeWorkTool',
      '_type': 'json',
      'numOfRows': '50',
      'pageNo': '1',
    };
  }

  /// 한국관광공사 매뉴얼(v4.4): `detailCommon2` 요청변수에 **contentTypeId 없음**
  Map<String, String> _queryParamsDetailCommon2(String contentId) {
    return <String, String>{
      'contentId': contentId,
      'MobileOS': 'ETC',
      'MobileApp': 'HndeWorkTool',
      '_type': 'json',
      'numOfRows': '1',
      'pageNo': '1',
    };
  }

  Map<String, String> _queryParamsDetailIntro2(
    String contentId,
    int? contentTypeId,
  ) {
    return <String, String>{
      'contentId': contentId,
      if (contentTypeId != null) 'contentTypeId': '$contentTypeId',
      'MobileOS': 'ETC',
      'MobileApp': 'HndeWorkTool',
      '_type': 'json',
      'numOfRows': '1',
      'pageNo': '1',
    };
  }

  /// 실제 요청과 동일한 쿼리스트링으로 표시용 URL (웹=Worker, 그 외=공공 호스트 + serviceKey 자리 표시)
  String displayTourKorGetUrl(String endpoint, Map<String, String> qp) {
    if (kIsWeb && Secrets.isR2Configured) {
      return Uri.parse(_workerTourKorUrl(endpoint))
          .replace(queryParameters: qp)
          .toString();
    }
    return Uri.https(
      TourApiConfig.baseHost,
      '${TourApiConfig.korServicePath}/$endpoint',
      <String, String>{
        ...qp,
        'serviceKey': '<serviceKey>',
      },
    ).toString();
  }

  Future<List<TourImageItem>> fetchImages(String contentId) async {
    final Map<String, String> qp = _queryParamsDetailImage2(contentId);
    final http.Response res;
    if (kIsWeb && Secrets.isR2Configured) {
      final Uri uri = Uri.parse(_workerTourKorUrl('detailImage2'))
          .replace(queryParameters: qp);
      res = await _client.get(uri, headers: const <String, String>{
        'Accept': 'application/json',
      });
    } else {
      final Uri uri = Uri.https(
        TourApiConfig.baseHost,
        '${TourApiConfig.korServicePath}/detailImage2',
        <String, String>{
          ...qp,
          'serviceKey': TourApiConfig.serviceKey,
        },
      );
      res = await _client.get(uri);
    }
    _throwIfBadHttp(res, '이미지 조회');
    final Map<String, dynamic> root =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _throwIfHeaderError(root);
    final List<Map<String, dynamic>> rawItems =
        _itemsFromBody(root['response']?['body']);
    final List<TourImageItem> out = <TourImageItem>[];
    for (final Map<String, dynamic> j in rawItems) {
      final TourImageItem? it = TourImageItem.tryFromJson(j);
      if (it != null) out.add(it);
    }
    return out;
  }

  /// 목록 썸네일용 — [detailCommon2]의 대표 이미지(`firstimage`/`firstimage2`)
  Future<String?> fetchCommonRepresentativeImageUrl({
    required String contentId,
  }) async {
    final Map<String, dynamic>? m = await _fetchDetailCommonMap(contentId);
    if (m == null) {
      return null;
    }
    for (final dynamic v in <dynamic>[
      m['firstimage'],
      m['firstImage'],
      m['firstimage2'],
      m['firstImage2'],
      m['originimgurl'],
      m['originImgUrl'],
      m['smallimageurl'],
      m['smallImageUrl'],
      m['img'],
    ]) {
      final String? u = normalizeTourMediaUrl(v?.toString());
      if (u != null) {
        return u;
      }
    }
    return null;
  }

  /// `detailCommon2`(overview) + `detailIntro2`(문화시설 필드) 병합
  Future<CultureDetail> fetchSpotDetail(String contentId) async {
    final List<Map<String, dynamic>?> maps = await Future.wait(
      <Future<Map<String, dynamic>?>>[
        _fetchDetailCommonMap(contentId),
        _fetchDetailIntroMap(contentId),
      ],
    );
    return CultureDetail.merge(
      contentId: contentId,
      common: maps[0],
      intro: maps[1],
    );
  }

  Future<TourDetailBundle> fetchDetailBundle({
    required String contentId,
    int? contentTypeId,
  }) async {
    final Map<String, String> qpCommon = _queryParamsDetailCommon2(contentId);
    final Map<String, String> qpIntro =
        _queryParamsDetailIntro2(contentId, contentTypeId);
    final Map<String, String> qpImg = _queryParamsDetailImage2(contentId);
    final String urlCommon = displayTourKorGetUrl('detailCommon2', qpCommon);
    final String urlIntro = displayTourKorGetUrl('detailIntro2', qpIntro);
    final String urlImg = displayTourKorGetUrl('detailImage2', qpImg);

    final Map<String, dynamic>? common = await _fetchDetailCommonMap(contentId);
    final Map<String, dynamic>? intro =
        await _fetchDetailIntroMap(contentId, contentTypeId: contentTypeId);
    List<TourImageItem> images = <TourImageItem>[];
    try {
      images = await fetchImages(contentId);
    } on PublicDataException {
      // 상세 본문·대표이미지(common)는 보이고 갤러리만 비움
      images = <TourImageItem>[];
    }
    return TourDetailBundle(
      contentId: contentId,
      common: common,
      intro: intro,
      images: images,
      requestUrlDetailCommon2: urlCommon,
      requestUrlDetailIntro2: urlIntro,
      requestUrlDetailImage2: urlImg,
    );
  }

  /// 최소 호출용: `detailCommon2`만
  Future<Map<String, dynamic>?> fetchDetailCommonMap(String contentId) {
    return _fetchDetailCommonMap(contentId);
  }

  /// 최소 호출용: `detailIntro2`만
  Future<Map<String, dynamic>?> fetchDetailIntroMap(
    String contentId, {
    int? contentTypeId,
  }) {
    return _fetchDetailIntroMap(contentId, contentTypeId: contentTypeId);
  }

  Future<Map<String, dynamic>?> _fetchDetailCommonMap(String contentId) async {
    // KorService2(detailCommon2): 매뉴얼 기준 요청변수에 contentTypeId 없음
    final Map<String, String> qp = _queryParamsDetailCommon2(contentId);
    final http.Response res;
    if (kIsWeb && Secrets.isR2Configured) {
      final Uri uri = Uri.parse(_workerTourKorUrl('detailCommon2'))
          .replace(queryParameters: qp);
      res = await _client.get(uri, headers: const <String, String>{
        'Accept': 'application/json',
      });
    } else {
      final Uri uri = Uri.https(
        TourApiConfig.baseHost,
        '${TourApiConfig.korServicePath}/detailCommon2',
        <String, String>{
          ...qp,
          'serviceKey': TourApiConfig.serviceKey,
        },
      );
      res = await _client.get(uri);
    }
    _throwIfBadHttp(res, '상세(common) 요청');
    final Map<String, dynamic> root =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _throwIfHeaderError(root);
    return _singleItemFromBody(root['response']?['body']);
  }

  Future<Map<String, dynamic>?> _fetchDetailIntroMap(
    String contentId, {
    int? contentTypeId,
  }) async {
    final Map<String, String> qp =
        _queryParamsDetailIntro2(contentId, contentTypeId);
    final http.Response res;
    if (kIsWeb && Secrets.isR2Configured) {
      final Uri uri = Uri.parse(_workerTourKorUrl('detailIntro2'))
          .replace(queryParameters: qp);
      res = await _client.get(uri, headers: const <String, String>{
        'Accept': 'application/json',
      });
    } else {
      final Uri uri = Uri.https(
        TourApiConfig.baseHost,
        '${TourApiConfig.korServicePath}/detailIntro2',
        <String, String>{
          ...qp,
          'serviceKey': TourApiConfig.serviceKey,
        },
      );
      res = await _client.get(uri);
    }
    _throwIfBadHttp(res, '상세(intro) 요청');
    final Map<String, dynamic> root =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _throwIfHeaderError(root);
    return _singleItemFromBody(root['response']?['body']);
  }

  void _throwIfHeaderError(Map<String, dynamic> root) {
    final Map<String, dynamic>? h =
        root['response']?['header'] as Map<String, dynamic>?;
    if (h == null) {
      return;
    }
    final String code = '${h['resultCode'] ?? ''}'.trim();
    if (code.isEmpty || code == '0000') {
      return;
    }
    final String msg = '${h['resultMsg'] ?? '오류'}'.trim();
    throw PublicDataException('TourAPI: $code $msg');
  }

  static List<Map<String, dynamic>> _itemsFromBody(dynamic body) {
    if (body is! Map) {
      return <Map<String, dynamic>>[];
    }
    final Map<String, dynamic> b = Map<String, dynamic>.from(body);
    final dynamic items = b['items'];
    if (items == null || items == '') {
      return <Map<String, dynamic>>[];
    }
    if (items is! Map) {
      return <Map<String, dynamic>>[];
    }
    final dynamic item = items['item'];
    if (item == null) {
      return <Map<String, dynamic>>[];
    }
    if (item is List) {
      return item
          .map((dynamic e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (item is Map) {
      return <Map<String, dynamic>>[Map<String, dynamic>.from(item)];
    }
    return <Map<String, dynamic>>[];
  }

  static Map<String, dynamic>? _singleItemFromBody(dynamic body) {
    final List<Map<String, dynamic>> list = _itemsFromBody(body);
    if (list.isEmpty) {
      return null;
    }
    return list.first;
  }
}
