import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_paths.dart';
import '../constants/super_admin.dart';
import '../models/branch_model.dart';
import '../models/branch_group_model.dart';

class InitialDataSeeder {
  static const Duration _kFirestoreProbeTimeout = Duration(seconds: 12);

  /// `public/data/*` 시드는 Firestore 규칙상 **메인관리자만** 쓸 수 있는 경우가 많습니다.
  /// 일반 사용자에게는 호출해도 아무 것도 하지 않습니다(permission-denied 로그 반복 방지).
  static Future<void> ensureSeeded() async {
    try {
      if (!await _currentUserMaySeedPublicData()) {
        if (kDebugMode) {
          debugPrint(
            'InitialDataSeeder: 메인관리자가 아니어서 public/data 시드 생략',
          );
        }
        return;
      }
      await _seedBranchesIfNeeded();
      await _seedBranchGroupsIfNeeded();
      await _seedRolesIfNeeded();
      await _seedWorkHubIfNeeded();
    } on Object catch (e, st) {
      debugPrint('InitialDataSeeder.ensureSeeded 실패(앱은 계속): $e\n$st');
    }
  }

  /// `branches`가 비었을 때 **본사** 1건만 생성합니다.
  ///
  /// Firestore 규칙상 로그인 사용자면 `public/data/branches`에 쓸 수 있어,
  /// 회원가입(2/2) 직전처럼 아직 메인관리자가 아닌 사용자도 호출 가능합니다.
  /// ([ensureSeeded]는 메인관리자 전용 대량 시드와 별개입니다.)
  static Future<void> ensureMinimumHeadquartersBranchIfEmpty() async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }
    final CollectionReference<Map<String, dynamic>> col =
        FirestorePaths.publicBranchesCol();
    final bool empty = await _isCollectionEmpty(col);
    if (!empty) {
      return;
    }
    try {
      const String hqId = '본사';
      final BranchModel hq = BranchModel(
        id: hqId,
        name: '본사',
        groupKey: 'HDNE_MAIN',
      );
      await col.doc(hqId).set(hq.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'InitialDataSeeder.ensureMinimumHeadquartersBranchIfEmpty: ${e.code}',
        );
      }
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('InitialDataSeeder.ensureMinimumHeadquartersBranchIfEmpty: $e');
      }
    }
  }

  /// 프로필의 `mainAdmin` 또는 `roleIdx == 0` 일 때만 public 시드 시도.
  static Future<bool> _currentUserMaySeedPublicData() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return false;
    }
    try {
      final Map<String, dynamic> d =
          await FirestorePaths.fetchMergedUserProfileMain(uid)
              .timeout(_kFirestoreProbeTimeout);
      final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
        profileMainAdmin: d['mainAdmin'],
        profileEmail: d['email'] as String?,
        authEmail: FirebaseAuth.instance.currentUser?.email,
        roleIdx: (d['roleIdx'] as num?)?.toInt(),
      );
      return mainAdmin;
    } on Object {
      return false;
    }
  }

  static Future<bool> _isCollectionEmpty(CollectionReference<Map<String, dynamic>> col) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await col.limit(1).get().timeout(_kFirestoreProbeTimeout);
      return snap.docs.isEmpty;
    } on TimeoutException {
      debugPrint('InitialDataSeeder: Firestore 조회 타임아웃 → 시드 건너뜀 (${col.path})');
      return false;
    } on FirebaseException catch (e) {
      debugPrint('InitialDataSeeder: Firestore 오류 → 시드 건너뜀 (${e.code}) ${col.path}');
      return false;
    } on Object catch (e) {
      debugPrint('InitialDataSeeder: 조회 실패 → 시드 건너뜀: $e');
      return false;
    }
  }

  static Future<void> _seedBranchesIfNeeded() async {
    final col = FirestorePaths.publicBranchesCol();
    final bool empty = await _isCollectionEmpty(col);
    if (!empty) return;

    const String group1Key = 'HDNE_MAIN';
    const String group2Key = 'THEWAY_MAIN';

    final List<BranchModel> branches = <BranchModel>[
      BranchModel(id: '본사', name: '본사', groupKey: group1Key),
      BranchModel(
          id: '만남(부산)휴게소',
          name: '만남(부산)휴게소',
          groupKey: group1Key),
      BranchModel(
          id: '진영(순천)휴게소',
          name: '진영(순천)휴게소',
          groupKey: group1Key),
      BranchModel(
          id: '장안(울산)휴게소',
          name: '장안(울산)휴게소',
          groupKey: group1Key),
      BranchModel(
          id: '장안(부산)휴게소',
          name: '장안(부산)휴게소',
          groupKey: group1Key),
      BranchModel(
          id: '동명(춘천)휴게소',
          name: '동명(춘천)휴게소',
          groupKey: group1Key),
      BranchModel(
          id: '동명(부산)휴게소',
          name: '동명(부산)휴게소',
          groupKey: group1Key),
      BranchModel(
          id: '송산휴게소',
          name: '송산휴게소',
          groupKey: group1Key),
      BranchModel(
          id: '선산(창원)휴게소',
          name: '선산(창원)휴게소',
          groupKey: group1Key),
      BranchModel(
          id: '더웨이유통본사',
          name: '더웨이유통본사',
          groupKey: group2Key),
      BranchModel(
          id: '진안(장수)휴게소',
          name: '진안(장수)휴게소',
          groupKey: group2Key),
      BranchModel(
          id: '진안(장수)주유소',
          name: '진안(장수)주유소',
          groupKey: group2Key),
      BranchModel(
          id: '진안(익산)주유소',
          name: '진안(익산)주유소',
          groupKey: group2Key),
      BranchModel(
          id: '선산(양평)주유소',
          name: '선산(양평)주유소',
          groupKey: group2Key),
      BranchModel(
          id: '선산(창원)주유소',
          name: '선산(창원)주유소',
          groupKey: group2Key),
    ];

    final WriteBatch batch = FirebaseFirestore.instance.batch();
    for (final BranchModel b in branches) {
      batch.set(col.doc(b.id), b.toMap());
    }
    await batch.commit();
  }

  static Future<void> _seedBranchGroupsIfNeeded() async {
    final col = FirestorePaths.publicBranchGroupsCol();
    final bool empty = await _isCollectionEmpty(col);
    if (!empty) return;

    const String group1Key = 'HDNE_MAIN';
    const String group2Key = 'THEWAY_MAIN';

    final List<BranchGroupModel> groups = <BranchGroupModel>[
      BranchGroupModel(
        key: group1Key,
        label: '에이치앤디이 사업소',
        branchNames: <String>[
          '본사',
          '만남(부산)휴게소',
          '진영(순천)휴게소',
          '장안(울산)휴게소',
          '장안(부산)휴게소',
          '동명(춘천)휴게소',
          '동명(부산)휴게소',
          '송산휴게소',
          '선산(창원)휴게소',
        ],
      ),
      BranchGroupModel(
        key: group2Key,
        label: '더웨이유통 사업소',
        branchNames: <String>[
          '더웨이유통본사',
          '진안(장수)휴게소',
          '진안(장수)주유소',
          '진안(익산)주유소',
          '선산(양평)주유소',
          '선산(창원)주유소',
        ],
      ),
    ];

    final WriteBatch batch = FirebaseFirestore.instance.batch();
    for (final BranchGroupModel g in groups) {
      batch.set(col.doc(g.key), g.toMap());
    }
    await batch.commit();
  }

  static Future<void> _seedRolesIfNeeded() async {
    final col = FirestorePaths.publicRolesCol();
    final bool empty = await _isCollectionEmpty(col);
    if (!empty) return;

    final WriteBatch batch = FirebaseFirestore.instance.batch();
    batch.set(col.doc('0'), <String, dynamic>{
      'roleIdx': 0,
      'roleName': '메인관리자',
      'canAccessFiles': true,
      'canAccessSettings': true,
    });
    batch.set(col.doc('1'), <String, dynamic>{
      'roleIdx': 1,
      'roleName': '일반사용자',
      'canAccessFiles': false,
      'canAccessSettings': false,
    });
    await batch.commit();
  }

  /// 자료송수신·게시판 데모 문서 (비어 있을 때만)
  static Future<void> _seedWorkHubIfNeeded() async {
    final CollectionReference<Map<String, dynamic>> subCol =
        FirestorePaths.submissionsCol();
    final bool subEmpty = await _isCollectionEmpty(subCol);
    if (subEmpty) {
      final DocumentReference<Map<String, dynamic>> doc1 =
          await subCol.add(<String, dynamic>{
        'title': '2024년 2분기 사업장 안전 정기 점검표 (데모)',
        'description': '산업안전보건법 제12조에 의거한 정기 보고서입니다.',
        'urgency': 'urgent',
        'dueDate': Timestamp.fromDate(DateTime(2024, 5, 30)),
        'createdByUid': 'system-seed',
        'createdAt': FieldValue.serverTimestamp(),
        'departmentLabel': 'HQ Planning Team',
        'templateFileName': '안전점검표_제출양식.xlsx',
      });

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      void site(String id, String label, String status) {
        batch.set(
          doc1.collection('sites').doc(id),
          <String, dynamic>{
            'label': label,
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      site('seoul', '서울 광역 본부', 'submitted');
      site('incheon', '인천 광역 사업소', 'pending');
      site('busan', '부산 지역 지부', 'pending');
      await batch.commit();

      await subCol.add(<String, dynamic>{
        'title': '분기별 안전교육 이수 현황 제출 (데모)',
        'description': '일반 자료 요청입니다.',
        'urgency': 'general',
        'dueDate': Timestamp.fromDate(DateTime(2024, 6, 15)),
        'createdByUid': 'system-seed',
        'createdAt': FieldValue.serverTimestamp(),
        'departmentLabel': 'HR Team',
        'templateFileName': null,
      });
    }

    final CollectionReference<Map<String, dynamic>> postsCol =
        FirestorePaths.postsCol();
    final bool postsEmpty = await _isCollectionEmpty(postsCol);
    if (!postsEmpty) return;

    final WriteBatch pb = FirebaseFirestore.instance.batch();
    void post(
      String id,
      String boardType,
      String title,
      String body, {
      bool official = false,
    }) {
      pb.set(postsCol.doc(id), <String, dynamic>{
        'title': title,
        'body': body,
        'boardType': boardType,
        'authorUid': 'system-seed',
        'authorDisplay': 'System Administrator',
        'createdAt': FieldValue.serverTimestamp(),
        'readCount': 1200,
        'isOfficial': official,
      });
    }

    post(
      'notice_demo_1',
      'notice',
      '전사 공지사항 샘플 (데모)',
      'Firestore `posts` 컬렉션에 저장된 공지 예시입니다.',
      official: true,
    );
    post(
      'free_demo_1',
      'freeboard',
      '자유게시판 샘플',
      '자유롭게 의견을 나누는 게시판입니다.',
    );
    post(
      'anon_demo_1',
      'anonymous',
      '익명 건의 (데모)',
      '익명 게시글 예시입니다.',
    );
    await pb.commit();
  }
}

