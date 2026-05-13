import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../config/secrets.dart';

/// R2 버킷 객체 목록용 (Worker `/v1/list` 응답)
class R2BucketObjectInfo {
  const R2BucketObjectInfo({
    required this.key,
    this.lastModified,
    this.size,
  });

  final String key;
  final DateTime? lastModified;
  final int? size;
}

class R2UploadResult {
  R2UploadResult({
    required this.fileKey,
    required this.fileUrl,
  });

  final String fileKey;
  final String fileUrl;
}

/// Cloudflare Worker 프록시만 사용 (클라이언트에 R2 시크릿 없음)
class R2StorageService {
  R2StorageService();

  static Future<String> _bearerToken() async {
    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw StateError('파일 저장을 위해 로그인이 필요합니다.');
    }
    final String? t = await u.getIdToken();
    if (t == null || t.isEmpty) {
      throw StateError('인증 토큰을 가져올 수 없습니다.');
    }
    return t;
  }

  Uri _baseUri(String path, [Map<String, String>? query]) {
    Secrets.assertWorkerConfigured();
    final String base =
        Secrets.effectiveR2WorkerUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<R2UploadResult> uploadFile(PlatformFile file) async {
    final List<int>? bytes = file.bytes;
    if (bytes == null) {
      throw ArgumentError('파일 데이터가 비어 있습니다.');
    }

    final String token = await _bearerToken();
    final http.MultipartRequest req = http.MultipartRequest(
      'POST',
      _baseUri('/v1/upload'),
    );
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ),
    );

    final http.StreamedResponse streamed = await req.send();
    final http.Response res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('업로드 실패 (${res.statusCode}): ${res.body}');
    }
    final Map<String, dynamic> j =
        jsonDecode(res.body) as Map<String, dynamic>;
    final String fileKey = j['fileKey'] as String? ?? '';
    final String fileUrl = j['fileUrl'] as String? ?? '';
    if (fileKey.isEmpty || fileUrl.isEmpty) {
      throw StateError('Worker 응답 형식 오류');
    }
    return R2UploadResult(fileKey: fileKey, fileUrl: fileUrl);
  }

  Future<void> deleteFile(String fileKey) async {
    final String token = await _bearerToken();
    final Uri u = _baseUri('/v1/object', <String, String>{'key': fileKey});
    final http.Response res = await http.delete(
      u,
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('삭제 실패 (${res.statusCode}): ${res.body}');
    }
  }

  Future<List<R2BucketObjectInfo>> listAllBucketObjects() async {
    final String token = await _bearerToken();
    final Uri u = _baseUri('/v1/list');
    final http.Response res = await http.get(
      u,
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 403) {
      throw StateError('파일 목록은 메인관리자만 볼 수 있습니다. Worker ADMIN_UIDS에 본인 uid를 넣었는지 확인하세요.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('목록 실패 (${res.statusCode}): ${res.body}');
    }
    final Map<String, dynamic> j =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic>? raw = j['objects'] as List<dynamic>?;
    if (raw == null) {
      return <R2BucketObjectInfo>[];
    }
    final List<R2BucketObjectInfo> out = <R2BucketObjectInfo>[];
    for (final dynamic e in raw) {
      if (e is! Map<String, dynamic>) {
        continue;
      }
      final String key = e['key'] as String? ?? '';
      if (key.isEmpty) {
        continue;
      }
      DateTime? lm;
      final String? lmStr = e['lastModified'] as String?;
      if (lmStr != null && lmStr.isNotEmpty) {
        lm = DateTime.tryParse(lmStr);
      }
      final int? sz = (e['size'] as num?)?.toInt();
      out.add(
        R2BucketObjectInfo(
          key: key,
          lastModified: lm,
          size: sz,
        ),
      );
    }
    return out;
  }

  /// 브라우저 새 창 다운로드용 서명 URL (짧은 유효기간, Worker가 발급)
  Future<String> getPresignedDownloadUrl(
    String fileKey, {
    String? fileName,
  }) async {
    final String token = await _bearerToken();
    final http.Response res = await http.post(
      _baseUri('/v1/sign-download'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'key': fileKey,
        'fileName': fileName ?? fileKey.split('/').last,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('다운로드 URL 발급 실패 (${res.statusCode}): ${res.body}');
    }
    final Map<String, dynamic> j =
        jsonDecode(res.body) as Map<String, dynamic>;
    final String url = j['url'] as String? ?? '';
    if (url.isEmpty) {
      throw StateError('Worker 응답에 url 없음');
    }
    return url;
  }

  /// 저장된 fileUrl에서 object key 추출 (구 R2 URL·Worker 다운로드 URL 모두)
  ///
  /// Worker 업로드 키는 항상 `uploads/…` 로 시작하므로, 경로에서 `uploads/` 이후를 우선 사용한다.
  static String? fileKeyFromUrl(String url) {
    final Uri? u = Uri.tryParse(url);
    if (u == null) {
      return null;
    }
    final String? qk = u.queryParameters['key'];
    if (qk != null && qk.isNotEmpty) {
      return qk;
    }
    final String path = u.path.startsWith('/') ? u.path.substring(1) : u.path;
    if (path.isEmpty) {
      return null;
    }
    final int uploadsIdx = path.indexOf('uploads/');
    if (uploadsIdx >= 0) {
      return path.substring(uploadsIdx);
    }
    final List<String> parts =
        path.split('/').where((String s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return parts.sublist(1).join('/');
    }
    return null;
  }
}
