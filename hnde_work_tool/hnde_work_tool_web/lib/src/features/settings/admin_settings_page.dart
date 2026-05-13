import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../../constants/role_constants.dart';
import '../../constants/firestore_paths.dart';
import '../../constants/super_admin.dart';
import '../../models/branch_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../common/enterprise_scaffold.dart';
import '../common/merged_user_profile_stream_builder.dart';
import 'branch_edit_form.dart';

const Color _navy = Color(0xFF1E3A8A);
const Color _slate900 = Color(0xFF0F172A);
const Color _slate400 = Color(0xFF94A3B8);
const Color _slate50 = Color(0xFFF8FAFC);

/// 관리자 설정: 직원 관리 / 사업소 관리
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  String _tab = 'staff';

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const EnterpriseScaffold(
        title: '관리자 설정',
        child: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return EnterpriseScaffold(
      title: '관리자 설정',
      child: MergedUserProfileStreamBuilder(
        uid: user.uid,
        builder: (
          BuildContext context,
          Map<String, dynamic> d,
          bool streamsWaiting,
        ) {
          final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
            profileMainAdmin: d['mainAdmin'],
            profileEmail: d['email'] as String?,
            authEmail: user.email,
            roleIdx: (d['roleIdx'] as num?)?.toInt(),
          );

          if (!mainAdmin) {
            return const Center(
              child: Text(
                '접근 권한이 없습니다.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TabBar(tab: _tab, onTab: (v) => setState(() => _tab = v)),
                const SizedBox(height: 32),
                if (_tab == 'staff')
                  _StaffListView(
                    onEdit: (s) => _openStaffEditDialog(context, s),
                  )
                else if (_tab == 'branch')
                  _FirestoreBranchListView(
                    onEdit: (BranchModel b) => setState(() {
                      // 사업소 편집은 기존 폼(전체 화면) 유지
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _BranchEditFullPage(
                            data: _branchToEditMap(b),
                          ),
                        ),
                      );
                    }),
                    onCreate: () => setState(() {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _BranchEditFullPage(
                            data: <String, dynamic>{
                              'isNew': true,
                              'id': '',
                              'name': '',
                              'groupKey': 'HDNE_MAIN',
                              'address': '',
                              'phone': '',
                              'head': '',
                              'lat': null,
                              'lng': null,
                            },
                          ),
                        ),
                      );
                    }),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openStaffEditDialog(
    BuildContext context,
    Map<String, dynamic> staff,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return _StaffEditDialog(
          staff: staff,
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
    );
    if (mounted) {
      setState(() {});
    }
  }
}

Map<String, dynamic> _branchToEditMap(BranchModel b) {
  return <String, dynamic>{
    'isNew': false,
    'id': b.id,
    'name': b.name,
    'groupKey': b.groupKey,
    'address': b.address ?? '',
    'phone': b.phone ?? '',
    'head': b.head ?? '',
    'lat': b.latitude,
    'lng': b.longitude,
  };
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onTab});

  final String tab;
  final ValueChanged<String> onTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ScrollConfiguration(
                  behavior: _AdminTabScrollBehavior(),
                  child: Row(
                    children: <Widget>[
                    _TabBtn(
                      label: '직원 관리',
                      icon: Icons.people_outline,
                      selected: tab == 'staff',
                      onTap: () => onTab('staff'),
                    ),
                    _TabBtn(
                      label: '사업소 관리',
                      icon: Icons.business_outlined,
                      selected: tab == 'branch',
                      onTap: () => onTab('branch'),
                    ),
                    // 문화의 날(AI) 메뉴 보류
                    // _TabBtn(
                    //   label: '문화의 날(AI)',
                    //   icon: Icons.auto_awesome_outlined,
                    //   selected: tab == 'culture',
                    //   onTap: () => onTab('culture'),
                    // ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTabScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _navy : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: selected ? Colors.white : _slate400),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : _slate400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _staffRolePrivilegePatch(String role) {
  switch (role) {
    case 'Master':
      return <String, dynamic>{
        'role': 'Master',
        'mainAdmin': true,
        'roleIdx': RoleConstants.mainAdmin,
      };
    case 'HQ Admin':
      return <String, dynamic>{
        'role': 'HQ Admin',
        'mainAdmin': false,
        'roleIdx': RoleConstants.hqAdmin,
      };
    case 'Branch Manager':
      return <String, dynamic>{
        'role': 'Branch Manager',
        'mainAdmin': false,
        'roleIdx': RoleConstants.branchAdmin,
      };
    case 'Staff':
    default:
      return <String, dynamic>{
        'role': 'Staff',
        'mainAdmin': false,
        'roleIdx': RoleConstants.branchStaff,
      };
  }
}

/// 미러 문서에서 UI 권한 드롭다운 값으로 환산 (예외 이메일·mainAdmin·role·roleIdx 순).
String _staffUiRoleFromMirror(Map<String, dynamic> d) {
  final String email = (d['email'] as String?)?.trim() ?? '';
  if (SuperAdmin.isSuperAdminEmail(email)) {
    return 'Master';
  }
  if ((d['mainAdmin'] as bool?) == true) {
    return 'Master';
  }
  final String r = (d['role'] as String?)?.trim() ?? '';
  if (r == 'Master' || r == 'HQ Admin' || r == 'Branch Manager' || r == 'Staff') {
    return r;
  }
  final int idx = (d['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
  if (idx == RoleConstants.mainAdmin) {
    return 'Master';
  }
  if (idx == RoleConstants.hqAdmin) {
    return 'HQ Admin';
  }
  if (idx == RoleConstants.branchAdmin) {
    return 'Branch Manager';
  }
  return 'Staff';
}

/// 본인 UID 또는 예외 전체관리자 계정은 권한 드롭다운을 바꿀 수 없다.
bool _canEditStaffRole(Map<String, dynamic> staff) {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  final String targetUid = (staff['uid'] ?? staff['id'] ?? '') as String? ?? '';
  if (uid != null && uid == targetUid) {
    return false;
  }
  final String em = (staff['email'] as String?)?.trim() ?? '';
  if (SuperAdmin.isSuperAdminEmail(em)) {
    return false;
  }
  return true;
}

/// `users/{uid}` 미러에서 직원명으로 쓸 문자열. 이메일과 동일하거나 이메일 형태면 제외한다.
String _staffMirrorPersonName(Map<String, dynamic> s) {
  final String email = (s['email'] as String?)?.trim() ?? '';
  final String rawName = (s['name'] as String?)?.trim() ?? '';
  final String rawDisp = (s['displayName'] as String?)?.trim() ?? '';
  bool junk(String v) => v.isEmpty || v.contains('@') || v == email;
  if (!junk(rawName)) {
    return rawName;
  }
  if (!junk(rawDisp)) {
    return rawDisp;
  }
  return '';
}

class _StaffListView extends StatefulWidget {
  const _StaffListView({required this.onEdit});

  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  State<_StaffListView> createState() => _StaffListViewState();
}

class _StaffListViewState extends State<_StaffListView> {
  final TextEditingController _searchC = TextEditingController();
  final ScrollController _staffHScroll = ScrollController();

  /// 상위(병합 프로필 스트림)가 자주 리빌드되어도 Firestore 구독이 매번 바뀌지 않도록 한 번만 연다.
  late final Stream<List<Map<String, dynamic>>> _usersMirrorStream;

  @override
  void initState() {
    super.initState();
    _usersMirrorStream =
        context.read<WorkFirestoreRepository>().watchUsersMirror();
  }

  static const TextStyle _staffColHeaderStyle = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w900,
    color: _slate400,
    letterSpacing: 2,
  );

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      final DateTime d = v.toDate();
      final String y = d.year.toString().padLeft(4, '0');
      final String m = d.month.toString().padLeft(2, '0');
      final String day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }
    return '-';
  }

  /// 이름, 사업소, 직책(`position` 또는 권한 문자열 `role`) 중 하나라도 포함되면 통과
  bool _staffMatches(Map<String, dynamic> s, String raw) {
    final String q = raw.trim().toLowerCase();
    if (q.isEmpty) return true;
    String low(dynamic v) => (v ?? '').toString().trim().toLowerCase();
    final String person = _staffMirrorPersonName(s).toLowerCase();
    final String branch =
        low(s['branchName']).isNotEmpty ? low(s['branchName']) : low(s['branch']);
    final String role = low(s['role']);
    final String position = low(s['position']);
    final String email = low(s['email']);
    return person.contains(q) ||
        email.contains(q) ||
        branch.contains(q) ||
        role.contains(q) ||
        position.contains(q);
  }

  @override
  void dispose() {
    _searchC.dispose();
    _staffHScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 600),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(40),
            decoration: const BoxDecoration(
              color: _slate50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(48),
                topRight: Radius.circular(48),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _navy,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: _navy.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.people, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '전사 직원 인사 관리',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _slate900,
                        letterSpacing: -0.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchC,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '이름, 사업소, 직책 검색...',
                      prefixIcon: const Icon(Icons.search, color: _slate400, size: 18),
                      suffixIcon: _searchC.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '검색어 지우기',
                              onPressed: () {
                                _searchC.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close, size: 18, color: _slate400),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 420,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _usersMirrorStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(
                        '직원 목록을 불러오지 못했습니다.\n${snap.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<Map<String, dynamic>> list = snap.data ?? <Map<String, dynamic>>[];
                final List<Map<String, dynamic>> filtered = list
                    .where((Map<String, dynamic> s) => _staffMatches(s, _searchC.text))
                    .toList();
                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    const double kTableMinScrollW = 1004;
                    final double viewW = constraints.maxWidth;
                    final double contentW = viewW <= 0
                        ? kTableMinScrollW
                        : (viewW < kTableMinScrollW ? kTableMinScrollW : viewW);

                    const EdgeInsets _cellPad = EdgeInsets.symmetric(horizontal: 10, vertical: 12);
                    const Map<int, TableColumnWidth> _staffColWidths = <int, TableColumnWidth>{
                      0: FixedColumnWidth(264),
                      1: FixedColumnWidth(104),
                      2: FixedColumnWidth(168),
                      3: FixedColumnWidth(76),
                      4: FixedColumnWidth(104),
                      5: FixedColumnWidth(104),
                      6: FixedColumnWidth(124),
                      7: FixedColumnWidth(56),
                    };

                    Widget th(String label, {TextAlign ta = TextAlign.center}) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        child: Text(label, textAlign: ta, style: _staffColHeaderStyle),
                      );
                    }

                    List<TableRow> buildTableRows() {
                      Widget positionCell(Map<String, dynamic> s) {
                        final String uid =
                            (s['uid'] ?? s['id'] ?? '') as String? ?? '';
                        final String pos = (s['position'] as String?)?.trim() ?? '';
                        if (pos.isNotEmpty || uid.trim().isEmpty) {
                          return Text(
                            pos.isEmpty ? '-' : pos,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _slate900,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }
                        // 인사관리 목록은 users/{uid} 미러만 구독하므로, position이 profile/main에만 있는 경우
                        // 여기서 1회 fallback으로 표시합니다.
                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirestorePaths.userProfileMainDoc(uid).snapshots(),
                          builder: (
                            BuildContext context,
                            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
                          ) {
                            final Map<String, dynamic> d = snap.data?.data() ?? <String, dynamic>{};
                            final String p = (d['position'] as String?)?.trim() ?? '';
                            return Text(
                              p.isEmpty ? '-' : p,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _slate900,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        );
                      }

                      final List<TableRow> rows = <TableRow>[
                        TableRow(
                          decoration: const BoxDecoration(color: _slate50),
                          children: <Widget>[
                            th('직원명', ta: TextAlign.left),
                            th('직책'),
                            th('소속 / 권한'),
                            th('상태'),
                            th('입사일자'),
                            th('퇴사일자'),
                            th('연락처'),
                            th('관리'),
                          ],
                        ),
                      ];
                      if (filtered.isEmpty) {
                        rows.add(
                          TableRow(
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 28),
                                child: Text(
                                  '검색 조건에 맞는 직원이 없습니다.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _slate400,
                                  ),
                                ),
                              ),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                              const SizedBox.shrink(),
                            ],
                          ),
                        );
                        return rows;
                      }
                      for (final Map<String, dynamic> s in filtered) {
                        final String email = (s['email'] ?? '') as String? ?? '';
                        final String personName = _staffMirrorPersonName(s);
                        final String primaryName = personName.isEmpty ? '-' : personName;
                        final String branch = (s['branchName'] ?? s['branch'] ?? '-') as String? ?? '-';
                        final String roleChip = _staffUiRoleFromMirror(s);
                        final String phone = (s['phone'] ?? '') as String? ?? '';
                        final String status = (s['employmentStatus'] ?? 'active') as String? ?? 'active';
                        final String joinedAt = _fmtTs(s['joinedAt']);
                        final String leavedAt = _fmtTs(s['leavedAt']);
                        final String? pendingBranch = (s['pendingBranch'] as String?)?.trim();
                        final String? pendingStatus = (s['pendingBranchStatus'] as String?)?.trim();
                        final bool hasPending =
                            (pendingBranch?.isNotEmpty == true) && pendingStatus == 'pending';
                        rows.add(
                          TableRow(
                            children: <Widget>[
                              Padding(
                                padding: _cellPad,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    if (hasPending)
                                      Tooltip(
                                        message: '소속 변경 승인 대기',
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () => widget.onEdit(s),
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.pending_actions_rounded,
                                              size: 22,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: _slate50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person, color: _slate400, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text(
                                            primaryName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: _slate900,
                                            ),
                                          ),
                                          if (email.isNotEmpty && email.trim() != primaryName)
                                            Text(
                                              email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _slate400,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: _cellPad,
                                child: Center(
                                  child: positionCell(s),
                                ),
                              ),
                              Padding(
                                padding: _cellPad,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      branch,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: _slate900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: roleChip == 'Master'
                                            ? const Color(0xFFFEF3C7)
                                            : (roleChip == 'HQ Admin'
                                                ? const Color(0xFFDBEAFE)
                                                : _slate50),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        roleChip,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: roleChip == 'Master'
                                              ? const Color(0xFFB45309)
                                              : (roleChip == 'HQ Admin' ? _navy : _slate400),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: _cellPad,
                                child: Center(
                                  child: Text(
                                    _statusLabel(status),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _slate900,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: _cellPad,
                                child: Center(
                                  child: Text(
                                    joinedAt,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _slate400,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: _cellPad,
                                child: Center(
                                  child: Text(
                                    leavedAt,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _slate400,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: _cellPad,
                                child: Center(
                                  child: Text(
                                    phone.isEmpty ? '-' : phone,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: _slate400),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Center(
                                  child: IconButton(
                                    tooltip: '편집',
                                    onPressed: () => widget.onEdit(s),
                                    icon: const Icon(Icons.edit_outlined),
                                    color: _slate400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return rows;
                    }

                    return Align(
                      alignment: Alignment.topCenter,
                      child: Scrollbar(
                        controller: _staffHScroll,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _staffHScroll,
                          scrollDirection: Axis.horizontal,
                          primary: false,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          child: SizedBox(
                            width: contentW,
                            child: Table(
                              columnWidths: _staffColWidths,
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              border: TableBorder(
                                horizontalInside: BorderSide(color: Colors.grey.shade200),
                                verticalInside: BorderSide(color: Colors.grey.shade200),
                                top: BorderSide(color: Colors.grey.shade300),
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                              children: buildTableRows(),
                            ),
                          ),
                        ),
                      ),
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

String _statusLabel(String v) {
  switch (v) {
    case 'active':
      return '재직';
    case 'leave':
      return '휴직';
    case 'retired':
      return '퇴직';
    default:
      return v;
  }
}

class _FirestoreBranchListView extends StatefulWidget {
  const _FirestoreBranchListView({
    required this.onEdit,
    required this.onCreate,
  });

  final ValueChanged<BranchModel> onEdit;
  final VoidCallback onCreate;

  @override
  State<_FirestoreBranchListView> createState() => _FirestoreBranchListViewState();
}

class _FirestoreBranchListViewState extends State<_FirestoreBranchListView> {
  late final Stream<List<BranchModel>> _branchesStream;

  @override
  void initState() {
    super.initState();
    _branchesStream = context.read<WorkFirestoreRepository>().watchBranches();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Firestore 사업소 (branches)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _navy,
                  letterSpacing: -0.5,
                ),
              ),
              FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('신규 사업소 등록'),
                style: FilledButton.styleFrom(
                  backgroundColor: _slate900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        StreamBuilder<List<BranchModel>>(
          stream: _branchesStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<BranchModel>> snap,
          ) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}'),
              );
            }
            final List<BranchModel> branches = snap.data ?? <BranchModel>[];
            if (branches.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('등록된 사업소가 없습니다.')),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _BranchListColumnHeader(),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: branches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int i) {
                      final BranchModel b = branches[i];
                      return _FirestoreBranchRow(
                        branch: b,
                        onEdit: () => widget.onEdit(b),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StaffEditDialog extends StatefulWidget {
  const _StaffEditDialog({
    required this.staff,
    required this.onClose,
  });

  final Map<String, dynamic> staff;
  final VoidCallback onClose;

  @override
  State<_StaffEditDialog> createState() => _StaffEditDialogState();
}

class _StaffEditDialogState extends State<_StaffEditDialog> {
  WorkFirestoreRepository get _repo => context.read<WorkFirestoreRepository>();

  final TextEditingController _empNameC = TextEditingController();
  late String _role;
  late String _branch;
  late String _email;
  late String _phone;
  late String _position;
  Uint8List? _photoBytes;
  String _status = 'active'; // active|leave|retired
  DateTime? _joinedAt;
  DateTime? _leavedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> d = widget.staff;
    final String uid = (d['uid'] ?? d['id'] ?? '') as String? ?? '';
    _empNameC.text = _staffMirrorPersonName(d);
    _role = _staffUiRoleFromMirror(d);
    _branch = d['branchName'] as String? ?? d['branch'] as String? ?? '본사';
    _email = d['email'] as String? ?? '';
    _phone = d['phone'] as String? ?? '';
    _position = (d['position'] as String?)?.trim() ?? '';
    _photoBytes = d['photoBytes'] as Uint8List?;
    _status = d['employmentStatus'] as String? ?? 'active';
    final Timestamp? j = d['joinedAt'] as Timestamp?;
    final Timestamp? l = d['leavedAt'] as Timestamp?;
    _joinedAt = j?.toDate();
    _leavedAt = l?.toDate();

    if (_position.isEmpty && uid.trim().isNotEmpty) {
      // users/{uid} 미러에 position이 없고 profile/main에만 있는 경우 보정
      FirestorePaths.userProfileMainDoc(uid).get().then((snap) {
        final Map<String, dynamic> pd = snap.data() ?? <String, dynamic>{};
        final String p = (pd['position'] as String?)?.trim() ?? '';
        if (p.isNotEmpty && mounted && _position.isEmpty) {
          setState(() => _position = p);
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _empNameC.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final Uint8List? bytes = r.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() => _photoBytes = bytes);
  }

  Future<void> _save() async {
    if (_saving) return;
    final String uid = (widget.staff['uid'] ?? widget.staff['id'] ?? '') as String? ?? '';
    if (uid.trim().isEmpty) {
      widget.onClose();
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoUrl;
      if (_photoBytes != null && _photoBytes!.isNotEmpty) {
        final PlatformFile pf = PlatformFile(
          name: 'profile.png',
          size: _photoBytes!.length,
          bytes: _photoBytes!,
        );
        photoUrl = await _repo.uploadProfilePhotoAndGetUrl(pf);
      }

      final Map<String, dynamic> patch = <String, dynamic>{
        'name': _empNameC.text.trim(),
        'displayName': _empNameC.text.trim(),
        'branch': _branch,
        'branchName': _branch,
        'email': _email,
        'phone': _phone,
        'position': _position.trim(),
        'employmentStatus': _status,
        'joinedAt': _joinedAt == null ? null : Timestamp.fromDate(_joinedAt!),
        'leavedAt': _leavedAt == null ? null : Timestamp.fromDate(_leavedAt!),
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

      final String staffEmail = (widget.staff['email'] as String?)?.trim() ?? '';
      final bool isSelf = FirebaseAuth.instance.currentUser?.uid == uid;
      if (SuperAdmin.isSuperAdminEmail(staffEmail)) {
        patch.addAll(_staffRolePrivilegePatch('Master'));
      } else if (!isSelf) {
        patch.addAll(_staffRolePrivilegePatch(_role));
      }

      await _repo.updateUserAndProfile(uid: uid, userPatch: patch, profilePatch: patch);
      if (mounted) setState(() => _saving = false);
      widget.onClose();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      // 다이얼로그 내에서는 간단히 닫지 않고 유지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String resolvedTitleName = _staffMirrorPersonName(widget.staff);
    final String titleName = resolvedTitleName.isEmpty ? '직원' : resolvedTitleName;
    final String uid = (widget.staff['uid'] ?? '') as String? ?? '';
    final String? pendingBranch = (widget.staff['pendingBranch'] as String?)?.trim();
    final String? pendingStatus = (widget.staff['pendingBranchStatus'] as String?)?.trim();
    final bool hasPending = (pendingBranch?.isNotEmpty == true) && pendingStatus == 'pending';
    return AlertDialog(
      title: Text('$titleName 편집'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _slate50,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _photoBytes != null && _photoBytes!.isNotEmpty
                        ? ClipOval(
                            child: Image.memory(
                              _photoBytes!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.person, color: _slate400),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('직원 이미지 변경'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _empNameC,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: '직원명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: <String>['Master', 'HQ Admin', 'Branch Manager', 'Staff'].contains(_role)
                    ? _role
                    : 'Staff',
                decoration: const InputDecoration(
                  labelText: '직무 권한',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'Master',
                    child: Text('Master (전체관리자)'),
                  ),
                  DropdownMenuItem(value: 'HQ Admin', child: Text('HQ Admin')),
                  DropdownMenuItem(
                    value: 'Branch Manager',
                    child: Text('Branch Manager'),
                  ),
                  DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                ],
                onChanged: _canEditStaffRole(widget.staff)
                    ? (String? v) => setState(() => _role = v ?? _role)
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _position,
                decoration: const InputDecoration(
                  labelText: '직책',
                  hintText: '직책을 입력하세요',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String v) => _position = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: '상태',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'active', child: Text('재직')),
                  DropdownMenuItem(value: 'leave', child: Text('휴직')),
                  DropdownMenuItem(value: 'retired', child: Text('퇴직')),
                ],
                onChanged: _saving ? null : (String? v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              final DateTime now = DateTime.now();
                              final DateTime? d = await showDatePicker(
                                context: context,
                                initialDate: _joinedAt ?? DateTime(now.year, now.month, now.day),
                                firstDate: DateTime(1990, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (d == null) return;
                              setState(() => _joinedAt = d);
                            },
                      child: Text(_joinedAt == null ? '입사일자 선택' : '입사일자: ${_joinedAt!.toIso8601String().substring(0, 10)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              final DateTime now = DateTime.now();
                              final DateTime? d = await showDatePicker(
                                context: context,
                                initialDate: _leavedAt ?? DateTime(now.year, now.month, now.day),
                                firstDate: DateTime(1990, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (d == null) return;
                              setState(() => _leavedAt = d);
                            },
                      child: Text(_leavedAt == null ? '퇴사일자 선택' : '퇴사일자: ${_leavedAt!.toIso8601String().substring(0, 10)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _branch,
                decoration: const InputDecoration(
                  labelText: '소속 사업소',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '본사', child: Text('본사')),
                  DropdownMenuItem(value: '인천 사업소', child: Text('인천 사업소')),
                  DropdownMenuItem(value: '서울 지부', child: Text('서울 지부')),
                ],
                onChanged: (String? v) =>
                    setState(() => _branch = v ?? _branch),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(
                  labelText: '업무 이메일',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String v) => _email = v.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _phone,
                decoration: const InputDecoration(
                  labelText: '연락처',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String v) => _phone = v.trim(),
              ),
              if (hasPending) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '소속 변경요청: $pendingBranch',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                try {
                                  await _repo.rejectBranchChange(uid: uid);
                                  if (mounted) setState(() => _saving = false);
                                  widget.onClose();
                                } catch (e) {
                                  if (mounted) setState(() => _saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('반려 실패: $e')),
                                  );
                                }
                              },
                        child: const Text('반려'),
                      ),
                      FilledButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                setState(() => _saving = true);
                                try {
                                  await _repo.approveBranchChange(
                                    uid: uid,
                                    nextBranchName: pendingBranch!,
                                  );
                                  if (mounted) setState(() => _saving = false);
                                  widget.onClose();
                                } catch (e) {
                                  if (mounted) setState(() => _saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('승인 실패: $e')),
                                  );
                                }
                              },
                        child: const Text('승인'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: widget.onClose, child: const Text('취소')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 18),
          label: const Text('저장'),
        ),
      ],
    );
  }
}

class _BranchEditFullPage extends StatelessWidget {
  const _BranchEditFullPage({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _EditView(
          item: _EditingItem(type: 'branch', data: data),
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _BranchListColumnHeader extends StatelessWidget {
  const _BranchListColumnHeader();

  static const TextStyle _h = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: _slate400,
  );

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text('사업소명', style: _h),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text('주소', style: _h),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text('사업소장', style: _h),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Text('전화번호', style: _h),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _FirestoreBranchRow extends StatelessWidget {
  const _FirestoreBranchRow({
    required this.branch,
    required this.onEdit,
  });

  final BranchModel branch;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String addr = branch.address ?? '-';
    final String phone = branch.phone ?? '-';
    final String head = branch.head ?? '-';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: Text(
                  branch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _slate900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  addr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  head,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 112,
                child: Text(
                  phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  tooltip: '편집',
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditingItem {
  _EditingItem({required this.type, required this.data});
  final String type;
  final Map<String, dynamic> data;
}

class _EditView extends StatelessWidget {
  const _EditView({required this.item, required this.onBack});

  final _EditingItem item;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (item.type == 'staff') {
      return _StaffEditForm(data: item.data, onBack: onBack);
    }
    final bool isNew = item.data['isNew'] == true;
    return FirestoreBranchEditForm(
      initial: item.data,
      isNew: isNew,
      onBack: onBack,
    );
  }
}

class _StaffEditForm extends StatelessWidget {
  const _StaffEditForm({required this.data, required this.onBack});

  final Map<String, dynamic> data;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(12, 8, 12, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('목록으로 돌아가기'),
          style: TextButton.styleFrom(
            foregroundColor: _slate400,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(64),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 256,
                padding: const EdgeInsets.all(64),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A8A), Color(0xFF172E6F)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${data['name']}  편집 모드',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _EditField(
                            label: '직무 권한 설정',
                            child: DropdownButtonFormField<String>(
                              value: data['role'] as String,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _slate50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: 'Master',
                                  child: Text('Master (전체관리자)'),
                                ),
                                DropdownMenuItem(value: 'HQ Admin', child: Text('HQ Admin')),
                                DropdownMenuItem(value: 'Branch Manager', child: Text('Branch Manager')),
                                DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                              ],
                              onChanged: (_) {},
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _EditField(
                            label: '소속 사업소',
                            child: DropdownButtonFormField<String>(
                              value: data['branch'] as String,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _slate50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(value: '본사', child: Text('본사')),
                                DropdownMenuItem(value: '인천 사업소', child: Text('인천 사업소')),
                                DropdownMenuItem(value: '서울 지부', child: Text('서울 지부')),
                              ],
                              onChanged: (_) {},
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: <Widget>[
                        Expanded(child: _EditField(label: '업무 이메일', value: data['email'] as String)),
                        const SizedBox(width: 24),
                        Expanded(child: _EditField(label: '연락처', value: data['phone'] as String)),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onBack,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('변경사항 저장'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _navy,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: _slate400,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        child ??
        TextField(
          controller: TextEditingController(text: value),
          decoration: InputDecoration(
            filled: true,
            fillColor: _slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }
}
