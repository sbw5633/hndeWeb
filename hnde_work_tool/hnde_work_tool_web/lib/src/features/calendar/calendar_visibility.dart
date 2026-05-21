/// 캘린더 일정 가시성/권한 공통 헬퍼.
///
/// `calendar_events` Firestore 도큐먼트 데이터에 대해 현재 사용자에게 노출해도 되는지
/// 판단하는 동일 로직을 캘린더 페이지와 대시보드 등에서 공유하기 위해 분리합니다.
library;

/// 일정 도큐먼트를 현재 사용자에게 보여야 하는지 판단.
///
/// - `isMainAdmin`: mainAdmin/master 권한 보유 시 모든 일정 노출.
/// - `private`: 작성자(`createdByUid`) 와 본인이 일치할 때만 노출.
/// - `company`: 모든 사용자에게 노출.
/// - `branch`: `branchName` 단일값 또는 `targetBranches` 리스트와 본인 사업소(id/name)
///   중 하나라도 일치하면 노출.
bool isCalendarEventVisibleTo(
  Map<String, dynamic> data, {
  required bool isMainAdmin,
  required String myUid,
  required String myBranchId,
  required String myBranchName,
}) {
  if (isMainAdmin) return true;
  final String scope = (data['scope'] as String?)?.trim() ?? 'private';
  if (scope == 'private') {
    final String owner = (data['createdByUid'] as String?)?.trim() ?? '';
    final String me = myUid.trim();
    return me.isNotEmpty && owner.isNotEmpty && owner == me;
  }
  if (scope == 'company') return true;
  if (scope == 'branch') {
    final List<String> targets = <String>[];
    final dynamic raw = data['targetBranches'];
    if (raw is List) {
      for (final dynamic e in raw) {
        if (e is String && e.trim().isNotEmpty) targets.add(e.trim());
      }
    }
    final String single = (data['branchName'] as String?)?.trim() ?? '';
    if (single.isNotEmpty && !targets.contains(single)) {
      targets.add(single);
    }
    if (targets.isEmpty) return false;
    final String name = myBranchName.trim();
    final String id = myBranchId.trim();
    for (final String t in targets) {
      if (name.isNotEmpty && t == name) return true;
      if (id.isNotEmpty && t == id) return true;
    }
    return false;
  }
  return false;
}
