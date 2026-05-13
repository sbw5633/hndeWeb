import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../config/secrets.dart';
import '../constants/firestore_paths.dart';
import '../models/culture_day_event_item.dart';

/// 문화의 날: Firestore 번들 읽기 + 관리자 AI 파이프라인(Worker) 호출 후 게시.
class CultureDayRepository {
  CultureDayRepository();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchBundleDoc(
    String monthKey,
  ) {
    return FirestorePaths.cultureDayBundleDoc(monthKey).snapshots();
  }

  static List<CultureDayEventItem> parseItems(Map<String, dynamic>? data) {
    if (data == null) {
      return <CultureDayEventItem>[];
    }
    final dynamic raw = data['items'] ?? data['events'];
    if (raw is! List) {
      return <CultureDayEventItem>[];
    }
    final List<CultureDayEventItem> out = <CultureDayEventItem>[];
    for (final dynamic e in raw) {
      final CultureDayEventItem? it = CultureDayEventItem.tryFromMap(e);
      if (it != null) {
        out.add(it);
      }
    }
    return out;
  }

  /// 수집 작업 큐 문서 추가 (상태 추적용). [runAiPipelineAndPublish]와 함께 쓰면 됩니다.
  Future<DocumentReference<Map<String, dynamic>>> submitIngestJob({
    required String requestedByUid,
    required String monthKey,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String instruction,
  }) {
    return FirestorePaths.cultureDayIngestJobsCol().add(<String, dynamic>{
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'monthKey': monthKey,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'instruction': instruction.trim(),
      'requestedByUid': requestedByUid,
      'pipeline': <String, String>{
        'collect': 'pending',
        'review': 'pending',
        'structure': 'pending',
        'upload': 'pending',
      },
    });
  }

  static String _workerBaseUrl() {
    return Secrets.effectiveR2WorkerUrl.replaceAll(RegExp(r'/$'), '');
  }

  /// Cloudflare Worker: Tour `searchFestival2` 수집 → Gemini 검수·구조화 → 응답 JSON.
  /// 이후 [publishBundleFromWorkerItems]로 Firestore에 반영합니다.
  Future<Map<String, dynamic>> callWorkerGenerate({
    required String monthKey,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String instruction,
    double mapX = 126.978,
    double mapY = 37.5665,
    double radius = 20000,
    /// Worker 기본과 동일: true면 전국 여러 거점(각 20km) 병합 수집.
    bool nationwide = true,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('로그인 필요');
    }
    if (!Secrets.isR2Configured) {
      throw StateError(
        'Worker URL 미설정(R2_WORKER_URL_PROD 등). --dart-define-from-file=env.worker',
      );
    }
    final String token = await user.getIdToken() ?? '';
    if (token.isEmpty) {
      throw StateError('ID 토큰 없음');
    }
    final Uri uri = Uri.parse('${_workerBaseUrl()}/v1/culture-day/generate');
    final http.Response res = await http.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'monthKey': monthKey,
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'instruction': instruction,
        'mapX': mapX,
        'mapY': mapY,
        'radius': radius,
        'nationwide': nationwide,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode == 404) {
        throw Exception(
          'Worker 404: POST /v1/culture-day/generate 를 찾지 못했습니다. '
          '① env.worker 의 R2_WORKER_URL_PROD 는 Worker **루트**(예: https://이름.workers.dev)만 넣고 끝에 `/v1` 을 붙이지 마세요. '
          '② cloudflare-worker 에서 `npx wrangler deploy` 로 최신 Worker(문화의 날 라우트 포함)를 배포했는지 확인하세요. '
          '응답: ${res.body}',
        );
      }
      throw Exception('Worker ${res.statusCode}: ${res.body}');
    }
    final Object? decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Worker 응답 형식 오류');
    }
    return decoded;
  }

  /// Worker가 반환한 [items]를 `culture_day_bundles/{monthKey}`에 게시합니다.
  Future<void> publishBundleFromWorkerItems({
    required String monthKey,
    required List<dynamic> items,
    Map<String, dynamic>? meta,
  }) async {
    final List<Map<String, dynamic>> normalized = <Map<String, dynamic>>[];
    for (final dynamic e in items) {
      if (e is Map<String, dynamic>) {
        normalized.add(e);
      } else if (e is Map) {
        normalized.add(Map<String, dynamic>.from(e));
      }
    }
    await FirestorePaths.cultureDayBundleDoc(monthKey).set(<String, dynamic>{
      'monthKey': monthKey,
      'status': 'published',
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'ai_pipeline_tour_gemini',
      if (meta != null) 'meta': meta,
      'items': normalized,
    });
  }

  /// 수집 → 구조화 → Firestore 업로드까지 한 번에 (작업 문서가 있으면 상태 갱신).
  Future<int> runAiPipelineAndPublish({
    required String monthKey,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String instruction,
    DocumentReference<Map<String, dynamic>>? jobRef,
  }) async {
    Future<void> patchJob(Map<String, dynamic> data) async {
      if (jobRef != null) {
        await jobRef.update(data);
      }
    }

    await patchJob(<String, dynamic>{
      'status': 'running',
      'startedAt': FieldValue.serverTimestamp(),
      'pipeline': <String, String>{
        'collect': 'running',
        'review': 'pending',
        'structure': 'pending',
        'upload': 'pending',
      },
    });

    try {
      final Map<String, dynamic> root = await callWorkerGenerate(
        monthKey: monthKey,
        periodStart: periodStart,
        periodEnd: periodEnd,
        instruction: instruction,
      );
      await patchJob(<String, dynamic>{
        'pipeline': <String, String>{
          'collect': 'done',
          'review': 'running',
          'structure': 'pending',
          'upload': 'pending',
        },
      });

      final dynamic items = root['items'];
      if (items is! List) {
        throw StateError('Worker 응답에 items 배열이 없습니다.');
      }
      final Map<String, dynamic>? meta =
          root['meta'] is Map<String, dynamic>
              ? root['meta'] as Map<String, dynamic>
              : null;

      await patchJob(<String, dynamic>{
        'pipeline': <String, String>{
          'collect': 'done',
          'review': 'done',
          'structure': 'running',
          'upload': 'pending',
        },
      });

      await publishBundleFromWorkerItems(
        monthKey: monthKey,
        items: items,
        meta: meta,
      );

      await patchJob(<String, dynamic>{
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'pipeline': <String, String>{
          'collect': 'done',
          'review': 'done',
          'structure': 'done',
          'upload': 'done',
        },
        'resultMonthKey': monthKey,
        'itemCount': items.length,
      });

      return items.length;
    } on Object catch (e) {
      await patchJob(<String, dynamic>{
        'status': 'failed',
        'failedAt': FieldValue.serverTimestamp(),
        'errorMessage': e.toString(),
        'pipeline': <String, String>{
          'collect': 'error',
          'review': 'error',
          'structure': 'error',
          'upload': 'error',
        },
      });
      rethrow;
    }
  }
}
