import 'package:flutter/foundation.dart';

/// Cloudflare Worker URL만 클라이언트에 둡니다.
///
/// **디버그·프로파일·릴리즈 모두** 기본은 배포 Worker (`R2_WORKER_URL_PROD`) 한 줄이면 됩니다.
/// 로컬 `wrangler dev`만 쓸 때만 `WORKER_MODE=local` + `R2_WORKER_URL_LOCAL` 을 추가합니다.
///
/// 상세: `docs/CLOUDFLARE_WORKER_설정.md`
class Secrets {
  Secrets._();

  /// Worker 호스트 **루트**만 두어야 합니다. `…/v1` 까지 넣으면 앱이 `/v1/...` 를 붙여 **404**가 납니다.
  static String normalizeWorkerBaseUrl(String raw) {
    String s = raw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    final String lower = s.toLowerCase();
    if (lower.endsWith('/v1')) {
      s = s.substring(0, s.length - 3);
      while (s.endsWith('/')) {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  /// 로컬 `wrangler dev` 전용 (`WORKER_MODE=local` 일 때만 사용)
  static const String r2WorkerUrlLocal = String.fromEnvironment(
    'R2_WORKER_URL_LOCAL',
    defaultValue: '',
  );

  /// 배포된 Worker (https://....workers.dev)
  static const String r2WorkerUrlProd = String.fromEnvironment(
    'R2_WORKER_URL_PROD',
    defaultValue: '',
  );

  /// 구 방식(한 줄만 쓸 때). PROD가 비었을 때만 폴백
  static const String r2WorkerUrlLegacy = String.fromEnvironment(
    'R2_WORKER_URL',
    defaultValue: '',
  );

  /// `auto`(기본) | `local` — **디버그/프로파일**에서만 의미 있음. `auto` = 배포 Worker
  static const String workerMode = String.fromEnvironment(
    'WORKER_MODE',
    defaultValue: 'auto',
  );

  /// 실제 API 호출에 쓰는 Base URL (슬래시 없음, 끝의 `/v1` 자동 제거)
  static String get effectiveR2WorkerUrl {
    if (kReleaseMode) {
      if (r2WorkerUrlProd.isNotEmpty) {
        return normalizeWorkerBaseUrl(r2WorkerUrlProd);
      }
      if (r2WorkerUrlLegacy.isNotEmpty) {
        return normalizeWorkerBaseUrl(r2WorkerUrlLegacy);
      }
      throw StateError(
        '릴리즈 빌드에는 R2_WORKER_URL_PROD (또는 구 R2_WORKER_URL) 가 필요합니다.',
      );
    }

    final String mode = workerMode.trim().toLowerCase();
    if (mode == 'local') {
      if (r2WorkerUrlLocal.isNotEmpty) {
        return normalizeWorkerBaseUrl(r2WorkerUrlLocal);
      }
      if (r2WorkerUrlLegacy.isNotEmpty) {
        return normalizeWorkerBaseUrl(r2WorkerUrlLegacy);
      }
      return normalizeWorkerBaseUrl(_need(r2WorkerUrlLocal, 'R2_WORKER_URL_LOCAL'));
    }

    // auto / prod / 기타: 개발도 배포 Worker만 (이중 확인 없음)
    if (r2WorkerUrlProd.isNotEmpty) {
      return normalizeWorkerBaseUrl(r2WorkerUrlProd);
    }
    if (r2WorkerUrlLegacy.isNotEmpty) {
      return normalizeWorkerBaseUrl(r2WorkerUrlLegacy);
    }
    throw StateError(
      'R2_WORKER_URL_PROD (또는 구 R2_WORKER_URL) 가 필요합니다. '
      '로컬 Worker만 쓰려면 WORKER_MODE=local 과 R2_WORKER_URL_LOCAL 을 설정하세요. '
      'flutter run --dart-define-from-file=env.worker',
    );
  }

  static String _need(String v, String name) {
    if (v.isEmpty) {
      throw StateError('$name 이 비어 있습니다. env.worker 를 확인하세요.');
    }
    return v;
  }

  static void assertWorkerConfigured() {
    final String _ = effectiveR2WorkerUrl;
  }

  static bool get isR2Configured {
    try {
      return effectiveR2WorkerUrl.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
