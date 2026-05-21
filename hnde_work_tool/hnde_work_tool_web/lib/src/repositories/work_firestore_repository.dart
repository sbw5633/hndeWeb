import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/firestore_paths.dart';
import '../constants/super_admin.dart';
import '../models/board_comment_model.dart';
import '../models/branch_group_model.dart';
import '../models/branch_model.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_room_model.dart';
import '../models/inbox_message_model.dart';
import '../models/post_model.dart';
import '../models/submission_model.dart';
import '../models/submission_site_model.dart';
import '../models/company_rule_file_model.dart';
import '../models/todo_item_model.dart';
import '../models/app_notification_model.dart';
import '../services/r2_storage_service.dart';

/// 프로토타입 기능별 Firestore 접근 (확장 시 메서드만 추가)
class WorkFirestoreRepository {
  WorkFirestoreRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  String? get _uid => _auth.currentUser?.uid;

  // --- Presence (online/offline) ---
  Timer? _presenceTimer;
  bool _presenceStarted = false;
  static const Duration _presenceHeartbeatInterval = Duration(seconds: 30);

  /// 날짜별 마지막 목록 (메모리). 동일 날짜 재진입 시 즉시 표시 + 스냅샷 리스너로 갱신만 받음.
  final Map<String, List<TodoItemModel>> _todoDaySnapshotCache =
      <String, List<TodoItemModel>>{};

  final Map<String, List<SubmissionModel>> _submissionsListCache =
      <String, List<SubmissionModel>>{};

  final Map<String, List<PostModel>> _postsListCache =
      <String, List<PostModel>>{};

  final Map<String, PostModel> _postDetailCache = <String, PostModel>{};

  final Map<String, List<BoardCommentModel>> _postCommentsCache =
      <String, List<BoardCommentModel>>{};

  /// R2 서명 URL 캐시 (fileKey 기준, Future 캐시)
  final Map<String, Future<String>> _r2PresignedUrlCache =
      <String, Future<String>>{};

  final Map<String, List<Map<String, dynamic>>> _usersMirrorCache =
      <String, List<Map<String, dynamic>>>{};

  final Map<String, List<ConversationRoomModel>> _myConversationsCache =
      <String, List<ConversationRoomModel>>{};

  List<BranchModel>? _branchesCache;

  static const String _submissionsCacheKey = 'all';
  static const String _usersMirrorCacheKey = 'allUsersMirror';
  static const String _prefsCacheSubmissions = 'cache.dashboard.submissions.v1';
  static const String _prefsCacheUsersMirror = 'cache.dashboard.usersMirror.v1';

  Future<void> setPresenceOnline() async {
    final String? uid = _uid;
    if (uid == null) return;
    try {
      await FirestorePaths.usersCol().doc(uid).set(
        <String, dynamic>{
          'presenceState': 'online',
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      // 배포 규칙/권한/네트워크 이슈 등은 presence 기능만 조용히 실패 처리
      if (e.code == 'permission-denied') return;
      return;
    } on Object {
      return;
    }
  }

  Future<void> setPresenceOffline() async {
    final String? uid = _uid;
    if (uid == null) return;
    try {
      await FirestorePaths.usersCol().doc(uid).set(
        <String, dynamic>{
          'presenceState': 'offline',
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      return;
    } on Object {
      return;
    }
  }

  /// 앱 실행 중 주기적으로 lastActiveAt 갱신 (온라인 판정용)
  void startPresenceHeartbeat() {
    if (_presenceStarted) return;
    _presenceStarted = true;
    _presenceTimer?.cancel();
    // 즉시 1회 + 주기적 갱신
    unawaited(setPresenceOnline());
    _presenceTimer = Timer.periodic(_presenceHeartbeatInterval, (_) {
      unawaited(setPresenceOnline());
    });
  }

  void stopPresenceHeartbeat({bool setOffline = true}) {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _presenceStarted = false;
    if (setOffline) {
      unawaited(setPresenceOffline());
    }
  }

  // --- Submissions ---

  Stream<List<SubmissionModel>> watchSubmissions() async* {
    final List<SubmissionModel>? cached =
        _submissionsListCache[_submissionsCacheKey];

    if (cached == null) {
      final List<SubmissionModel>? seed = await _loadCachedSubmissionsFromPrefs();
      if (seed != null && seed.isNotEmpty) {
        _submissionsListCache[_submissionsCacheKey] =
            List<SubmissionModel>.from(seed);
        yield seed;
      }
    }

    final Stream<List<SubmissionModel>> live = FirestorePaths.submissionsCol()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> s) {
        final List<SubmissionModel> list =
            s.docs.map(SubmissionModel.fromDoc).toList();
        _submissionsListCache[_submissionsCacheKey] =
            List<SubmissionModel>.from(list);
        unawaited(_saveSubmissionsCacheToPrefs(list));
        return list;
      },
    );
    if (cached == null) {
      yield* live;
      return;
    }
    yield* _seedThenLiveList(cached, live);
  }

  Stream<SubmissionModel?> watchSubmission(String id) {
    return FirestorePaths.submissionsCol().doc(id).snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> d) =>
              d.exists ? SubmissionModel.fromDoc(d) : null,
        );
  }

  Future<String> createSubmission(SubmissionModel draft) async {
    final String? uid = _uid;
    if (uid == null) throw StateError('로그인 필요');
    final DocumentReference<Map<String, dynamic>> ref =
        await FirestorePaths.submissionsCol().add(draft.toCreateMap(uid));
    return ref.id;
  }

  /// 자료 요청 생성 (대상 사업소 지정)
  Future<String> createSubmissionWithSites(
    SubmissionModel draft, {
    required List<String> targetBranchIds,
    String? templateFileName,
    String? templateFileUrl,
    String? templateR2Key,
  }) async {
    final String? uid = _uid;
    if (uid == null) throw StateError('로그인 필요');

    final Map<String, dynamic> createMap = draft.toCreateMap(uid);
    if (templateFileName != null) {
      createMap['templateFileName'] = templateFileName;
    }
    if (templateFileUrl != null) {
      createMap['templateDownloadUrl'] = templateFileUrl;
    }
    if (templateR2Key != null && templateR2Key.trim().isNotEmpty) {
      createMap['templateR2Key'] = templateR2Key.trim();
    }

    final DocumentReference<Map<String, dynamic>> ref =
        await FirestorePaths.submissionsCol().add(createMap);
    final String submissionId = ref.id;
    final CollectionReference<Map<String, dynamic>> sitesCol =
        FirestorePaths.submissionSitesCol(submissionId);

    final WriteBatch batch = _db.batch();
    for (final String branchId in targetBranchIds) {
      batch.set(
        sitesCol.doc(branchId),
        <String, dynamic>{
          'label': branchId,
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
    await _notifySubmissionCreated(
      submissionId: submissionId,
      title: draft.title,
      targetBranchIds: targetBranchIds,
    );
    return submissionId;
  }

  Stream<List<BranchModel>> watchBranches() {
    final List<BranchModel>? cached = _branchesCache;
    final Stream<List<BranchModel>> live = FirestorePaths.publicBranchesCol()
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> s) {
      final List<BranchModel> list =
          s.docs.map(BranchModel.fromDoc).toList()
            ..sort((BranchModel a, BranchModel b) => a.name.compareTo(b.name));
      _branchesCache = List<BranchModel>.from(list);
      return list;
    });
    if (cached == null) {
      return live;
    }
    return _seedThenLiveList(List<BranchModel>.from(cached), live);
  }

  // --- Users mirror (admin list) ---

  /// users/{uid} 미러에 없는 필드를 profile/main에서 1회 백필합니다.
  /// (인사관리 탭 등에서 users/{uid}만 읽어도 즉시 표시되도록)
  final Set<String> _usersMirrorBackfillInFlight = <String>{};

  Future<void> _backfillUsersMirrorIfMissing({
    required String uid,
    required Map<String, dynamic> mirror,
  }) async {
    final String u = uid.trim();
    if (u.isEmpty) return;
    final String curPos = (mirror['position'] as String?)?.trim() ?? '';
    if (curPos.isNotEmpty) return;
    if (_usersMirrorBackfillInFlight.contains(u)) return;
    _usersMirrorBackfillInFlight.add(u);
    try {
      final DocumentSnapshot<Map<String, dynamic>> p =
          await FirestorePaths.userProfileMainDoc(u).get();
      final Map<String, dynamic> pd = p.data() ?? <String, dynamic>{};
      final String pos = (pd['position'] as String?)?.trim() ?? '';
      if (pos.isEmpty) return;
      await FirestorePaths.usersCol()
          .doc(u)
          .set(<String, dynamic>{'position': pos}, SetOptions(merge: true));
    } catch (_) {
      return;
    } finally {
      _usersMirrorBackfillInFlight.remove(u);
    }
  }

  Stream<List<Map<String, dynamic>>> watchUsersMirror() async* {
    final List<Map<String, dynamic>>? cached =
        _usersMirrorCache[_usersMirrorCacheKey];

    if (cached == null) {
      final List<Map<String, dynamic>>? seed =
          await _loadCachedUsersMirrorFromPrefs();
      if (seed != null && seed.isNotEmpty) {
        _usersMirrorCache[_usersMirrorCacheKey] =
            List<Map<String, dynamic>>.from(seed);
        yield seed;
      }
    }

    final Stream<List<Map<String, dynamic>>> live =
        FirestorePaths.usersCol().snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> s) {
        final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d in s.docs) {
          final Map<String, dynamic> item = <String, dynamic>{
            'uid': d.id,
            ...d.data(),
          };
          unawaited(
            _backfillUsersMirrorIfMissing(uid: d.id, mirror: item),
          );
          list.add(item);
        }
        list.sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              ((a['displayName'] ?? a['name'] ?? a['email'] ?? '') as String)
                  .toString()
                  .compareTo(
                    ((b['displayName'] ?? b['name'] ?? b['email'] ?? '') as String)
                        .toString(),
                  ),
        );
        _usersMirrorCache[_usersMirrorCacheKey] =
            List<Map<String, dynamic>>.from(list);
        unawaited(_saveUsersMirrorCacheToPrefs(list));
        return list;
      },
    );
    if (cached == null) {
      yield* live;
      return;
    }
    yield* _seedThenLiveList(cached, live);
  }

  Future<void> _saveSubmissionsCacheToPrefs(List<SubmissionModel> list) async {
    try {
      final SharedPreferences p = await _prefs;
      final List<Map<String, dynamic>> out = list.take(200).map((SubmissionModel s) {
        return <String, dynamic>{
          'id': s.id,
          'title': s.title,
          'description': s.description,
          'urgency': s.urgency,
          'dueAtMs': s.dueDate?.millisecondsSinceEpoch,
          'createdByUid': s.createdByUid,
          'createdAtMs': s.createdAt?.millisecondsSinceEpoch,
          'departmentLabel': s.departmentLabel,
        };
      }).toList();
      await p.setString(_prefsCacheSubmissions, jsonEncode(out));
    } catch (_) {
      return;
    }
  }

  Future<List<SubmissionModel>?> _loadCachedSubmissionsFromPrefs() async {
    try {
      final SharedPreferences p = await _prefs;
      final String? raw = p.getString(_prefsCacheSubmissions);
      if (raw == null || raw.trim().isEmpty) return null;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final List<SubmissionModel> out = <SubmissionModel>[];
      for (final Object? e in decoded) {
        if (e is! Map) continue;
        final Map<String, dynamic> m = e.cast<String, dynamic>();
        final String id = (m['id'] as String?) ?? '';
        if (id.trim().isEmpty) continue;
        out.add(
          SubmissionModel(
            id: id,
            title: (m['title'] as String?) ?? '',
            description: (m['description'] as String?) ?? '',
            urgency: (m['urgency'] as String?) ?? 'general',
            dueDate: (m['dueAtMs'] is num)
                ? Timestamp.fromMillisecondsSinceEpoch((m['dueAtMs'] as num).toInt())
                : null,
            createdByUid: (m['createdByUid'] as String?) ?? '',
            createdAt: (m['createdAtMs'] is num)
                ? Timestamp.fromMillisecondsSinceEpoch((m['createdAtMs'] as num).toInt())
                : null,
            departmentLabel: (m['departmentLabel'] as String?) ?? '',
          ),
        );
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUsersMirrorCacheToPrefs(List<Map<String, dynamic>> list) async {
    try {
      final SharedPreferences p = await _prefs;
      final List<Map<String, dynamic>> out = list.take(300).map((Map<String, dynamic> u) {
        // 너무 큰 데이터는 줄여서 저장
        return <String, dynamic>{
          'uid': (u['uid'] ?? '').toString(),
          'name': u['name'],
          'displayName': u['displayName'],
          'email': u['email'],
        };
      }).toList();
      await p.setString(_prefsCacheUsersMirror, jsonEncode(out));
    } catch (_) {
      return;
    }
  }

  Future<List<Map<String, dynamic>>?> _loadCachedUsersMirrorFromPrefs() async {
    try {
      final SharedPreferences p = await _prefs;
      final String? raw = p.getString(_prefsCacheUsersMirror);
      if (raw == null || raw.trim().isEmpty) return null;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
      for (final Object? e in decoded) {
        if (e is! Map) continue;
        final Map<String, dynamic> m = e.cast<String, dynamic>();
        final String uid = (m['uid'] ?? '').toString().trim();
        if (uid.isEmpty) continue;
        out.add(<String, dynamic>{...m, 'uid': uid});
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserAndProfile({
    required String uid,
    required Map<String, dynamic> userPatch,
    required Map<String, dynamic> profilePatch,
  }) async {
    final WriteBatch batch = _db.batch();
    batch.set(FirestorePaths.usersCol().doc(uid), userPatch, SetOptions(merge: true));
    batch.set(FirestorePaths.userProfileMainDoc(uid), profilePatch, SetOptions(merge: true));
    await batch.commit();
  }

  Future<String?> uploadProfilePhotoAndGetUrl(PlatformFile file) async {
    final R2UploadResult r = await uploadTemplateToR2(
      file,
      r2RegistrySource: 'profile',
      r2RegistrySourcePath: 'photo',
    );
    return r.fileUrl;
  }

  Future<void> requestBranchChange({
    required String uid,
    required String nextBranchName,
  }) async {
    final Map<String, dynamic> patch = <String, dynamic>{
      'pendingBranch': nextBranchName,
      'pendingBranchStatus': 'pending',
      'pendingBranchRequestedAt': FieldValue.serverTimestamp(),
    };
    await updateUserAndProfile(uid: uid, userPatch: patch, profilePatch: patch);
  }

  Future<void> cancelBranchChangeRequest({required String uid}) async {
    final Map<String, dynamic> patch = <String, dynamic>{
      'pendingBranch': FieldValue.delete(),
      'pendingBranchStatus': FieldValue.delete(),
      'pendingBranchRequestedAt': FieldValue.delete(),
      'pendingBranchDecisionAt': FieldValue.delete(),
    };
    await updateUserAndProfile(uid: uid, userPatch: patch, profilePatch: patch);
  }

  Future<void> approveBranchChange({
    required String uid,
    required String nextBranchName,
  }) async {
    final Map<String, dynamic> patchUser = <String, dynamic>{
      'branch': nextBranchName,
      'branchName': nextBranchName,
      'pendingBranch': FieldValue.delete(),
      'pendingBranchStatus': 'approved',
      'pendingBranchDecisionAt': FieldValue.serverTimestamp(),
      'pendingBranchRequestedAt': FieldValue.delete(),
    };
    final Map<String, dynamic> patchProfile = <String, dynamic>{
      'branch': nextBranchName,
      'branchName': nextBranchName,
      'pendingBranch': FieldValue.delete(),
      'pendingBranchStatus': 'approved',
      'pendingBranchDecisionAt': FieldValue.serverTimestamp(),
      'pendingBranchRequestedAt': FieldValue.delete(),
    };
    await updateUserAndProfile(uid: uid, userPatch: patchUser, profilePatch: patchProfile);
  }

  Future<void> rejectBranchChange({
    required String uid,
  }) async {
    final Map<String, dynamic> patch = <String, dynamic>{
      'pendingBranch': FieldValue.delete(),
      'pendingBranchStatus': 'rejected',
      'pendingBranchDecisionAt': FieldValue.serverTimestamp(),
      'pendingBranchRequestedAt': FieldValue.delete(),
    };
    await updateUserAndProfile(uid: uid, userPatch: patch, profilePatch: patch);
  }

  Stream<List<BranchGroupModel>> watchBranchGroups() {
    return FirestorePaths.publicBranchGroupsCol()
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> s) =>
              s.docs.map(BranchGroupModel.fromDoc).toList(),
        );
  }

  /// 에이치앤디이 → 더웨이유통 순 정렬용 키
  static const List<String> _groupOrder = <String>[
    'HDNE_MAIN',    // 에이치앤디이 사업소
    'THEWAY_MAIN',  // 더웨이유통 사업소
  ];

  /// 기본 그룹 (Firestore에 없을 때 보충)
  static final List<BranchGroupModel> _defaultGroups = <BranchGroupModel>[
    BranchGroupModel(
      key: 'HDNE_MAIN',
      label: '에이치앤디이 사업소',
      branchNames: <String>[
        '본사', '만남(부산)휴게소', '진영(순천)휴게소', '장안(울산)휴게소',
        '장안(부산)휴게소', '동명(춘천)휴게소', '동명(부산)휴게소',
        '송산휴게소', '선산(창원)휴게소',
      ],
    ),
    BranchGroupModel(
      key: 'THEWAY_MAIN',
      label: '더웨이유통 사업소',
      branchNames: <String>[
        '더웨이유통본사', '진안(장수)휴게소', '진안(장수)주유소',
        '진안(익산)주유소', '선산(양평)주유소', '선산(창원)주유소',
      ],
    ),
  ];

  /// 브랜치+그룹 동시 스트림 (에이치앤디이 → 더웨이유통 순 정렬)
  Stream<(List<BranchModel> branches, List<BranchGroupModel> groups)>
      watchBranchesAndGroups() {
    return watchBranches().asyncMap(
      (List<BranchModel> branches) async {
        List<BranchGroupModel> groups =
            await watchBranchGroups().first;

        final Map<String, BranchGroupModel> byKey = {
          for (final BranchGroupModel g in groups) g.key: g,
        };
        final List<BranchGroupModel> ordered = <BranchGroupModel>[];
        for (final String k in _groupOrder) {
          if (byKey.containsKey(k)) {
            ordered.add(byKey[k]!);
          } else {
            final idx = _defaultGroups.indexWhere((g) => g.key == k);
            if (idx >= 0) ordered.add(_defaultGroups[idx]);
          }
        }
        groups = ordered.isNotEmpty ? ordered : _defaultGroups;

        final Map<String, BranchModel> branchMap = {
          for (final BranchModel b in branches) b.id: b,
        };
        final List<BranchModel> sortedBranches = <BranchModel>[];
        for (final BranchGroupModel g in groups) {
          for (final String name in g.branchNames) {
            final BranchModel? b = branchMap[name];
            if (b != null) {
              sortedBranches.add(b);
            }
          }
        }
        for (final BranchModel b in branches) {
          if (!sortedBranches.any((x) => x.id == b.id)) {
            sortedBranches.add(b);
          }
        }
        return (sortedBranches, groups);
      },
    );
  }

  /// 여러 파일을 한 번에 업로드(또는 R2 URL 반환 후) 저장 — 기존 항목과 합침
  Future<void> submitSubmissionSiteFiles({
    required String submissionId,
    required String siteDocId,
    required List<PlatformFile> newFiles,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        FirestorePaths.submissionSitesCol(submissionId).doc(siteDocId);
    final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
    final List<SubmittedFileItem> existing = <SubmittedFileItem>[];
    if (doc.exists) {
      final SubmissionSiteModel m =
          SubmissionSiteModel.fromDoc(doc);
      existing.addAll(m.allSubmittedFiles);
    }
    final List<SubmittedFileItem> uploaded = <SubmittedFileItem>[];
    final DocumentSnapshot<Map<String, dynamic>> subDoc =
        await FirestorePaths.submissionsCol().doc(submissionId).get();
    final String subTitle =
        (subDoc.data()?['title'] as String?)?.trim().isNotEmpty == true
            ? (subDoc.data()!['title'] as String)
            : '요청';
    for (final PlatformFile f in newFiles) {
      final R2UploadResult up = await uploadTemplateToR2(
        f,
        r2RegistrySource: '자료송수신',
        r2RegistrySourcePath: '자료송수신 > $subTitle > $siteDocId',
      );
      uploaded.add(
        SubmittedFileItem(
          fileUrl: up.fileUrl,
          fileName: f.name,
          fileKey: up.fileKey,
        ),
      );
    }
    final List<SubmittedFileItem> merged = <SubmittedFileItem>[
      ...existing,
      ...uploaded,
    ];
    await ref.set(
      <String, dynamic>{
        'status': 'submitted',
        'submittedFiles': merged.map((SubmittedFileItem e) => e.toMap()).toList(),
        'submittedFileUrl': FieldValue.delete(),
        'submittedFileName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// 단일 파일 제출 (기존 호환)
  Future<void> setSubmissionSiteFile({
    required String submissionId,
    required String siteDocId,
    required String fileUrl,
    required String fileName,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        FirestorePaths.submissionSitesCol(submissionId).doc(siteDocId);
    final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
    final List<SubmittedFileItem> existing = <SubmittedFileItem>[];
    if (doc.exists) {
      existing.addAll(SubmissionSiteModel.fromDoc(doc).allSubmittedFiles);
    }
    existing.add(
      SubmittedFileItem(fileUrl: fileUrl, fileName: fileName),
    );
    await ref.set(
      <String, dynamic>{
        'status': 'submitted',
        'submittedFiles': existing.map((SubmittedFileItem e) => e.toMap()).toList(),
        'submittedFileUrl': FieldValue.delete(),
        'submittedFileName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// 파일 한 건 회수 (확인 전에만 가능)
  Future<void> recallSubmissionSiteFile({
    required String submissionId,
    required String siteDocId,
    required String fileUrlToRemove,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        FirestorePaths.submissionSitesCol(submissionId).doc(siteDocId);
    final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
    if (!doc.exists) return;
    final String? status = doc.data()?['status'] as String?;
    if (status == 'approved') {
      throw StateError('요청처 확인 완료 후에는 회수할 수 없습니다.');
    }
    final List<SubmittedFileItem> list =
        SubmissionSiteModel.fromDoc(doc).allSubmittedFiles;
    final List<SubmittedFileItem> next = list
        .where((SubmittedFileItem e) => e.fileUrl != fileUrlToRemove)
        .toList();
    if (next.isEmpty) {
      await ref.update(<String, dynamic>{
        'status': 'pending',
        'submittedFiles': FieldValue.delete(),
        'submittedFileUrl': FieldValue.delete(),
        'submittedFileName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update(<String, dynamic>{
        'status': 'submitted',
        'submittedFiles': next.map((SubmittedFileItem e) => e.toMap()).toList(),
        'submittedFileUrl': FieldValue.delete(),
        'submittedFileName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// 전체 제출 회수 (확인 전에만 가능)
  Future<void> recallSubmissionSite({
    required String submissionId,
    required String siteDocId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirestorePaths
        .submissionSitesCol(submissionId)
        .doc(siteDocId)
        .get();
    if (!doc.exists) return;
    final String? status = doc.data()?['status'] as String?;
    if (status == 'approved') {
      throw StateError('요청처 확인 완료 후에는 회수할 수 없습니다.');
    }
    await doc.reference.update(<String, dynamic>{
      'status': 'pending',
      'submittedFiles': FieldValue.delete(),
      'submittedFileUrl': FieldValue.delete(),
      'submittedFileName': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  /// 파일 업로드 후 R2 URL 반환 (경로는 Firestore에 저장)
  /// [r2RegistrySource]·[r2RegistrySourcePath]가 모두 비어 있지 않으면 `r2_file_registry`에 기록
  Future<String> uploadTemplateAndGetUrl(
    PlatformFile file, {
    String? r2RegistrySource,
    String? r2RegistrySourcePath,
  }) async {
    final R2UploadResult r = await uploadTemplateToR2(
      file,
      r2RegistrySource: r2RegistrySource,
      r2RegistrySourcePath: r2RegistrySourcePath,
    );
    return r.fileUrl;
  }

  /// R2 업로드 전체 결과 (fileKey 포함)
  Future<R2UploadResult> uploadTemplateToR2(
    PlatformFile file, {
    String? r2RegistrySource,
    String? r2RegistrySourcePath,
  }) async {
    final R2StorageService storage = R2StorageService();
    final R2UploadResult result = await storage.uploadFile(file);
    if (r2RegistrySource != null &&
        r2RegistrySourcePath != null &&
        r2RegistrySource.trim().isNotEmpty &&
        r2RegistrySourcePath.trim().isNotEmpty) {
      await recordR2Upload(
        fileKey: result.fileKey,
        fileUrl: result.fileUrl,
        source: r2RegistrySource.trim(),
        sourcePath: r2RegistrySourcePath.trim(),
      );
    }
    return result;
  }

  /// R2 업로드 메타데이터 (메인관리자 파일 관리용)
  Future<void> recordR2Upload({
    required String fileKey,
    required String fileUrl,
    required String source,
    required String sourcePath,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> prof =
        await FirestorePaths.userProfileMainDoc(uid).get();
    final Map<String, dynamic>? d = prof.data();
    String displayName = uid;
    if (d != null) {
      final String? dn = (d['displayName'] as String?)?.trim();
      if (dn != null && dn.isNotEmpty) {
        displayName = dn;
      } else {
        final String? em = (d['email'] as String?)?.trim();
        if (em != null && em.isNotEmpty) {
          displayName = em;
        }
      }
    }
    await FirestorePaths.r2FileRegistryCol()
        .doc(FirestorePaths.r2RegistryDocIdFromFileKey(fileKey))
        .set(
          <String, dynamic>{
            'fileKey': fileKey,
            'fileUrl': fileUrl,
            'uploadedByUid': uid,
            'uploadedByDisplayName': displayName,
            'source': source,
            'sourcePath': sourcePath,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  /// 저장된 fileUrl + (선택) fileKey로 presigned 다운로드 URL 생성 (브라우저용)
  /// [fileKey]가 있으면 URL 파싱을 하지 않음 (구 데이터는 URL에서만 추출)
  Future<String> getPresignedDownloadUrl(
    String fileUrl, {
    String? fileKey,
    String? fileName,
  }) async {
    final String? resolved = (fileKey != null && fileKey.trim().isNotEmpty)
        ? fileKey.trim()
        : R2StorageService.fileKeyFromUrl(fileUrl);
    if (resolved == null || resolved.isEmpty) {
      throw StateError('잘못된 다운로드 URL 형식: $fileUrl');
    }
    final R2StorageService storage = R2StorageService();
    return storage.getPresignedDownloadUrl(resolved, fileName: fileName);
  }

  /// 이미지/미리보기 렌더용 서명 URL.
  /// - 저장된 [fileUrl]이 바로 접근 가능한 URL이면 그대로 써도 되지만,
  ///   Worker/R2 정책에 따라 인증·서명이 필요할 수 있어 여기서 통일합니다.
  /// - 내부적으로 fileKey 단위로 Future 캐시합니다.
  Future<String> getPresignedViewUrl(String fileUrl) {
    final String? key = R2StorageService.fileKeyFromUrl(fileUrl);
    if (key == null || key.trim().isEmpty) {
      return Future<String>.error(
        StateError('잘못된 파일 URL 형식: $fileUrl'),
      );
    }
    return _r2PresignedUrlCache.putIfAbsent(
      key,
      () => getPresignedDownloadUrl(fileUrl, fileKey: key),
    );
  }

  Stream<List<SubmissionSiteModel>> watchSubmissionSites(String submissionId) {
    return FirestorePaths.submissionSitesCol(submissionId)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> s) =>
              s.docs.map(SubmissionSiteModel.fromDoc).toList(),
        );
  }

  Future<void> setSubmissionSiteStatus({
    required String submissionId,
    required String siteDocId,
    required String status,
    String? reRequestComment,
  }) {
    final Map<String, dynamic> m = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 're_requested' &&
        reRequestComment != null &&
        reRequestComment.trim().isNotEmpty) {
      m['reRequestComment'] = reRequestComment.trim();
      m['reRequestAt'] = FieldValue.serverTimestamp();
    }
    return FirestorePaths.submissionSitesCol(submissionId)
        .doc(siteDocId)
        .set(m, SetOptions(merge: true));
  }

  Future<void> ensureDefaultSubmissionSites(
    String submissionId, [
    List<String>? branchIds,
  ]) async {
    final CollectionReference<Map<String, dynamic>> col =
        FirestorePaths.submissionSitesCol(submissionId);
    final QuerySnapshot<Map<String, dynamic>> snap = await col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final List<String> ids = branchIds?.isNotEmpty == true
        ? branchIds!
        : <String>['본사', '에이치앤디이', '더웨이유통'];

    final WriteBatch batch = _db.batch();
    for (final String id in ids) {
      batch.set(
        col.doc(id),
        <String, dynamic>{
          'label': id,
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  // --- Posts ---

  /// 게시판 목록: `boardType` 동등 필터 + `createdAt` 내림차순(복합 인덱스 필요).
  Stream<List<PostModel>> watchPosts(String boardType) {
    final List<PostModel>? cached = _postsListCache[boardType];
    final Stream<List<PostModel>> live = FirestorePaths.postsCol()
        .where('boardType', isEqualTo: boardType)
        .where('deleted', isEqualTo: false)
        .where('isLatest', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> s) {
        final List<PostModel> list =
            s.docs.map(PostModel.fromDoc).toList();
        _postsListCache[boardType] = List<PostModel>.from(list);
        return list;
      },
    );
    if (cached == null) {
      return live;
    }
    return _seedThenLiveList(cached, live);
  }

  Stream<PostModel?> watchPost(String id) {
    final PostModel? cached = _postDetailCache[id];
    final Stream<PostModel?> live =
        FirestorePaths.postsCol().doc(id).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> d) {
        final PostModel? p =
            d.exists ? PostModel.fromDoc(d) : null;
        if (p != null) {
          _postDetailCache[id] = p;
        } else {
          _postDetailCache.remove(id);
        }
        return p;
      },
    );
    if (cached == null) {
      return live;
    }
    return _postDetailSeedThenLive(cached, live);
  }

  Stream<List<BoardCommentModel>> watchPostComments(String postId) {
    final List<BoardCommentModel>? cached = _postCommentsCache[postId];
    final Stream<List<BoardCommentModel>> live =
        FirestorePaths.postCommentsCol(postId)
            .orderBy('createdAt', descending: false)
            .snapshots()
            .map(
      (QuerySnapshot<Map<String, dynamic>> s) {
        final List<BoardCommentModel> list =
            s.docs.map(BoardCommentModel.fromDoc).toList();
        _postCommentsCache[postId] = List<BoardCommentModel>.from(list);
        return list;
      },
    );
    if (cached == null) {
      return live;
    }
    return _seedThenLiveList(cached, live);
  }

  Future<void> addPostComment(String postId, String body) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final String t = body.trim();
    if (t.isEmpty) {
      throw StateError('댓글 내용을 입력하세요.');
    }
    if (t.length > 300) {
      throw StateError('댓글은 300자 이하로 입력하세요.');
    }

    final DocumentReference<Map<String, dynamic>> userMain =
        FirestorePaths.userProfileMainDoc(uid);
    final DocumentSnapshot<Map<String, dynamic>> prof = await userMain.get();
    final Map<String, dynamic> p = prof.data() ?? <String, dynamic>{};
    final String display =
        '${p['name'] ?? ''} ${p['position'] ?? ''}'.trim().isEmpty
            ? (_auth.currentUser?.email ?? '사용자')
            : '${p['name'] ?? ''} ${p['position'] ?? ''}'.trim();
    final String? photoUrl = (p['photoUrl'] as String?)?.trim().isNotEmpty == true
        ? (p['photoUrl'] as String).trim()
        : null;

    final BoardCommentModel model = BoardCommentModel(
      id: '',
      body: t,
    );
    await FirestorePaths.postCommentsCol(postId).add(
          model.toCreateMap(
            authorUid: uid,
            authorDisplay: display,
            authorPhotoUrl: photoUrl,
          ),
        );

    final DocumentSnapshot<Map<String, dynamic>> post =
        await FirestorePaths.postsCol().doc(postId).get();
    final Map<String, dynamic>? pd = post.data();
    final String boardType = (pd?['boardType'] as String?)?.trim().isNotEmpty == true
        ? (pd!['boardType'] as String).trim()
        : 'notice';
    final String postTitle = (pd?['title'] as String?)?.trim() ?? '';
    final String? authorUid = pd?['authorUid'] as String?;
    await _notifyPostCommented(
      postId: postId,
      boardType: boardType,
      postTitle: postTitle,
      postAuthorUid: authorUid,
    );
  }

  Future<void> incrementReadCount(String postId) {
    return FirestorePaths.postsCol().doc(postId).update(<String, dynamic>{
      'readCount': FieldValue.increment(1),
    });
  }

  Future<String> createPost({
    required String boardType,
    required String title,
    required String body,
    List<String> imageUrls = const <String>[],
    bool isOfficial = false,
    bool anonymous = false,
  }) async {
    final String? uid = _uid;
    if (uid == null) throw StateError('로그인 필요');

    final String t = title.trim();
    final String b = body.trim();
    if (t.length > 50) {
      throw StateError('제목은 50자 이하로 입력하세요.');
    }
    if (b.length > 3000) {
      throw StateError('내용은 3000자 이하로 입력하세요.');
    }

    final DocumentReference<Map<String, dynamic>> userMain =
        FirestorePaths.userProfileMainDoc(uid);
    final DocumentSnapshot<Map<String, dynamic>> prof = await userMain.get();
    final Map<String, dynamic> p = prof.data() ?? <String, dynamic>{};
    final String display =
        '${p['name'] ?? ''} ${p['position'] ?? ''}'.trim().isEmpty
            ? (_auth.currentUser?.email ?? '사용자')
            : '${p['name'] ?? ''} ${p['position'] ?? ''}'.trim();
    final String? photoUrl = (p['photoUrl'] as String?)?.trim().isNotEmpty == true
        ? (p['photoUrl'] as String).trim()
        : null;

    final List<String> urls = imageUrls
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .take(5)
        .toList();

    final PostModel model = PostModel(
      id: '',
      title: t,
      body: b,
      boardType: boardType,
      isOfficial: isOfficial,
      imageUrls: urls,
    );

    final DocumentReference<Map<String, dynamic>> ref =
        await FirestorePaths.postsCol().add(
      model.toCreateMap(
        boardType: boardType,
        // 익명 게시판도 DB에는 작성자 UID를 저장(감사/알림/권한용). UI에서만 가립니다.
        authorUid: uid,
        authorDisplay: anonymous ? '익명' : display,
        authorPhotoUrl: anonymous ? null : photoUrl,
      ),
    );
    // 알림은 게시글 저장을 막지 않도록 비동기로 처리
    unawaited(
      _notifyPostCreated(
        postId: ref.id,
        boardType: boardType,
        postTitle: t,
      ).catchError((_) {}),
    );
    return ref.id;
  }

  Future<int> _myRoleIdx() async {
    final String? uid = _uid;
    if (uid == null) return 999;
    try {
      final Map<String, dynamic> d = await FirestorePaths.fetchMergedUserProfileMain(uid);
      return (d['roleIdx'] as num?)?.toInt() ?? 999;
    } catch (_) {
      return 999;
    }
  }

  bool _isDeleteAdminRoleIdx(int roleIdx) => roleIdx == 0 || roleIdx == 1;

  Future<void> deletePostSoft(String postId) async {
    final String? uid = _uid;
    if (uid == null) throw StateError('로그인 필요');
    final DocumentReference<Map<String, dynamic>> ref =
        FirestorePaths.postsCol().doc(postId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    final Map<String, dynamic> d = snap.data() ?? <String, dynamic>{};
    final String authorUid = (d['authorUid'] as String?)?.trim() ?? '';
    final bool isAuthor = authorUid.isNotEmpty && authorUid == uid;
    final int roleIdx = await _myRoleIdx();
    final bool isAdmin = _isDeleteAdminRoleIdx(roleIdx);
    if (!isAuthor && !isAdmin) {
      throw StateError('삭제 권한이 없습니다.');
    }
    await ref.set(<String, dynamic>{
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedByUid': uid,
    }, SetOptions(merge: true));
  }

  Future<String> editPostCreateRevision({
    required String postId,
    required String title,
    required String body,
  }) async {
    final String? uid = _uid;
    if (uid == null) throw StateError('로그인 필요');
    final DocumentReference<Map<String, dynamic>> oldRef =
        FirestorePaths.postsCol().doc(postId);
    final DocumentSnapshot<Map<String, dynamic>> oldSnap = await oldRef.get();
    if (!oldSnap.exists) {
      throw StateError('게시글을 찾을 수 없습니다.');
    }
    final Map<String, dynamic> old = oldSnap.data() ?? <String, dynamic>{};
    final String authorUid = (old['authorUid'] as String?)?.trim() ?? '';
    final bool isAuthor = authorUid.isNotEmpty && authorUid == uid;
    final int roleIdx = await _myRoleIdx();
    final bool isAdmin = _isDeleteAdminRoleIdx(roleIdx);
    if (!isAuthor && !isAdmin) {
      throw StateError('수정 권한이 없습니다.');
    }
    final String boardType = (old['boardType'] as String?)?.trim().isNotEmpty == true
        ? (old['boardType'] as String).trim()
        : 'freeboard';
    final bool isOfficial = old['isOfficial'] as bool? ?? false;
    final List<String> oldUrls = <String>[];
    final dynamic rawUrls = old['imageUrls'];
    if (rawUrls is List) {
      for (final dynamic e in rawUrls) {
        if (e is String && e.trim().isNotEmpty) oldUrls.add(e.trim());
      }
    }
    final String rootPostId = (old['rootPostId'] as String?)?.trim().isNotEmpty == true
        ? (old['rootPostId'] as String).trim()
        : postId;

    final String t = title.trim();
    final String b = body.trim();
    if (t.isEmpty) throw StateError('제목을 입력하세요.');
    if (b.isEmpty) throw StateError('내용을 입력하세요.');
    if (t.length > 50) throw StateError('제목은 50자 이하로 입력하세요.');
    if (b.length > 3000) throw StateError('내용은 3000자 이하로 입력하세요.');

    final DocumentReference<Map<String, dynamic>> userMain =
        FirestorePaths.userProfileMainDoc(uid);
    final DocumentSnapshot<Map<String, dynamic>> prof = await userMain.get();
    final Map<String, dynamic> p = prof.data() ?? <String, dynamic>{};
    final String myDisplay =
        '${p['name'] ?? ''} ${p['position'] ?? ''}'.trim().isEmpty
            ? (_auth.currentUser?.email ?? '사용자')
            : '${p['name'] ?? ''} ${p['position'] ?? ''}'.trim();
    final String? myPhotoUrl =
        (p['photoUrl'] as String?)?.trim().isNotEmpty == true
            ? (p['photoUrl'] as String).trim()
            : null;
    /// 관리자가 다른 사람 글을 수정하는 경우 원작성자 정보 보존.
    final bool keepOriginalAuthor = isAdmin && !isAuthor;
    final String preservedAuthorUid =
        keepOriginalAuthor ? authorUid : uid;
    final String preservedAuthorDisplay = keepOriginalAuthor
        ? ((old['authorDisplay'] as String?) ?? myDisplay)
        : (old['authorDisplay'] == '익명' ? '익명' : myDisplay);
    final String? preservedAuthorPhotoUrl = keepOriginalAuthor
        ? (old['authorPhotoUrl'] as String?)
        : (old['authorDisplay'] == '익명' ? null : myPhotoUrl);

    final DocumentReference<Map<String, dynamic>> newRef =
        FirestorePaths.postsCol().doc();
    final WriteBatch batch = _db.batch();
    batch.set(newRef, <String, dynamic>{
      'title': t,
      'body': b,
      'boardType': boardType,
      'authorUid': preservedAuthorUid,
      'authorDisplay': preservedAuthorDisplay,
      if (preservedAuthorPhotoUrl != null)
        'authorPhotoUrl': preservedAuthorPhotoUrl
      else
        'authorPhotoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': FieldValue.serverTimestamp(),
      if (keepOriginalAuthor) 'editedByUid': uid,
      'readCount': 0,
      'isOfficial': isOfficial,
      if (oldUrls.isNotEmpty) 'imageUrls': oldUrls,
      'deleted': false,
      'deletedAt': null,
      'deletedByUid': null,
      'isLatest': true,
      'revisionOf': postId,
      'rootPostId': rootPostId,
    });
    batch.set(oldRef, <String, dynamic>{
      'isLatest': false,
      'supersededBy': newRef.id,
      'supersededAt': FieldValue.serverTimestamp(),
      // 원본은 수정 시간이 아니라 "대체됨"만 기록합니다.
    }, SetOptions(merge: true));
    await batch.commit();
    return newRef.id;
  }

  /// 게시글 본문 이미지 업로드 (R2, URL만 반환)
  Future<String> uploadBoardImage(PlatformFile file) async {
    final R2UploadResult r = await uploadTemplateToR2(file);
    return r.fileUrl;
  }

  /// 로그아웃 등으로 `currentUser`가 바뀌면 Firestore 스트림이 끊기지 않고
  /// `await for`가 영원히 대기하는 경우가 있어, 인증 상태와 함께 강제로 닫습니다.
  ///
  /// 구독 취소는 **동일 스택에서 리스너 본인을 cancel하지 않도록** 마이크로태스크로
  /// 지연합니다. (웹 등에서 `authStateChanges` 콜백 안 `subAuth.cancel()` 시 UI 멈춤 방지)
  Stream<T> _guardFirestoreStreamWithAuth<T>(String boundUid, Stream<T> inner) {
    StreamSubscription<T>? subInner;
    StreamSubscription<User?>? subAuth;

    late final StreamController<T> controller;

    void cancelBindingsInMicrotask({
      required bool closeController,
      Object? error,
      StackTrace? stack,
    }) {
      final StreamSubscription<T>? innerSub = subInner;
      final StreamSubscription<User?>? authSub = subAuth;
      subInner = null;
      subAuth = null;
      scheduleMicrotask(() {
        try {
          innerSub?.cancel();
        } catch (_) {}
        try {
          authSub?.cancel();
        } catch (_) {}
        if (!controller.isClosed) {
          if (error != null && stack != null) {
            controller.addError(error, stack);
          } else if (closeController) {
            controller.close();
          }
        }
      });
    }

    controller = StreamController<T>(
      onListen: () {
        subAuth = _auth.authStateChanges().listen((User? u) {
          if (u?.uid != boundUid) {
            cancelBindingsInMicrotask(closeController: true);
          }
        });
        subInner = inner.listen(
          (T event) {
            if (_auth.currentUser?.uid != boundUid) {
              cancelBindingsInMicrotask(closeController: true);
              return;
            }
            controller.add(event);
          },
          onError: (Object e, StackTrace st) {
            cancelBindingsInMicrotask(
              closeController: false,
              error: e,
              stack: st,
            );
          },
          onDone: () {
            cancelBindingsInMicrotask(closeController: true);
          },
          cancelOnError: false,
        );
      },
      onCancel: () => cancelBindingsInMicrotask(closeController: false),
    );

    return controller.stream;
  }

  Stream<List<T>> _seedThenLiveList<T>(
    List<T> seed,
    Stream<List<T>> live,
  ) async* {
    final String? boundUid = _auth.currentUser?.uid;
    yield List<T>.from(seed);
    if (boundUid == null) {
      yield* live;
      return;
    }
    yield* _guardFirestoreStreamWithAuth<List<T>>(boundUid, live);
  }

  Stream<T> _seedThenLive<T>(T seed, Stream<T> live) async* {
    final String? boundUid = _auth.currentUser?.uid;
    yield seed;
    if (boundUid == null) {
      yield* live;
      return;
    }
    yield* _guardFirestoreStreamWithAuth<T>(boundUid, live);
  }

  Stream<PostModel?> _postDetailSeedThenLive(
    PostModel seed,
    Stream<PostModel?> live,
  ) async* {
    final String? boundUid = _auth.currentUser?.uid;
    yield seed;
    if (boundUid == null) {
      yield* live;
      return;
    }
    yield* _guardFirestoreStreamWithAuth<PostModel?>(boundUid, live);
  }

  // --- Todos (per user) ---

  Stream<List<TodoItemModel>> watchTodosForDate(String dateKey) {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<TodoItemModel>>.value(<TodoItemModel>[]);
    }
    final String cacheKey = '$uid|$dateKey';
    final List<TodoItemModel>? cached = _todoDaySnapshotCache[cacheKey];
    final Stream<List<TodoItemModel>> live = _mergedTodoDayStream(uid, dateKey).map(
      (List<TodoItemModel> list) {
        _todoDaySnapshotCache[cacheKey] = List<TodoItemModel>.from(list);
        return list;
      },
    );
    if (cached == null) {
      return live;
    }
    return _todoSeedThenLive(List<TodoItemModel>.from(cached), live);
  }

  /// 캐시를 먼저 내보낸 뒤 실시간 스트림을 이어 받는다(재진입 시 로딩 스피너 방지).
  Stream<List<TodoItemModel>> _todoSeedThenLive(
    List<TodoItemModel> seed,
    Stream<List<TodoItemModel>> live,
  ) async* {
    yield seed;
    yield* live;
  }

  /// [dateKeys] 배열 쿼리 + 구 스키마 [dateKey] 단일 필드 쿼리를 합침.
  Stream<List<TodoItemModel>> _mergedTodoDayStream(String uid, String dateKey) {
    final CollectionReference<Map<String, dynamic>> col =
        FirestorePaths.userTodosCol(uid);
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subKeys;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subLegacy;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> docsKeys =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docsLegacy =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    final StreamController<List<TodoItemModel>> controller =
        StreamController<List<TodoItemModel>>.broadcast(
      // cache를 제거했지만, 방어적으로 마지막 구독이 끊기면 Firestore 리스너도 정리합니다.
      onCancel: () async {
        await subKeys?.cancel();
        await subLegacy?.cancel();
      },
    );

    void emitMerged() {
      final Map<String, TodoItemModel> byId = <String, TodoItemModel>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in docsKeys) {
        byId[d.id] = TodoItemModel.fromDoc(d);
      }
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in docsLegacy) {
        byId.putIfAbsent(d.id, () => TodoItemModel.fromDoc(d));
      }
      final List<TodoItemModel> list = byId.values.toList();
      list.sort(
        (TodoItemModel a, TodoItemModel b) =>
            (a.createdAt?.millisecondsSinceEpoch ?? 0)
                .compareTo(b.createdAt?.millisecondsSinceEpoch ?? 0),
      );
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    subKeys = col
        .where('dateKeys', arrayContains: dateKey)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> s) {
        docsKeys = s.docs;
        emitMerged();
      },
      onError: controller.addError,
    );
    subLegacy = col
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> s) {
        docsLegacy = s.docs;
        emitMerged();
      },
      onError: controller.addError,
    );

    return controller.stream;
  }

  Future<void> upsertTodo(TodoItemModel item) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final CollectionReference<Map<String, dynamic>> col =
        FirestorePaths.userTodosCol(uid);
    if (item.dateKeys.isEmpty) {
      throw StateError('Todo dateKeys가 비어 있습니다.');
    }
    final Map<String, dynamic> data = item.toWriteMap(uid);
    if (item.id.isEmpty) {
      await col.add(data);
    } else {
      await col.doc(item.id).set(<String, dynamic>{
        ...data,
        'dateKey': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteTodo(String todoId) async {
    final String? uid = _uid;
    if (uid == null) {
      return;
    }
    await FirestorePaths.userTodosCol(uid).doc(todoId).delete();
  }

  Future<void> setTodoCompleted(String todoId, bool completed) async {
    final String? uid = _uid;
    if (uid == null) {
      return;
    }
    await FirestorePaths.userTodosCol(uid).doc(todoId).update(<String, dynamic>{
      'completed': completed,
    });
  }

  // --- Messages ---

  Stream<List<InboxMessageModel>> watchInbox() {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<InboxMessageModel>>.value(<InboxMessageModel>[]);
    }
    return FirestorePaths.messagesCol()
        .where('receiverUid', isEqualTo: uid)
        .limit(80)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> s) {
            final List<InboxMessageModel> list =
                s.docs.map(InboxMessageModel.fromDoc).toList();
            list.sort(
              (InboxMessageModel a, InboxMessageModel b) =>
                  (b.createdAt?.millisecondsSinceEpoch ?? 0)
                      .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0),
            );
            return list.take(50).toList();
          },
        );
  }

  Stream<int> watchUnreadInboxCount() {
    final String? uid = _uid;
    if (uid == null) return Stream<int>.value(0);
    return FirestorePaths.messagesCol()
        .where('receiverUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> s) => s.docs.length);
  }

  // --- Notifications (무료 플랜용: 공용 컬렉션 + lastReadAt 기반) ---

  static const String _kProfileLastNotifReadAt = 'lastNotificationReadAt';
  static const String _kAllBranchesToken = '__ALL__';
  static const String _kProfileHiddenNotifIds = 'hiddenNotificationIds';
  static const String _kProfileHiddenNotifBeforeAt = 'hiddenNotificationsBeforeAt';
  static const String _kLocalHiddenNotifIdsPrefs = 'cache.hiddenNotificationIds.v1';

  Set<String>? _localHiddenNotifIds;

  Future<Set<String>> _loadLocalHiddenNotifIds() async {
    final Set<String>? cached = _localHiddenNotifIds;
    if (cached != null) return cached;
    try {
      final SharedPreferences p = await _prefs;
      final List<String> raw = p.getStringList(_kLocalHiddenNotifIdsPrefs) ?? <String>[];
      final Set<String> set = raw.map((String e) => e.trim()).where((String e) => e.isNotEmpty).toSet();
      _localHiddenNotifIds = set;
      return set;
    } catch (_) {
      _localHiddenNotifIds = <String>{};
      return _localHiddenNotifIds!;
    }
  }

  Future<void> _saveLocalHiddenNotifIds(Set<String> ids) async {
    try {
      final SharedPreferences p = await _prefs;
      // 너무 커지지 않게 상한
      final List<String> list = ids.take(800).toList();
      await p.setStringList(_kLocalHiddenNotifIdsPrefs, list);
    } catch (_) {
      return;
    }
  }

  Stream<List<AppNotificationModel>> watchMyNotifications({
    int limit = 80,
  }) {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<AppNotificationModel>>.value(<AppNotificationModel>[]);
    }

    final DocumentReference<Map<String, dynamic>> profRef =
        FirestorePaths.userProfileMainDoc(uid);
    final Query<Map<String, dynamic>> notifQuery = FirestorePaths.notificationsCol()
        .orderBy('createdAt', descending: true)
        .limit(limit.clamp(1, 200));

    late final StreamController<List<AppNotificationModel>> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? notifSub;

    DocumentSnapshot<Map<String, dynamic>>? lastProf;
    QuerySnapshot<Map<String, dynamic>>? lastNotifs;
    Set<String> localHidden = <String>{};

    void emitIfReady() {
      final DocumentSnapshot<Map<String, dynamic>>? p = lastProf;
      final QuerySnapshot<Map<String, dynamic>>? n = lastNotifs;
      if (p == null || n == null) return;
      final Map<String, dynamic> prof = p.data() ?? <String, dynamic>{};
      final String myBranch = (prof['branchName'] as String?)?.trim().isNotEmpty == true
          ? (prof['branchName'] as String).trim()
          : ((prof['branch'] as String?)?.trim() ?? '');
      final Timestamp? hiddenBeforeTs =
          prof[_kProfileHiddenNotifBeforeAt] as Timestamp?;
      final DateTime? hiddenBeforeDt = hiddenBeforeTs?.toDate();
      final Set<String> hiddenIds = (prof[_kProfileHiddenNotifIds] is List)
          ? (prof[_kProfileHiddenNotifIds] as List)
              .map((dynamic e) => e.toString().trim())
              .where((String e) => e.isNotEmpty)
              .toSet()
          : <String>{};
      hiddenIds.addAll(localHidden);

      final List<AppNotificationModel> list = n.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => AppNotificationModel.fromDoc(d))
          .where((AppNotificationModel m) {
            final bool targeted = m.targetUids.contains(uid);
            final bool broadcast = m.branchNames.contains(_kAllBranchesToken);
            final bool branched = myBranch.isNotEmpty && m.branchNames.contains(myBranch);
            final bool visible = targeted || broadcast || branched;
            if (!visible) return false;
            if (hiddenIds.contains(m.id)) return false;
            final DateTime? c = m.createdAt?.toDate();
            if (hiddenBeforeDt != null && c != null && !c.isAfter(hiddenBeforeDt)) {
              return false;
            }
            return true;
          })
          .toList();
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    controller = StreamController<List<AppNotificationModel>>(
      onListen: () async {
        // 프로필 쓰기 실패/탭 종료 등으로 서버에 숨김 기록이 남지 않는 경우를 대비해
        // 로컬 숨김 캐시도 함께 적용합니다.
        localHidden = await _loadLocalHiddenNotifIds();
        profSub = profRef.snapshots().listen((DocumentSnapshot<Map<String, dynamic>> snap) {
          lastProf = snap;
          emitIfReady();
        });
        notifSub = notifQuery.snapshots().listen((QuerySnapshot<Map<String, dynamic>> snap) {
          lastNotifs = snap;
          emitIfReady();
        });
      },
      onCancel: () async {
        await profSub?.cancel();
        await notifSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<int> watchUnreadNotificationCount() {
    final String? uid = _uid;
    if (uid == null) return Stream<int>.value(0);

    final DocumentReference<Map<String, dynamic>> profRef =
        FirestorePaths.userProfileMainDoc(uid);

    late final StreamController<int> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profSub;
    StreamSubscription<List<AppNotificationModel>>? notifSub;

    DocumentSnapshot<Map<String, dynamic>>? lastProf;
    List<AppNotificationModel>? lastList;

    void emitIfReady() {
      final DocumentSnapshot<Map<String, dynamic>>? p = lastProf;
      final List<AppNotificationModel>? list = lastList;
      if (p == null || list == null) return;
      final Map<String, dynamic> prof = p.data() ?? <String, dynamic>{};
      final Timestamp? lastRead = prof[_kProfileLastNotifReadAt] as Timestamp?;
      final DateTime? lastReadDt = lastRead?.toDate();
      final int unread = list.where((AppNotificationModel n) {
        final DateTime? c = n.createdAt?.toDate();
        if (c == null) return false;
        if (lastReadDt == null) return true;
        return c.isAfter(lastReadDt);
      }).length;
      if (!controller.isClosed) {
        controller.add(unread);
      }
    }

    controller = StreamController<int>(
      onListen: () {
        profSub = profRef.snapshots().listen((DocumentSnapshot<Map<String, dynamic>> snap) {
          lastProf = snap;
          emitIfReady();
        });
        notifSub = watchMyNotifications(limit: 120).listen((List<AppNotificationModel> list) {
          lastList = list;
          emitIfReady();
        });
      },
      onCancel: () async {
        await profSub?.cancel();
        await notifSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> markAllNotificationsRead() async {
    final String? uid = _uid;
    if (uid == null) return;
    await FirestorePaths.userProfileMainDoc(uid).set(
      <String, dynamic>{_kProfileLastNotifReadAt: FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    // 공용 컬렉션 방식에서는 개별 readAt을 저장하지 않고, lastReadAt을 갱신합니다.
    await markAllNotificationsRead();
  }

  Future<void> hideNotification(String notificationId) async {
    final String? uid = _uid;
    if (uid == null) return;
    final String id = notificationId.trim();
    if (id.isEmpty) return;
    final Set<String> local = await _loadLocalHiddenNotifIds();
    local.add(id);
    _localHiddenNotifIds = local;
    unawaited(_saveLocalHiddenNotifIds(local));
    await FirestorePaths.userProfileMainDoc(uid).set(
      <String, dynamic>{
        _kProfileHiddenNotifIds: FieldValue.arrayUnion(<String>[id]),
      },
      SetOptions(merge: true),
    );
  }

  /// "확인한 알림 삭제": 읽음 기준(lastReadAt) 이전의 알림을 내 화면에서만 숨김 처리
  Future<void> hideReadNotifications() async {
    final String? uid = _uid;
    if (uid == null) return;
    final DocumentSnapshot<Map<String, dynamic>> prof =
        await FirestorePaths.userProfileMainDoc(uid).get();
    final Map<String, dynamic> p = prof.data() ?? <String, dynamic>{};
    final Timestamp? lastRead = p[_kProfileLastNotifReadAt] as Timestamp?;
    final Timestamp hideBefore = lastRead ?? Timestamp.now();
    await FirestorePaths.userProfileMainDoc(uid).set(
      <String, dynamic>{
        _kProfileHiddenNotifBeforeAt: hideBefore,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _writePublicNotificationDoc({
    required String type,
    required String title,
    required String body,
    List<String> branchNames = const <String>[],
    List<String> targetUids = const <String>[],
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? docId,
  }) async {
    final String? uid = _uid;
    if (uid == null) return;
    final Map<String, dynamic> data = <String, dynamic>{
      'type': type,
      'title': title.trim(),
      'body': body.trim(),
      'branchNames': branchNames,
      'targetUids': targetUids,
      'payload': payload,
      'actorUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (docId != null && docId.trim().isNotEmpty) {
      await FirestorePaths.notificationsCol().doc(docId.trim()).set(data);
    } else {
      await FirestorePaths.notificationsCol().add(data);
    }
  }

  /// 앱(셸) 진입 시: 내 사업소(site label) 기준 pending 이고 마감이 1시간 이내인 자료요청에 대해
  /// 공용 알림 문서를 보장합니다(문서 id로 중복 방지).
  Future<void> syncDueSoonSubmissionNotificationsOnLogin() async {
    try {
      final String? uid = _uid;
      if (uid == null) return;

      final String myBranch = await _myBranchName(uid);
      if (myBranch.isEmpty) return;

      final DateTime now = DateTime.now();
      final DateTime horizon = now.add(const Duration(hours: 1));

      final List<DocumentReference<Map<String, dynamic>>> subRefs =
          await _pendingSubmissionRefsForBranch(myBranch);
      if (subRefs.isEmpty) return;

      await _ensureDueSoonNotifsForRefs(
        myBranch: myBranch,
        now: now,
        horizon: horizon,
        submissionRefs: subRefs,
      );
    } catch (_) {
      // 접속 시 보조 기능이므로 실패해도 앱 흐름을 막지 않음
      return;
    }
  }

  Future<String> _myBranchName(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> prof =
        await FirestorePaths.userProfileMainDoc(uid).get();
    final Map<String, dynamic> p = prof.data() ?? <String, dynamic>{};
    final String bn = (p['branchName'] as String?)?.trim() ?? '';
    if (bn.isNotEmpty) return bn;
    return (p['branch'] as String?)?.trim() ?? '';
  }

  Future<List<DocumentReference<Map<String, dynamic>>>> _pendingSubmissionRefsForBranch(
    String branchName,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> sitesSnap = await _db
        .collectionGroup('sites')
        .where('label', isEqualTo: branchName)
        .limit(200)
        .get();

    final List<DocumentReference<Map<String, dynamic>>> refs =
        <DocumentReference<Map<String, dynamic>>>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> siteDoc
        in sitesSnap.docs) {
      final Map<String, dynamic> sd = siteDoc.data();
      final String status = (sd['status'] as String?)?.trim() ?? '';
      if (status != 'pending') continue;
      final DocumentReference<Map<String, dynamic>>? subRef =
          siteDoc.reference.parent.parent;
      if (subRef != null) refs.add(subRef);
    }
    return refs;
  }

  Future<void> _ensureDueSoonNotifsForRefs({
    required String myBranch,
    required DateTime now,
    required DateTime horizon,
    required List<DocumentReference<Map<String, dynamic>>> submissionRefs,
  }) async {
    // 너무 많은 await 직렬 처리로 UI가 답답해지는 걸 막기 위해 적당히 나눠 병렬 처리
    const int batchSize = 12;
    for (int i = 0; i < submissionRefs.length; i += batchSize) {
      final int end =
          (i + batchSize > submissionRefs.length) ? submissionRefs.length : i + batchSize;
      final List<Future<void>> jobs = <Future<void>>[];
      for (int j = i; j < end; j++) {
        jobs.add(
          _maybeWriteDueSoonNotifForSubmissionRef(
            myBranch: myBranch,
            now: now,
            horizon: horizon,
            subRef: submissionRefs[j],
          ),
        );
      }
      await Future.wait(jobs);
    }
  }

  Future<void> _maybeWriteDueSoonNotifForSubmissionRef({
    required String myBranch,
    required DateTime now,
    required DateTime horizon,
    required DocumentReference<Map<String, dynamic>> subRef,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> subSnap = await subRef.get();
      if (!subSnap.exists) return;
      final Map<String, dynamic>? sub = subSnap.data();
      final Timestamp? dueTs = sub?['dueDate'] as Timestamp?;
      if (dueTs == null) return;

      final DateTime due = dueTs.toDate();
      if (!due.isAfter(now)) return;
      if (due.isAfter(horizon)) return;

      final String title = (sub?['title'] as String?)?.trim().isNotEmpty == true
          ? (sub?['title'] as String).trim()
          : '자료 요청';
      final String notifId = 'due_soon_${subRef.id}_$myBranch';
      await _writePublicNotificationDoc(
        docId: notifId,
        type: 'submission_due_soon',
        title: '자료 요청 마감 임박',
        body: '「$title」 마감이 1시간 이내입니다.',
        branchNames: <String>[myBranch],
        payload: <String, dynamic>{
          'submissionId': subRef.id,
          'siteLabel': myBranch,
          'dueAtMs': due.millisecondsSinceEpoch,
        },
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _notifyPostCreated({
    required String postId,
    required String boardType,
    required String postTitle,
  }) async {
    final String label = boardType == 'notice'
        ? '공지'
        : boardType == 'freeboard'
            ? '자유게시판'
            : '익명게시판';
    await _writePublicNotificationDoc(
      type: 'notice_created',
      title: '새 $label',
      body: postTitle.trim().isEmpty ? '새 글이 등록되었습니다.' : postTitle.trim(),
      // 전사 공개 게시판 알림: 사업소 목록을 매번 읽지 않고 토큰 1개로 브로드캐스트
      branchNames: const <String>[_kAllBranchesToken],
      payload: <String, dynamic>{
        'postId': postId,
        'boardType': boardType,
      },
    );
  }

  Future<void> _notifyPostCommented({
    required String postId,
    required String boardType,
    required String postTitle,
    String? postAuthorUid,
  }) async {
    final String? uid = _uid;
    if (uid == null) return;

    final Set<String> targets = <String>{};
    final String? author = postAuthorUid?.trim();
    if (author != null && author.isNotEmpty && author != uid) {
      targets.add(author);
    }

    // 댓글 참여자(작성자 UID가 있는 사람들)도 함께 알림 대상.
    // - 익명 댓글(authorUid null)은 대상 계산에서 제외 (대상을 늘리지 않음)
    // - 본인(uid)은 제외
    try {
      final QuerySnapshot<Map<String, dynamic>> commentSnap =
          await FirestorePaths.postCommentsCol(postId)
              .orderBy('createdAt', descending: true)
              .limit(200)
              .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d
          in commentSnap.docs) {
        final String? cu = (d.data()['authorUid'] as String?)?.trim();
        if (cu == null || cu.isEmpty) continue;
        if (cu == uid) continue;
        targets.add(cu);
      }
    } catch (_) {
      // 인덱스/권한/네트워크 문제로 댓글 목록을 못 읽어도 작성자 알림은 유지
    }

    // 작성자도 없고, 댓글 참여자도 없으면 대상이 없으므로 알림 생성 금지.
    if (targets.isEmpty) return;

    final List<String> branches = <String>[]; // 댓글 알림은 전사/사업소 broadcast 금지

    await _writePublicNotificationDoc(
      type: 'post_commented',
      title: '게시글에 새 댓글',
      body: postTitle.trim().isEmpty ? '댓글이 달렸습니다.' : '「${postTitle.trim()}」에 댓글이 달렸습니다.',
      branchNames: branches,
      targetUids: targets.toList(),
      payload: <String, dynamic>{
        'postId': postId,
        'boardType': boardType,
      },
    );
  }

  Future<void> _notifySubmissionCreated({
    required String submissionId,
    required String title,
    required List<String> targetBranchIds,
  }) async {
    final List<String> ids = targetBranchIds
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;
    await _writePublicNotificationDoc(
      type: 'submission_created',
      title: '새 자료 요청',
      body: title.trim().isEmpty ? '새 요청이 등록되었습니다.' : '「${title.trim()}」 요청이 등록되었습니다.',
      branchNames: ids,
      payload: <String, dynamic>{'submissionId': submissionId},
    );
  }

  Future<void> notifyCalendarEventCreated({
    required String eventId,
    required String scope,
    required String titleText,
    String? branchName,
    List<String> branchNames = const <String>[],
  }) async {
    final List<String> resolvedBranchNames = <String>[];
    final List<String> targets = <String>[];
    if (scope == 'company') {
      resolvedBranchNames.add(_kAllBranchesToken);
    } else if (scope == 'branch') {
      for (final String b in branchNames) {
        final String t = b.trim();
        if (t.isNotEmpty && !resolvedBranchNames.contains(t)) {
          resolvedBranchNames.add(t);
        }
      }
      final String legacy = (branchName ?? '').trim();
      if (legacy.isNotEmpty && !resolvedBranchNames.contains(legacy)) {
        resolvedBranchNames.add(legacy);
      }
    } else {
      // private
      final String? uid = _uid;
      if (uid != null) targets.add(uid);
    }

    if (resolvedBranchNames.isEmpty && targets.isEmpty) return;

    await _writePublicNotificationDoc(
      type: 'calendar_event_created',
      title: '새 일정',
      body: titleText.trim().isEmpty
          ? '일정이 등록되었습니다.'
          : '「${titleText.trim()}」 일정이 등록되었습니다.',
      branchNames: resolvedBranchNames,
      targetUids: targets,
      payload: <String, dynamic>{
        'calendarEventId': eventId,
        'scope': scope,
      },
    );
  }

  /// 일정 수정. mainAdmin 또는 본인 작성자만 가능(클라이언트 가드).
  Future<void> updateCalendarEvent(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    final String? uid = _uid;
    if (uid == null) throw StateError('로그인 필요');
    final DocumentReference<Map<String, dynamic>> ref =
        FirestorePaths.calendarEventsCol().doc(eventId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    if (!snap.exists) throw StateError('일정을 찾을 수 없습니다.');
    final Map<String, dynamic> d = snap.data() ?? <String, dynamic>{};
    final String owner = (d['createdByUid'] as String?)?.trim() ?? '';
    final bool isAuthor = owner.isNotEmpty && owner == uid;
    final int roleIdx = await _myRoleIdx();
    final bool isAdmin = _isDeleteAdminRoleIdx(roleIdx);
    if (!isAuthor && !isAdmin) {
      throw StateError('수정 권한이 없습니다.');
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': uid,
    };
    await ref.set(payload, SetOptions(merge: true));
  }

  /// 일정 삭제. mainAdmin 또는 본인 작성자만 가능.
  Future<void> deleteCalendarEvent(String eventId) async {
    final String? uid = _uid;
    if (uid == null) throw StateError('로그인 필요');
    final DocumentReference<Map<String, dynamic>> ref =
        FirestorePaths.calendarEventsCol().doc(eventId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    if (!snap.exists) return;
    final Map<String, dynamic> d = snap.data() ?? <String, dynamic>{};
    final String owner = (d['createdByUid'] as String?)?.trim() ?? '';
    final bool isAuthor = owner.isNotEmpty && owner == uid;
    final int roleIdx = await _myRoleIdx();
    final bool isAdmin = _isDeleteAdminRoleIdx(roleIdx);
    if (!isAuthor && !isAdmin) {
      throw StateError('삭제 권한이 없습니다.');
    }
    await ref.delete();
  }

  static int _conversationRecencyMs(ConversationRoomModel r) {
    final int u = r.updatedAt?.millisecondsSinceEpoch ?? 0;
    final int lm = r.lastMessageAt?.millisecondsSinceEpoch ?? 0;
    return u > lm ? u : lm;
  }

  /// 내가 참가한 대화방 목록 (최근 활동순)
  Stream<List<ConversationRoomModel>> watchMyConversations() {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<ConversationRoomModel>>.value(<ConversationRoomModel>[]);
    }
    final List<ConversationRoomModel>? cached = _myConversationsCache[uid];
    // `array-contains` + 다른 필드 `orderBy` 는 복합 인덱스가 필요합니다.
    // 인덱스 배포 전에도 동작하도록 orderBy 는 쓰지 않고, 클라이언트에서 정렬합니다.
    // (참가 대화가 매우 많으면 서버 limit 이전의 임의 200건 중에서만 정렬됩니다.)
    final Stream<List<ConversationRoomModel>> live = FirestorePaths.conversationsCol()
        .where('participantUids', arrayContains: uid)
        .limit(200)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> s) {
            final List<ConversationRoomModel> list =
                s.docs.map(ConversationRoomModel.fromDoc).toList();
            list.sort(
              (ConversationRoomModel a, ConversationRoomModel b) =>
                  _conversationRecencyMs(b).compareTo(_conversationRecencyMs(a)),
            );
            final List<ConversationRoomModel> top =
                list.length > 100 ? list.sublist(0, 100) : list;
            _myConversationsCache[uid] = List<ConversationRoomModel>.from(top);
            return top;
          },
        );
    if (cached == null) {
      return live;
    }
    return _seedThenLiveList(List<ConversationRoomModel>.from(cached), live);
  }

  static String _cacheKeyConversationRoom(String conversationId) =>
      'cache.conversationRoom.$conversationId';
  static String _cacheKeyConversationMessages(String conversationId) =>
      'cache.conversationMessages.$conversationId';

  final Map<String, ConversationRoomModel> _conversationRoomCache =
      <String, ConversationRoomModel>{};
  final Map<String, List<ChatMessageModel>> _conversationMessagesCache =
      <String, List<ChatMessageModel>>{};

  /// 대화방별 미읽음 합계 (상단 뱃지)
  Stream<int> watchUnreadConversationCount() {
    final String? uid = _uid;
    if (uid == null) return Stream<int>.value(0);
    return watchMyConversations().map(
      (List<ConversationRoomModel> list) => list
          .where((ConversationRoomModel c) => c.hasUnreadFor(uid))
          .length,
    );
  }

  Stream<ConversationRoomModel?> watchConversationRoom(String conversationId) {
    final String id = conversationId.trim();
    if (id.isEmpty) {
      return Stream<ConversationRoomModel?>.value(null);
    }
    final ConversationRoomModel? mem = _conversationRoomCache[id];
    final Stream<ConversationRoomModel?> live =
        FirestorePaths.conversationDoc(id).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> d) {
        final ConversationRoomModel? room =
            d.exists ? ConversationRoomModel.fromDoc(d) : null;
        if (room != null) {
          _conversationRoomCache[id] = room;
          _saveConversationRoomCache(id, room);
        }
        return room;
      },
    );
    if (mem != null) {
      return _seedThenLive(mem, live);
    }
    return _seedConversationRoomFromPrefsThenLive(id, live);
  }

  Stream<List<ChatMessageModel>> watchConversationMessages(String conversationId) {
    final String id = conversationId.trim();
    if (id.isEmpty) {
      return Stream<List<ChatMessageModel>>.value(<ChatMessageModel>[]);
    }
    final List<ChatMessageModel>? mem = _conversationMessagesCache[id];
    final Stream<List<ChatMessageModel>> live =
        FirestorePaths.conversationMessagesCol(id)
            .orderBy('createdAt', descending: false)
            .limit(200)
            .snapshots()
            .map(
      (QuerySnapshot<Map<String, dynamic>> s) {
        final List<ChatMessageModel> list = s.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  ChatMessageModel.fromDoc(id, d),
            )
            .toList();
        _conversationMessagesCache[id] = List<ChatMessageModel>.from(list);
        _saveConversationMessagesCache(id, list);
        return list;
      },
    );
    if (mem != null) {
      return _seedThenLiveList(List<ChatMessageModel>.from(mem), live);
    }
    return _seedConversationMessagesFromPrefsThenLive(id, live);
  }

  Stream<ConversationRoomModel?> _seedConversationRoomFromPrefsThenLive(
    String conversationId,
    Stream<ConversationRoomModel?> live,
  ) async* {
    final String? boundUid = _auth.currentUser?.uid;
    try {
      final SharedPreferences p = await _prefs;
      final String? raw = p.getString(_cacheKeyConversationRoom(conversationId));
      if (raw != null && raw.trim().isNotEmpty) {
        final Map<String, dynamic> m =
            (jsonDecode(raw) as Map).cast<String, dynamic>();
        final ConversationRoomModel cached =
            ConversationRoomModel.fromCacheMap(conversationId, m);
        _conversationRoomCache[conversationId] = cached;
        yield cached;
      }
    } catch (_) {
      // ignore
    }
    if (boundUid == null) {
      await for (final ConversationRoomModel? v in live) {
        yield v;
      }
    } else {
      await for (final ConversationRoomModel? v
          in _guardFirestoreStreamWithAuth<ConversationRoomModel?>(boundUid, live)) {
        yield v;
      }
    }
  }

  Stream<List<ChatMessageModel>> _seedConversationMessagesFromPrefsThenLive(
    String conversationId,
    Stream<List<ChatMessageModel>> live,
  ) async* {
    final String? boundUid = _auth.currentUser?.uid;
    try {
      final SharedPreferences p = await _prefs;
      final String? raw =
          p.getString(_cacheKeyConversationMessages(conversationId));
      if (raw != null && raw.trim().isNotEmpty) {
        final List<dynamic> arr = jsonDecode(raw) as List<dynamic>;
        final List<ChatMessageModel> cached = arr
            .whereType<Map>()
            .map((dynamic e) => (e as Map).cast<String, dynamic>())
            .map(
              (Map<String, dynamic> m) =>
                  ChatMessageModel.fromCacheMap(conversationId, m),
            )
            .where(
              (ChatMessageModel m) =>
                  m.body.trim().isNotEmpty || m.id.trim().isNotEmpty,
            )
            .toList();
        if (cached.isNotEmpty) {
          _conversationMessagesCache[conversationId] =
              List<ChatMessageModel>.from(cached);
          yield cached;
        }
      }
    } catch (_) {
      // ignore
    }
    if (boundUid == null) {
      await for (final List<ChatMessageModel> v in live) {
        yield v;
      }
    } else {
      await for (final List<ChatMessageModel> v
          in _guardFirestoreStreamWithAuth<List<ChatMessageModel>>(boundUid, live)) {
        yield v;
      }
    }
  }

  Future<void> _saveConversationRoomCache(
    String conversationId,
    ConversationRoomModel room,
  ) async {
    try {
      final SharedPreferences p = await _prefs;
      await p.setString(
        _cacheKeyConversationRoom(conversationId),
        jsonEncode(room.toCacheMap()),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveConversationMessagesCache(
    String conversationId,
    List<ChatMessageModel> list,
  ) async {
    try {
      final SharedPreferences p = await _prefs;
      final List<ChatMessageModel> trimmed =
          list.length > 200 ? list.sublist(list.length - 200) : list;
      await p.setString(
        _cacheKeyConversationMessages(conversationId),
        jsonEncode(
          trimmed.map((ChatMessageModel m) => m.toCacheMap()).toList(),
        ),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<String> ensureDirectConversation(String otherUid) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final String other = otherUid.trim();
    if (other.isEmpty) {
      throw StateError('대화 상대를 선택하세요');
    }
    if (other == uid) {
      final String id = FirestorePaths.selfConversationId(uid);
      await FirestorePaths.conversationDoc(id).set(
        <String, dynamic>{
          'type': ConversationRoomModel.typeDirect,
          'participantUids': <String>[uid],
          'updatedAt': FieldValue.serverTimestamp(),
          'memberReadAt': <String, dynamic>{
            uid: FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );
      return id;
    }

    final String id = FirestorePaths.dmConversationId(uid, other);
    await FirestorePaths.conversationDoc(id).set(
      <String, dynamic>{
        'type': ConversationRoomModel.typeDirect,
        'participantUids': <String>[uid, other],
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return id;
  }

  Future<String> createGroupConversation({
    required List<String> participantUids,
    String? groupTitle,
    String? groupPhotoUrl,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final Set<String> uids = <String>{
      ...participantUids.map((String e) => e.trim()).where((String e) => e.isNotEmpty),
      uid,
    };
    if (uids.length < 2) {
      throw StateError('참가자를 두 명 이상 선택하세요');
    }
    final String photo = (groupPhotoUrl ?? '').trim();
    final DocumentReference<Map<String, dynamic>> ref =
        FirestorePaths.conversationsCol().doc();
    await ref.set(
      <String, dynamic>{
        'type': ConversationRoomModel.typeGroup,
        'participantUids': uids.toList(),
        'groupTitle': (groupTitle ?? '').trim(),
        if (photo.isNotEmpty) 'groupPhotoUrl': photo,
        'lastMessagePreview': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'memberReadAt': <String, dynamic>{
          uid: FieldValue.serverTimestamp(),
        },
      },
    );
    return ref.id;
  }

  Future<void> sendChatMessage(String conversationId, String body) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final String t = body.trim();
    if (t.isEmpty) {
      throw StateError('내용을 입력하세요');
    }
    final String cid = conversationId.trim();
    if (cid.isEmpty) {
      throw StateError('대화방이 없습니다');
    }

    final DocumentSnapshot<Map<String, dynamic>> prof =
        await FirestorePaths.userProfileMainDoc(uid).get();
    final Map<String, dynamic>? pd = prof.data();
    String senderDisplay = (pd?['name'] as String?)?.trim() ?? '';
    if (senderDisplay.isEmpty) {
      senderDisplay = (pd?['displayName'] as String?)?.trim() ?? '';
    }
    if (senderDisplay.isEmpty) {
      senderDisplay = _auth.currentUser?.email?.trim() ?? uid;
    }

    final String preview = t.length > 120 ? '${t.substring(0, 120)}…' : t;
    final DocumentReference<Map<String, dynamic>> msgRef =
        FirestorePaths.conversationMessagesCol(cid).doc();
    final ChatMessageModel msg = ChatMessageModel(
      id: msgRef.id,
      conversationId: cid,
      senderUid: uid,
      senderDisplay: senderDisplay,
      body: t,
    );

    final WriteBatch batch = _db.batch();
    batch.set(msgRef, msg.toCreateMap());

    // 배지 숫자(unread count)를 위해 참가자 목록을 한 번 읽고,
    // 수신자들의 `memberUnreadCount.{uid}` 를 증가시킵니다.
    final DocumentSnapshot<Map<String, dynamic>> roomSnap =
        await FirestorePaths.conversationDoc(cid).get();
    final Map<String, dynamic> roomData = roomSnap.data() ?? <String, dynamic>{};
    final List<dynamic>? pu = roomData['participantUids'] as List<dynamic>?;
    final Set<String> participants = (pu == null)
        ? <String>{}
        : pu
            .map((dynamic e) => e.toString().trim())
            .where((String e) => e.isNotEmpty)
            .toSet();

    batch.set(
      FirestorePaths.conversationDoc(cid),
      <String, dynamic>{
        'lastMessagePreview': preview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'memberReadAt.$uid': FieldValue.serverTimestamp(),
        'memberUnreadCount.$uid': 0,
        for (final String p in participants)
          if (p != uid) 'memberUnreadCount.$p': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> markConversationRead(String conversationId) async {
    final String? uid = _uid;
    if (uid == null) {
      return;
    }
    final String cid = conversationId.trim();
    if (cid.isEmpty) {
      return;
    }
    await FirestorePaths.conversationDoc(cid).update(<String, dynamic>{
      'memberReadAt.$uid': FieldValue.serverTimestamp(),
      'memberUnreadCount.$uid': 0,
    });
  }

  Future<void> markMessageRead(String messageId) {
    return FirestorePaths.messagesCol().doc(messageId).update(<String, dynamic>{
      'read': true,
    });
  }

  /// 수신자별로 문서 1개씩 생성(단체 전송). Firestore 배치 한도(500) 단위로 커밋.
  Future<void> sendMessengerMessages({
    required List<String> receiverUids,
    required String body,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final String t = body.trim();
    if (t.isEmpty) {
      throw StateError('내용을 입력하세요');
    }
    final Set<String> targets = receiverUids
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toSet();
    if (targets.isEmpty) {
      throw StateError('받는 사람을 선택하세요');
    }
    final List<String> effectiveReceivers =
        targets.where((String id) => id != uid).toList();
    if (effectiveReceivers.isEmpty) {
      throw StateError('본인 외 받는 사람을 선택하세요');
    }

    final DocumentSnapshot<Map<String, dynamic>> prof =
        await FirestorePaths.userProfileMainDoc(uid).get();
    final Map<String, dynamic>? pd = prof.data();
    String senderDisplay = (pd?['name'] as String?)?.trim() ?? '';
    if (senderDisplay.isEmpty) {
      senderDisplay = (pd?['displayName'] as String?)?.trim() ?? '';
    }
    if (senderDisplay.isEmpty) {
      senderDisplay = _auth.currentUser?.email?.trim() ?? uid;
    }

    const int kMaxBatch = 400;
    for (int i = 0; i < effectiveReceivers.length; i += kMaxBatch) {
      final WriteBatch batch = _db.batch();
      final int end = (i + kMaxBatch > effectiveReceivers.length)
          ? effectiveReceivers.length
          : i + kMaxBatch;
      for (int j = i; j < end; j++) {
        final String rid = effectiveReceivers[j];
        final DocumentReference<Map<String, dynamic>> ref =
            FirestorePaths.messagesCol().doc();
        final InboxMessageModel m = InboxMessageModel(
          id: ref.id,
          senderUid: uid,
          receiverUid: rid,
          body: t,
          read: false,
          senderDisplay: senderDisplay,
        );
        batch.set(ref, m.toCreateMap());
      }
      await batch.commit();
    }
  }

  // --- Calendar Events ---

  /// 오늘 이후 다가오는 일정 (Upcoming Events)
  Stream<List<Map<String, dynamic>>> watchUpcomingEvents({int limit = 20}) {
    final DateTime now = DateTime.now();
    return FirestorePaths.calendarEventsCol()
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('start')
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> s) => s.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    <String, dynamic>{
                  'id': d.id,
                  ...d.data(),
                },
              )
              .toList(),
        );
  }

  // --- 회사정보: 조직도 / 사규집 ---

  Stream<Map<String, dynamic>?> watchOrgChartDoc() {
    return FirestorePaths.companyOrgChartDoc().snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> d) => d.data(),
        );
  }

  Future<void> setOrgChartPdf(PlatformFile file) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final Map<String, dynamic> pd =
        await FirestorePaths.fetchMergedUserProfileMain(uid);
    final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
      profileMainAdmin: pd['mainAdmin'],
      profileEmail: pd['email'] as String?,
      authEmail: _auth.currentUser?.email,
      roleIdx: (pd['roleIdx'] as num?)?.toInt(),
    );
    if (!mainAdmin) {
      throw StateError('메인관리자만 업로드할 수 있습니다.');
    }
    final R2UploadResult r = await uploadTemplateToR2(
      file,
      r2RegistrySource: 'company',
      r2RegistrySourcePath: 'org_chart',
    );
    final DocumentSnapshot<Map<String, dynamic>> old =
        await FirestorePaths.companyOrgChartDoc().get();
    final String? oldKey = (old.data()?['r2Key'] as String?)?.trim();
    final String newKey = r.fileKey.trim();

    /// 메타를 먼저 저장한 뒤 이전 객체 삭제 — Firestore 실패 시에도 기존 R2는 유지됨.
    await FirestorePaths.companyOrgChartDoc()
        .set(
          <String, dynamic>{
            'fileUrl': r.fileUrl,
            'r2Key': r.fileKey,
            'fileName': file.name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        )
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw TimeoutException(
            'Firestore 저장이 45초 안에 끝나지 않았습니다. 네트워크·권한을 확인하세요.',
          ),
        );

    if (oldKey != null &&
        oldKey.isNotEmpty &&
        oldKey != newKey) {
      try {
        await R2StorageService()
            .deleteFile(oldKey)
            .timeout(const Duration(seconds: 20));
      } on Object {
        // 삭제 실패해도 신규 메타는 이미 반영됨
      }
    }
  }

  Stream<List<CompanyRuleFileModel>> watchCompanyRuleFiles() {
    return FirestorePaths.companyRuleFilesCol().snapshots().map(
          (QuerySnapshot<Map<String, dynamic>> s) {
            final List<CompanyRuleFileModel> list = s.docs
                .map(CompanyRuleFileModel.fromDoc)
                .where(
                  (CompanyRuleFileModel e) =>
                      e.fileUrl.isNotEmpty && e.r2Key.isNotEmpty,
                )
                .toList();
            list.sort(
              (CompanyRuleFileModel a, CompanyRuleFileModel b) =>
                  a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
            );
            return list;
          },
        );
  }

  Future<void> addCompanyRuleFile({
    required String category,
    required PlatformFile file,
  }) async {
    if (category != 'regulation' && category != 'guideline') {
      throw ArgumentError.value(category, 'category');
    }
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final Map<String, dynamic> pd =
        await FirestorePaths.fetchMergedUserProfileMain(uid);
    final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
      profileMainAdmin: pd['mainAdmin'],
      profileEmail: pd['email'] as String?,
      authEmail: _auth.currentUser?.email,
      roleIdx: (pd['roleIdx'] as num?)?.toInt(),
    );
    if (!mainAdmin) {
      throw StateError('메인관리자만 업로드할 수 있습니다.');
    }
    final R2UploadResult r = await uploadTemplateToR2(
      file,
      r2RegistrySource: 'company',
      r2RegistrySourcePath: 'company_rules/$category',
    );
    String displayName = file.name.trim();
    if (displayName.isEmpty) {
      displayName = 'document.pdf';
    }
    await FirestorePaths.companyRuleFilesCol()
        .add(
          <String, dynamic>{
            'category': category,
            'fileName': displayName,
            'fileUrl': r.fileUrl,
            'r2Key': r.fileKey,
            'createdAt': FieldValue.serverTimestamp(),
          },
        )
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () => throw TimeoutException(
            '사규집 메타 저장이 45초 안에 끝나지 않았습니다. 네트워크·Firestore 권한을 확인하세요.',
          ),
        );
  }

  Future<void> deleteCompanyRuleFile(CompanyRuleFileModel item) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('로그인 필요');
    }
    final Map<String, dynamic> pd =
        await FirestorePaths.fetchMergedUserProfileMain(uid);
    final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
      profileMainAdmin: pd['mainAdmin'],
      profileEmail: pd['email'] as String?,
      authEmail: _auth.currentUser?.email,
      roleIdx: (pd['roleIdx'] as num?)?.toInt(),
    );
    if (!mainAdmin) {
      throw StateError('메인관리자만 삭제할 수 있습니다.');
    }
    if (item.r2Key.isNotEmpty) {
      try {
        await R2StorageService().deleteFile(item.r2Key);
      } on Object {
        // 스토리지 삭제 실패 시에도 문서는 제거 시도
      }
    }
    await FirestorePaths.companyRuleFilesCol().doc(item.id).delete();
  }

  /// 데모/테스트용: 본인에게 쪽지 보내기
  Future<void> seedSelfMessage(String body) async {
    final String? uid = _uid;
    if (uid == null) return;
    final InboxMessageModel m = InboxMessageModel(
      id: '',
      senderUid: 'system',
      receiverUid: uid,
      body: body,
      senderDisplay: '시스템',
    );
    await FirestorePaths.messagesCol().add(m.toCreateMap());
  }
}
