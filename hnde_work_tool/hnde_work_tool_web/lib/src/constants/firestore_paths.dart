import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_env.dart';

/// 프로젝트/경로 상수들을 한 곳에 모아두기 위한 유틸.
class FirestorePaths {
  static String get appId => kFirestoreAppId;

  static DocumentReference<Map<String, dynamic>> artifactsAppDoc() {
    return FirebaseFirestore.instance.collection('artifacts').doc(appId);
  }

  static DocumentReference<Map<String, dynamic>> publicDataDoc() {
    return artifactsAppDoc().collection('public').doc('data');
  }

  static CollectionReference<Map<String, dynamic>> publicBranchesCol() {
    return publicDataDoc().collection('branches');
  }

  static CollectionReference<Map<String, dynamic>> publicBranchGroupsCol() {
    return publicDataDoc().collection('branch_groups');
  }

  static CollectionReference<Map<String, dynamic>> publicRolesCol() {
    return publicDataDoc().collection('roles');
  }

  static CollectionReference<Map<String, dynamic>> usersCol() {
    return artifactsAppDoc().collection('users');
  }

  static DocumentReference<Map<String, dynamic>> userMirrorDoc(String uid) {
    return usersCol().doc(uid);
  }

  /// `users/{uid}` 미러와 `users/{uid}/profile/main`을 합칩니다.
  /// 동일 키는 **profile/main**이 우선합니다(미러에만 있는 `mainAdmin` 등은 유지됨).
  static Map<String, dynamic> mergeUserMirrorAndProfileMain(
    Map<String, dynamic>? userMirror,
    Map<String, dynamic>? profileMain,
  ) {
    final Map<String, dynamic> out =
        Map<String, dynamic>.from(userMirror ?? const <String, dynamic>{});
    profileMain?.forEach((String k, dynamic v) {
      out[k] = v;
    });
    return out;
  }

  static Future<Map<String, dynamic>> fetchMergedUserProfileMain(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> mirror =
        await usersCol().doc(uid).get();
    final DocumentSnapshot<Map<String, dynamic>> main =
        await userProfileMainDoc(uid).get();
    return mergeUserMirrorAndProfileMain(mirror.data(), main.data());
  }

  static DocumentReference<Map<String, dynamic>> userProfileMainDoc(String uid) {
    return usersCol().doc(uid).collection('profile').doc('main');
  }

  /// 자료 송수신(요청/과제) 허브
  static CollectionReference<Map<String, dynamic>> submissionsCol() {
    return publicDataDoc().collection('submissions');
  }

  static CollectionReference<Map<String, dynamic>> submissionSitesCol(
    String submissionId,
  ) {
    return submissionsCol().doc(submissionId).collection('sites');
  }

  /// 커뮤니티 게시글 (boardType: notice | freeboard | anonymous)
  static CollectionReference<Map<String, dynamic>> postsCol() {
    return publicDataDoc().collection('posts');
  }

  /// 게시글 댓글 (`posts/{postId}/comments`)
  static CollectionReference<Map<String, dynamic>> postCommentsCol(
    String postId,
  ) {
    return postsCol().doc(postId).collection('comments');
  }

  /// 레거시 1건 단위 쪽지 (마이그레이션 전 데이터)
  static CollectionReference<Map<String, dynamic>> messagesCol() {
    return publicDataDoc().collection('messages');
  }

  /// 대화방 (1:1 / 그룹)
  static CollectionReference<Map<String, dynamic>> conversationsCol() {
    return publicDataDoc().collection('conversations');
  }

  static DocumentReference<Map<String, dynamic>> conversationDoc(String id) {
    return conversationsCol().doc(id);
  }

  /// 1:1 대화방 문서 id (`/` 금지 — 정렬된 두 uid로 고정)
  static String dmConversationId(String uidA, String uidB) {
    final List<String> sorted = <String>[uidA, uidB]..sort();
    return 'dm_${sorted[0]}_${sorted[1]}';
  }

  /// 나에게 보내기(메모) 대화방 문서 id
  static String selfConversationId(String myUid) {
    return 'self_${myUid.trim()}';
  }

  /// 대화방 메시지 스레드
  static CollectionReference<Map<String, dynamic>> conversationMessagesCol(
    String conversationId,
  ) {
    return conversationDoc(conversationId).collection('messages');
  }

  /// 사용자별 투두 (프라이빗)
  static CollectionReference<Map<String, dynamic>> userTodosCol(String uid) {
    return usersCol().doc(uid).collection('todos');
  }

  /// 알림(공용): business logic에서 대상 사업소/사용자 필드로 필터링
  static CollectionReference<Map<String, dynamic>> notificationsCol() {
    return publicDataDoc().collection('notifications');
  }

  static CollectionReference<Map<String, dynamic>> insuranceStatusCol() {
    return publicDataDoc().collection('insurance_status');
  }

  static CollectionReference<Map<String, dynamic>> dailyWorkersCol() {
    return publicDataDoc().collection('daily_workers');
  }

  /// 캘린더 일정 (전사/개인)
  static CollectionReference<Map<String, dynamic>> calendarEventsCol() {
    return publicDataDoc().collection('calendar_events');
  }

  /// 대용량 파일 전송(목록) — `fileKey` 필드로 R2 객체와 연결
  static CollectionReference<Map<String, dynamic>> transfersCol() {
    return publicDataDoc().collection('transfers');
  }

  /// R2 업로드 메타(경로·업로더·출처) — `fileKey`와 1:1
  static CollectionReference<Map<String, dynamic>> r2FileRegistryCol() {
    return publicDataDoc().collection('r2_file_registry');
  }

  /// Firestore 문서 id는 `/` 불가 — [fileKey]를 고정 규칙으로 인코딩
  static String r2RegistryDocIdFromFileKey(String fileKey) {
    return fileKey.replaceAll('/', '!');
  }

  /// 조직도 PDF (메인관리자 업로드, 1개)
  static DocumentReference<Map<String, dynamic>> companyOrgChartDoc() {
    return publicDataDoc().collection('company_assets').doc('org_chart');
  }

  /// 사규집: 규정(regulation) / 지침(guideline) PDF 목록
  static CollectionReference<Map<String, dynamic>> companyRuleFilesCol() {
    return publicDataDoc().collection('company_rule_files');
  }

  /// 문화의 날: 월별(또는 기간별) **게시용 번들**. 문서 id 예: `2026-04`
  static DocumentReference<Map<String, dynamic>> cultureDayBundleDoc(
    String monthKey,
  ) {
    return publicDataDoc().collection('culture_day_bundles').doc(monthKey);
  }

  /// 문화의 날: 관리자가 AI/n8n 파이프라인에 넘기는 **수집 작업 큐**
  static CollectionReference<Map<String, dynamic>> cultureDayIngestJobsCol() {
    return publicDataDoc().collection('culture_day_ingest_jobs');
  }

}
