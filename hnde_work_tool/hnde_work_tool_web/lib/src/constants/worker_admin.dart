/// Cloudflare Worker `ADMIN_UIDS`(wrangler.toml) 와 동기화되는 클라이언트용 화이트리스트.
///
/// Worker는 Firestore를 읽지 않고 JWT의 uid만 비교하므로,
/// 파일 목록/삭제 가능한 사용자는 Cloudflare 변수에 직접 등록되어야 합니다.
/// 같은 목록을 클라이언트에서도 UI 노출 제어에 사용합니다.
///
/// 빌드 시 `--dart-define=WORKER_ADMIN_UIDS=uid1,uid2` 또는
/// `env.worker` 에 `WORKER_ADMIN_UIDS=uid1,uid2` 로 덮어쓸 수 있습니다.
class WorkerAdmin {
  WorkerAdmin._();

  /// `wrangler.toml` 의 `ADMIN_UIDS` 와 일치시키는 폴백 값.
  static const String _fallback = 'T6xEyrDDr0a8R5BjsbSp1LbqQrr2';

  static const String _envRaw = String.fromEnvironment(
    'WORKER_ADMIN_UIDS',
    defaultValue: '',
  );

  static List<String> get _uids {
    final String raw = _envRaw.trim().isEmpty ? _fallback : _envRaw;
    return raw
        .split(RegExp(r'[,\s]+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// 현재 Firebase Auth `uid` 가 Worker 관리자 목록에 있는지 확인.
  static bool isWorkerAdmin(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    return _uids.contains(uid);
  }
}
