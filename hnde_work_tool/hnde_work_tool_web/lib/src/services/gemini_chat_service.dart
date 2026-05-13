import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../config/secrets.dart';

/// Gemini — API 키는 Cloudflare Worker에만 둠 (`wrangler secret put GEMINI_API_KEY`)
///
/// 기본 **끔** (`GEMINI_ENABLED` 없음). 켤 때: `env.worker`에 `GEMINI_ENABLED=true` 추가 + Worker 시크릿.
const bool _kGeminiFeatureEnabled = bool.fromEnvironment(
  'GEMINI_ENABLED',
  defaultValue: false,
);

class GeminiChatService {
  GeminiChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> generateReply(String userText) async {
    final String trimmed = userText.trim();
    if (trimmed.isEmpty) {
      return '내용을 입력해 주세요.';
    }

    if (!_kGeminiFeatureEnabled) {
      return 'AI 비서(Gemini)는 아직 켜지 않았습니다. '
          '연동 시 Cloudflare Worker에 API 키만 서버에 두고 사용할 수 있습니다.';
    }

    final User? u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      return 'AI 비서를 쓰려면 로그인해 주세요.';
    }
    final String? token = await u.getIdToken();
    if (token == null || token.isEmpty) {
      return '인증 토큰을 가져올 수 없습니다.';
    }

    final String base;
    try {
      base = Secrets.effectiveR2WorkerUrl.replaceAll(RegExp(r'/$'), '');
    } catch (_) {
      return 'Worker URL(env.worker)이 없습니다. R2와 동일 Worker 주소를 설정하세요.';
    }

    final Uri uri = Uri.parse('$base/v1/gemini/chat');

    int attempt = 0;
    int delayMs = 1000;
    const int maxRetries = 5;
    Object? lastError;

    while (attempt < maxRetries) {
      try {
        final http.Response response = await _client.post(
          uri,
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, String>{'text': trimmed}),
        );

        if (response.statusCode == 503) {
          try {
            final Map<String, dynamic> err =
                jsonDecode(response.body) as Map<String, dynamic>;
            if (err['error'] == 'gemini_not_configured') {
              return '서버에 Gemini가 아직 설정되지 않았습니다. '
                  '관리자: Cloudflare에서 `wrangler secret put GEMINI_API_KEY` 를 실행하세요.';
            }
          } catch (_) {}
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data =
              jsonDecode(response.body) as Map<String, dynamic>;
          if (data['error'] != null) {
            return '응답 오류: ${data['error']}';
          }
          final String? text = data['text'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            return text.trim();
          }
          return '답변을 생성할 수 없습니다.';
        }

        throw Exception('HTTP ${response.statusCode} ${response.body}');
      } catch (e) {
        lastError = e;
        attempt++;
        if (attempt >= maxRetries) break;
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2;
      }
    }

    return '연결 오류가 발생했습니다. 잠시 후 다시 시도해주세요. ($lastError)';
  }
}
