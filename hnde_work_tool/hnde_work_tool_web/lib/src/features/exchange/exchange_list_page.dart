import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/role_constants.dart';
import '../../constants/super_admin.dart';
import '../../models/submission_model.dart';
import '../../models/submission_site_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';

String _effectiveBranchFromProfile(Map<String, dynamic>? prof) {
  if (prof == null) return '';
  final String? bn = (prof['branchName'] as String?)?.trim();
  if (bn != null && bn.isNotEmpty) return bn;
  final String? br = (prof['branch'] as String?)?.trim();
  return br ?? '';
}

bool _siteMatchesUserBranch(SubmissionSiteModel s, String branch) {
  if (branch.isEmpty) return false;
  return s.id == branch || s.label == branch;
}

/// 요청처 집계 / 제출처 한 줄 (요청처 우선, 상세 페이지와 동일)
String? _exchangeListStatusLine({
  required SubmissionModel model,
  required String? uid,
  required Map<String, dynamic>? profile,
  required List<SubmissionSiteModel>? sites,
  required bool sitesWaiting,
}) {
  if (uid == null || profile == null) return null;
  final int roleIdx =
      (profile['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
  final bool isRequesterViewer = model.createdByUid.isNotEmpty &&
      uid == model.createdByUid;
  final bool isRequesterViewerLegacy = model.createdByUid.isEmpty &&
      (SuperAdmin.effectiveMainAdmin(
            profileMainAdmin: profile['mainAdmin'],
            profileEmail: profile['email'] as String?,
            authEmail: FirebaseAuth.instance.currentUser?.email,
            roleIdx: roleIdx,
          ) ||
          RoleConstants.canViewAllBranches(roleIdx));
  final bool showRequesterPanel =
      isRequesterViewer || isRequesterViewerLegacy;

  final List<SubmissionSiteModel> list = sites ?? <SubmissionSiteModel>[];
  if (showRequesterPanel) {
    if (sitesWaiting && list.isEmpty) return null;
    final int total = list.length;
    final int submittedCnt =
        list.where((SubmissionSiteModel s) => s.status != 'pending').length;
    final int approvedCnt =
        list.where((SubmissionSiteModel s) => s.status == 'approved').length;
    final int rereqCnt = list
        .where((SubmissionSiteModel s) => s.status == 're_requested')
        .length;
    return '$total개소 중 $submittedCnt개소 제출 '
        '($approvedCnt개 확인 / $rereqCnt개 재요청)';
  }

  final String effectiveBranch = _effectiveBranchFromProfile(profile);
  if (effectiveBranch.isEmpty || effectiveBranch == 'unknown') return null;
  if (sitesWaiting && list.isEmpty) return null;

  SubmissionSiteModel? mySite;
  for (final SubmissionSiteModel s in list) {
    if (_siteMatchesUserBranch(s, effectiveBranch)) {
      mySite = s;
      break;
    }
  }
  if (mySite == null) return null;

  switch (mySite.status) {
    case 'pending':
      return '대기';
    case 'submitted':
      return '제출완료';
    case 'approved':
      return '확인완료';
    case 're_requested':
      return '재요청';
    case 'rejected':
      return '반려';
    default:
      return mySite.status;
  }
}

class ExchangeListPage extends StatefulWidget {
  const ExchangeListPage({super.key});

  @override
  State<ExchangeListPage> createState() => _ExchangeListPageState();
}

class _ExchangeListPageState extends State<ExchangeListPage> {
  late final WorkFirestoreRepository _repo;
  late final Stream<List<SubmissionModel>> _submissionsStream;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    _submissionsStream = _repo.watchSubmissions();
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: '자료송수신',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                '자료 송수신',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/exchange/create'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('새 요청'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<List<SubmissionModel>>(
              stream: _submissionsStream,
              builder: (BuildContext context,
                  AsyncSnapshot<List<SubmissionModel>> snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      '불러오기 실패: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: LoadingWidget(size: 80));
                }
                final List<SubmissionModel> list =
                    snap.data ?? <SubmissionModel>[];
                if (list.isEmpty) {
                  return const Center(
                    child: Text(
                      '등록된 요청이 없습니다. 상단에서 새 요청을 추가하세요.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder:
                      (BuildContext context, AsyncSnapshot<User?> authSnap) {
                    final String? uid = authSnap.data?.uid;
                    if (uid == null) {
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int i) {
                          final SubmissionModel s = list[i];
                          return _SubmissionCard(
                            key: ValueKey<String>('ex-${s.id}'),
                            model: s,
                            uid: null,
                            profile: null,
                            onTap: () => context.go('/exchange/${s.id}'),
                          );
                        },
                      );
                    }
                    return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirestorePaths.userProfileMainDoc(uid)
                          .snapshots(),
                      builder: (BuildContext context,
                          AsyncSnapshot<
                                  DocumentSnapshot<Map<String, dynamic>>>
                              profSnap) {
                        final Map<String, dynamic>? prof =
                            profSnap.data?.data();
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (BuildContext context, int i) {
                            final SubmissionModel s = list[i];
                            return _SubmissionCard(
                              key: ValueKey<String>('ex-${s.id}'),
                              model: s,
                              uid: uid,
                              profile: prof,
                              onTap: () => context.go('/exchange/${s.id}'),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  const _SubmissionCard({
    super.key,
    required this.model,
    required this.onTap,
    required this.uid,
    required this.profile,
  });

  final SubmissionModel model;
  final VoidCallback onTap;
  final String? uid;
  final Map<String, dynamic>? profile;

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  late final WorkFirestoreRepository _repo;
  late final Stream<List<SubmissionSiteModel>> _sitesStream;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    _sitesStream = _repo.watchSubmissionSites(widget.model.id);
  }

  @override
  void didUpdateWidget(covariant _SubmissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.id != widget.model.id) {
      _sitesStream = _repo.watchSubmissionSites(widget.model.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dueStr = widget.model.dueDate == null
        ? '-'
        : DateFormat('yyyy-MM-dd').format(widget.model.dueDate!.toDate());
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: StreamBuilder<List<SubmissionSiteModel>>(
            stream: _sitesStream,
            builder: (BuildContext context,
                AsyncSnapshot<List<SubmissionSiteModel>> siteSnap) {
              final bool sitesWaiting =
                  siteSnap.connectionState == ConnectionState.waiting &&
                      !siteSnap.hasData;
              final String? statusLine = _exchangeListStatusLine(
                model: widget.model,
                uid: widget.uid,
                profile: widget.profile,
                sites: siteSnap.data,
                sitesWaiting: sitesWaiting,
              );
              return Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.model.isUrgent
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.folder_copy_rounded,
                      color: widget.model.isUrgent ? Colors.orange : Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.model.isUrgent
                                    ? Colors.orange
                                    : Colors.blueGrey,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.model.isUrgent ? '긴급' : '일반',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.model.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.model.departmentLabel} · 마감: $dueStr',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (statusLine != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            statusLine,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.grey.shade300, size: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
