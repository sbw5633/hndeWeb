// [보류] OLE HWP 원격 변환 — PDF 변환 기능과 함께 보류.
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// OLE `.hwp`는 브라우저에서 직접 PDF로 그릴 수 없습니다. [Coolutils](https://www.coolutils.com/ko/online/HWP-to-PDF) 등은
/// **서버로 파일을 올린 뒤** PDF를 돌려줍니다. 동일한 방식으로 쓰려면 변환 API를 두고 여기서 호출합니다.
///
/// 빌드 시 `--dart-define=CONVERT_HWP_ENDPOINT=https://your-api/convert` 로 지정합니다.
/// POST `multipart/form-data`, 필드 이름 `file`, 본문은 PDF 바이트를 기대합니다(200대 + `application/pdf` 권장).
class PdfRemoteHwpConvert {
  PdfRemoteHwpConvert._();

  static const String _endpoint = String.fromEnvironment(
    'CONVERT_HWP_ENDPOINT',
    defaultValue: '',
  );

  static bool get isConfigured => _endpoint.isNotEmpty;

  /// 성공 시 PDF 바이트, 미설정·실패 시 `null`
  static Future<Uint8List?> tryOleHwpToPdf(Uint8List bytes, String fileName) async {
    if (_endpoint.isEmpty) {
      return null;
    }
    try {
      final Uri uri = Uri.parse(_endpoint);
      final http.MultipartRequest req = http.MultipartRequest('POST', uri);
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName.isEmpty ? 'document.hwp' : fileName,
        ),
      );
      final http.StreamedResponse streamed = await req.send();
      final http.Response resp = await http.Response.fromStream(streamed);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return null;
      }
      final List<int> body = resp.bodyBytes;
      if (body.isEmpty) {
        return null;
      }
      return Uint8List.fromList(body);
    } catch (_) {
      return null;
    }
  }
}
