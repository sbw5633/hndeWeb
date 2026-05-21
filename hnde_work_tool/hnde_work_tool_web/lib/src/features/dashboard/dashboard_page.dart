import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/super_admin.dart';
import '../../theme/app_theme.dart';
import '../../models/branch_model.dart';
import '../../models/post_model.dart';
import '../../models/submission_model.dart';
import '../../models/todo_item_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../calendar/calendar_visibility.dart';
import '../common/enterprise_scaffold.dart';

const Color _navy = Color(0xFF1E3A8A);
const Color _slate900 = Color(0xFF0F172A);
const Color _slate400 = Color(0xFF94A3B8);
const Color _slate50 = Color(0xFFF8FAFC);

/// 프로토타입 v14: 통합 상황실 (Command Center) 레이아웃
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    final User? user = FirebaseAuth.instance.currentUser;
    final DocumentReference<Map<String, dynamic>>? profileRef =
        user == null ? null : FirestorePaths.userProfileMainDoc(user.uid);

    return EnterpriseScaffold(
      title: '대시보드',
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 16),
            _Header(profileRef: profileRef),
            const SizedBox(height: 32),
            _StatCards(repo: repo),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                const double xlBreak = 1280;
                final bool xl = c.maxWidth >= xlBreak;
                if (!xl) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _MaterialMonitoring(repo: repo),
                      const SizedBox(height: 24),
                      _TodaysFocus(repo: repo),
                      const SizedBox(height: 24),
                      _CommunityNews(repo: repo),
                      const SizedBox(height: 24),
                      _Timeline(repo: repo),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 8,
                          child: _MaterialMonitoring(repo: repo),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 4,
                          child: _TodaysFocus(repo: repo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 6,
                          child: _CommunityNews(repo: repo),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 6,
                          child: _Timeline(repo: repo),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({this.profileRef});

  final DocumentReference<Map<String, dynamic>>? profileRef;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  String _greeting(DateTime now) {
    final int h = now.hour;
    if (h < 5) return '야간 근무도 고생 많으세요.';
    if (h < 11) return '좋은 아침입니다. 오늘도 힘차게 시작해요.';
    if (h < 14) return '점심 전후로 잠깐 숨 고르고 가세요.';
    if (h < 18) return '오후도 집중해서 마무리해봐요.';
    if (h < 22) return '오늘도 수고 많으셨습니다.';
    return '늦은 시간까지 고생 많으세요.';
  }

  @override
  Widget build(BuildContext context) {
    final String nowText = DateFormat('yyyy년 MM월 dd일 HH시mm분').format(_now);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.profileRef?.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
      ) {
        final Map<String, dynamic> d = snap.data?.data() ?? <String, dynamic>{};
        final String name = (d['name'] as String?)?.trim().isNotEmpty == true
            ? (d['name'] as String).trim()
            : (FirebaseAuth.instance.currentUser?.email ?? '사용자');
        final String position = (d['position'] as String?)?.trim() ?? '';
        final String branch = (d['branchName'] as String?)?.trim() ?? '';

        // 사용자 설정 폰트(ThemeData.fontFamily)를 확실히 타도록 textTheme 기반으로 구성
        final TextStyle metaStyle = (Theme.of(context).textTheme.labelMedium ??
                const TextStyle())
            .copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: _slate400,
          letterSpacing: 1.2,
        );
        final TextStyle greetStyle =
            (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
                .copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: _slate900,
          letterSpacing: -0.2,
          height: 1.15,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                nowText,
                style: metaStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: greetStyle,
                  children: <InlineSpan>[
                    if (branch.isNotEmpty)
                      TextSpan(
                        text: branch,
                        style: greetStyle.copyWith(
                          color: _navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (branch.isNotEmpty) const TextSpan(text: '  '),
                    if (position.isNotEmpty)
                      TextSpan(
                        text: position,
                        style: greetStyle.copyWith(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    if (position.isNotEmpty) const TextSpan(text: '  '),
                    TextSpan(text: '$name님 '),
                    TextSpan(
                      text: _greeting(_now),
                      style: greetStyle.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCards extends StatelessWidget {
  const _StatCards({required this.repo});

  final WorkFirestoreRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SubmissionModel>>(
      stream: repo.watchSubmissions(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<SubmissionModel>> subSnap,
      ) {
        final List<SubmissionModel> subs = subSnap.data ?? <SubmissionModel>[];
        final int subCount = subs.length;

        return StreamBuilder<List<TodoItemModel>>(
          stream: repo.watchTodosForDate(
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<TodoItemModel>> todoSnap,
          ) {
            final List<TodoItemModel> todos = todoSnap.data ?? <TodoItemModel>[];
            final int pendingCount = todos.where((t) => !t.completed).length;

            return StreamBuilder<List<PostModel>>(
              stream: repo.watchPosts('notice'),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<PostModel>> noticeSnap,
              ) {
                final int noticeCount = noticeSnap.data?.length ?? 0;

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: repo.watchUpcomingEvents(limit: 10),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> eventSnap,
                  ) {
                    final DateTime now = DateTime.now();
                    final int todayEventCount = (eventSnap.data ?? <Map<String, dynamic>>[])
                        .where((Map<String, dynamic> e) {
                      final dynamic s = e['start'];
                      if (s is! Timestamp) return false;
                      final DateTime dt = s.toDate();
                      return dt.year == now.year &&
                          dt.month == now.month &&
                          dt.day == now.day;
                    })
                        .length;

                    return Consumer<AppThemeNotifier>(
                      builder: (
                        BuildContext context,
                        AppThemeNotifier themeNotifier,
                        _,
                      ) {
                        final AppThemeData theme = themeNotifier.theme;
                        const double cardHeight = 100.0;
                        return LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints c) {
                            final bool narrow = c.maxWidth < 980;
                            if (narrow) {
                              // 좁은 화면: 기존처럼 wrap(2x2) 유지
                              const double cardWidth = 280.0;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: <Widget>[
                                  SizedBox(
                                    width: cardWidth,
                                    height: cardHeight,
                                    child: _StatCard(
                                      icon: Icons.send_rounded,
                                      label: '자료 송수신',
                                      value: '$subCount',
                                      unit: '건 진행중',
                                      color: 'blue',
                                      radius: theme.radius,
                                      primaryColor: theme.primary,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    height: cardHeight,
                                    child: _StatCard(
                                      icon: Icons.check_box_outlined,
                                      label: '미처리 업무',
                                      value: '$pendingCount',
                                      unit: '건 보류',
                                      color: 'indigo',
                                      radius: theme.radius,
                                      primaryColor: theme.primary,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    height: cardHeight,
                                    child: _StatCard(
                                      icon: Icons.calendar_month_rounded,
                                      label: '오늘의 일정',
                                      value: '$todayEventCount',
                                      unit: '건 예정',
                                      color: 'green',
                                      radius: theme.radius,
                                      primaryColor: theme.primary,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    height: cardHeight,
                                    child: _StatCard(
                                      icon: Icons.campaign_outlined,
                                      label: '공지 및 알림',
                                      value: '$noticeCount',
                                      unit: '건 미확인',
                                      color: 'orange',
                                      radius: theme.radius,
                                      primaryColor: theme.primary,
                                    ),
                                  ),
                                ],
                              );
                            }

                            final double maxW = c.maxWidth;
                            final double gap = 16;
                            final double cardW = ((maxW - gap * 3) / 4).clamp(230.0, 360.0);

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                SizedBox(
                                  width: cardW,
                                  height: cardHeight,
                                  child: _StatCard(
                                    icon: Icons.send_rounded,
                                    label: '자료 송수신',
                                    value: '$subCount',
                                    unit: '건 진행중',
                                    color: 'blue',
                                    radius: theme.radius,
                                    primaryColor: theme.primary,
                                  ),
                                ),
                                SizedBox(width: gap),
                                SizedBox(
                                  width: cardW,
                                  height: cardHeight,
                                  child: _StatCard(
                                    icon: Icons.check_box_outlined,
                                    label: '미처리 업무',
                                    value: '$pendingCount',
                                    unit: '건 보류',
                                    color: 'indigo',
                                    radius: theme.radius,
                                    primaryColor: theme.primary,
                                  ),
                                ),
                                SizedBox(width: gap),
                                SizedBox(
                                  width: cardW,
                                  height: cardHeight,
                                  child: _StatCard(
                                    icon: Icons.calendar_month_rounded,
                                    label: '오늘의 일정',
                                    value: '$todayEventCount',
                                    unit: '건 예정',
                                    color: 'green',
                                    radius: theme.radius,
                                    primaryColor: theme.primary,
                                  ),
                                ),
                                SizedBox(width: gap),
                                SizedBox(
                                  width: cardW,
                                  height: cardHeight,
                                  child: _StatCard(
                                    icon: Icons.campaign_outlined,
                                    label: '공지 및 알림',
                                    value: '$noticeCount',
                                    unit: '건 미확인',
                                    color: 'orange',
                                    radius: theme.radius,
                                    primaryColor: theme.primary,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.radius,
    required this.primaryColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String color;
  final double radius;
  final Color primaryColor;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Color _colorValue() {
    switch (widget.color) {
      case 'blue':
        return const Color(0xFF2563EB);
      case 'indigo':
        return const Color(0xFF4F46E5);
      case 'green':
        return const Color(0xFF16A34A);
      case 'orange':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color _colorBg50() {
    switch (widget.color) {
      case 'blue':
        return const Color(0xFFEFF6FF);
      case 'indigo':
        return const Color(0xFFEEF2FF);
      case 'green':
        return const Color(0xFFF0FDF4);
      case 'orange':
        return const Color(0xFFFFF7ED);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _colorValue();
    final Color bg50 = _colorBg50();
    final Color primaryColor = widget.primaryColor;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _rotationController.forward(from: 0);
      },
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: _hovered ? 24 : 12,
              offset: Offset(0, _hovered ? 4 : 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: _hovered ? accentColor : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(widget.radius),
                    bottomRight: Radius.circular(widget.radius),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: -40,
              child: AnimatedScale(
                scale: _hovered ? 1.5 : 1,
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: bg50.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (BuildContext context, Widget? child) {
                          return Transform.rotate(
                            angle: _rotationController.value * 2 * 3.14159,
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                        child: Icon(
                          widget.icon,
                          size: 24,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _slate400,
                              letterSpacing: 0.4,
                              fontStyle: FontStyle.italic,
                              height: 1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.value}${widget.unit}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _slate900,
                              letterSpacing: -0.5,
                              fontStyle: FontStyle.italic,
                              height: 1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [위젯 1] 자료 송수신 모니터링 - 참조번호, 제목, 소속, 우선순위
class _MaterialMonitoring extends StatelessWidget {
  const _MaterialMonitoring({required this.repo});

  final WorkFirestoreRepository repo;

  static String _formatDueDate(Timestamp? ts) {
    final DateTime? d = ts?.toDate();
    if (d == null) return '-';
    return DateFormat('MM/dd').format(d);
  }

  static String _displayNameFromUserMirror(Map<String, dynamic>? u) {
    if (u == null) return '';
    final String n = (u['name'] as String?)?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final String dn = (u['displayName'] as String?)?.trim() ?? '';
    if (dn.isNotEmpty) return dn;
    final String em = (u['email'] as String?)?.trim() ?? '';
    return em;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool narrow = c.maxWidth < 600;
        return Container(
          constraints: BoxConstraints(minHeight: narrow ? 320 : 450),
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
            padding: EdgeInsets.all(narrow ? 20 : 40),
            decoration: const BoxDecoration(
              color: _slate50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(48),
                topRight: Radius.circular(48),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(narrow ? 8 : 12),
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
                        child: const Icon(
                        Icons.folder_copy_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '자료 송수신 모니터링',
                              style: TextStyle(
                                fontSize: narrow ? 16 : 20,
                                fontWeight: FontWeight.w900,
                                color: _slate900,
                                letterSpacing: -0.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (!narrow) ...[
                              const SizedBox(height: 4),
                              Text(
                                '사업소별 제출물 실시간 트래킹',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _slate400,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/exchange'),
                  style: TextButton.styleFrom(
                    foregroundColor: _slate400,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: const Text('[전체보기]'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: narrow ? 280 : 400,
            child: StreamBuilder<List<SubmissionModel>>(
              stream: repo.watchSubmissions(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<SubmissionModel>> snap,
              ) {
                final List<SubmissionModel> list =
                    snap.data ?? <SubmissionModel>[];
                if (list.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        '등록된 자료가 없습니다.',
                        style: TextStyle(color: _slate400, fontSize: 13),
                      ),
                    ),
                  );
                }

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: repo.watchUsersMirror(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> usersSnap,
                  ) {
                    final Map<String, Map<String, dynamic>> byUid =
                        <String, Map<String, dynamic>>{
                      for (final Map<String, dynamic> u in (usersSnap.data ?? <Map<String, dynamic>>[]))
                        (u['uid'] ?? '').toString(): u,
                    };

                    final int takeN = narrow ? 5 : 7;
                    final List<SubmissionModel> shown =
                        list.length > takeN ? list.sublist(0, takeN) : list;

                    Widget chip(SubmissionModel s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: s.isUrgent ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: s.isUrgent ? const Color(0xFFFED7AA) : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Text(
                          s.isUrgent ? '긴급' : '일반',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: s.isUrgent ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                          ),
                        ),
                      );
                    }

                    Widget rowHeader() {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                        child: Row(
                          children: const <Widget>[
                            SizedBox(
                              width: 74,
                              child: Text(
                                '제출기한',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _slate400,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '제목',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _slate400,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            SizedBox(
                              width: 110,
                              child: Text(
                                '요청자',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _slate400,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            SizedBox(
                              width: 64,
                              child: Text(
                                '우선순위',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _slate400,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        children: <Widget>[
                          rowHeader(),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              itemCount: shown.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int i) {
                                final SubmissionModel s = shown[i];
                                final String requester = _displayNameFromUserMirror(byUid[s.createdByUid]).trim().isNotEmpty
                                    ? _displayNameFromUserMirror(byUid[s.createdByUid])
                                    : '-';
                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => context.go('/exchange/${s.id}'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: narrow
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: <Widget>[
                                                Row(
                                                  children: <Widget>[
                                                    Text(
                                                      _formatDueDate(s.dueDate),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w800,
                                                        color: _slate400,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        s.title,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w900,
                                                          color: _slate900,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    chip(s),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Align(
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    requester,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: _slate400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              children: <Widget>[
                                                SizedBox(
                                                  width: 74,
                                                  child: Text(
                                                    _formatDueDate(s.dueDate),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w800,
                                                      color: _slate400,
                                                      fontFamily: 'monospace',
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    s.title,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w900,
                                                      color: _slate900,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                SizedBox(
                                                  width: 110,
                                                  child: Text(
                                                    requester,
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: _slate400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                SizedBox(width: 64, child: Align(alignment: Alignment.centerRight, child: chip(s))),
                                              ],
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
      },
    );
  }
}

/// [위젯 2] 오늘의 할 일 - 네이비 카드
class _TodaysFocus extends StatelessWidget {
  const _TodaysFocus({required this.repo});

  final WorkFirestoreRepository repo;

  @override
  Widget build(BuildContext context) {
    final String todayKey =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(56),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _navy.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.check_box_outlined,
                        color: const Color(0xFF93C5FD),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "오늘의 할 일",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 24, bottom: 24),
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
              SizedBox(
                height: 220,
                child: StreamBuilder<List<TodoItemModel>>(
                  stream: repo.watchTodosForDate(todayKey),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<TodoItemModel>> snap,
                  ) {
                    final List<TodoItemModel> todos =
                        (snap.data ?? <TodoItemModel>[])
                            .where((TodoItemModel t) => !t.completed)
                            .toList();
                    if (todos.isEmpty) {
                      return Center(
                        child: Text(
                          '오늘 할 일이 없습니다.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: todos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (BuildContext context, int i) {
                        final TodoItemModel t = todos[i];
                        return InkWell(
                          onTap: () => context.go('/todo'),
                          borderRadius: BorderRadius.circular(32),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF60A5FA),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        t.title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (t.timeStr.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          '마감 ${t.timeStr}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF93C5FD),
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/todo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    '전체 일정 관리',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [위젯 3] 커뮤니티 소식 - 공지
class _CommunityNews extends StatelessWidget {
  const _CommunityNews({required this.repo});

  final WorkFirestoreRepository repo;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      padding: const EdgeInsets.all(40),
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
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                '커뮤니티 소식',
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
          const SizedBox(height: 40),
          SizedBox(
            height: 320,
            child: StreamBuilder<List<PostModel>>(
              stream: repo.watchPosts('notice'),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<PostModel>> noticeSnap,
              ) {
                final List<PostModel> notices =
                    noticeSnap.data ?? <PostModel>[];
                if (notices.isEmpty) {
                  return Center(
                    child: Text(
                      '공지가 없습니다.',
                      style: TextStyle(color: _slate400, fontSize: 13),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: notices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int i) {
                    final PostModel p = notices[i];
                    return InkWell(
                      onTap: () => context.go('/board/notice/${p.id}'),
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _slate50,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _slate400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    p.isOfficial ? '필독 공지' : '공지',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFEA580C),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _slate900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: _slate400,
                            ),
                          ],
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

/// [위젯 4] 주요 업무 타임라인
class _Timeline extends StatelessWidget {
  const _Timeline({required this.repo});

  final WorkFirestoreRepository repo;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      padding: const EdgeInsets.all(40),
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
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                '주요 업무 타임라인',
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
          const SizedBox(height: 40),
          SizedBox(
            height: 320,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: () {
                final String? uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) {
                  return const Stream<
                      DocumentSnapshot<Map<String, dynamic>>>.empty();
                }
                return FirestorePaths.userProfileMainDoc(uid).snapshots();
              }(),
              builder: (
                BuildContext context,
                AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> profSnap,
              ) {
                final Map<String, dynamic> prof =
                    profSnap.data?.data() ?? <String, dynamic>{};
                final int roleIdx =
                    (prof['roleIdx'] as num?)?.toInt() ?? 999;
                final bool isMainAdmin = SuperAdmin.effectiveMainAdmin(
                  profileMainAdmin: prof['mainAdmin'],
                  profileEmail: prof['email'] as String?,
                  authEmail: FirebaseAuth.instance.currentUser?.email,
                  roleIdx: roleIdx,
                );
                final String myUid =
                    FirebaseAuth.instance.currentUser?.uid ?? '';
                final String profileBranch =
                    (prof['branchName'] as String?)?.trim().isNotEmpty == true
                        ? (prof['branchName'] as String).trim()
                        : (prof['branch'] as String?)?.trim() ?? '';

                return StreamBuilder<List<BranchModel>>(
                  stream: repo.watchBranches(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<BranchModel>> branchSnap,
                  ) {
                    final List<BranchModel> branches =
                        branchSnap.data ?? <BranchModel>[];
                    String myBranchId = '';
                    String myBranchName = profileBranch;
                    for (final BranchModel b in branches) {
                      if (b.id == profileBranch || b.name == profileBranch) {
                        myBranchId = b.id;
                        myBranchName = b.name;
                        break;
                      }
                    }
                    return _TimelineEvents(
                      repo: repo,
                      isMainAdmin: isMainAdmin,
                      myUid: myUid,
                      myBranchId: myBranchId,
                      myBranchName: myBranchName,
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

class _TimelineEvents extends StatelessWidget {
  const _TimelineEvents({
    required this.repo,
    required this.isMainAdmin,
    required this.myUid,
    required this.myBranchId,
    required this.myBranchName,
  });

  final WorkFirestoreRepository repo;
  final bool isMainAdmin;
  final String myUid;
  final String myBranchId;
  final String myBranchName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.watchUpcomingEvents(limit: 60),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Map<String, dynamic>>> snap,
      ) {
        final List<Map<String, dynamic>> rawEvents =
            snap.data ?? <Map<String, dynamic>>[];
        final List<Map<String, dynamic>> events = rawEvents
            .where(
              (Map<String, dynamic> e) => isCalendarEventVisibleTo(
                e,
                isMainAdmin: isMainAdmin,
                myUid: myUid,
                myBranchId: myBranchId,
                myBranchName: myBranchName,
              ),
            )
            .take(20)
            .toList();
        if (events.isEmpty) {
          return Center(
            child: Text(
              '예정된 일정이 없습니다.',
              style: TextStyle(color: _slate400, fontSize: 13),
            ),
          );
        }
                return ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 24),
                  itemBuilder: (BuildContext context, int i) {
                    final Map<String, dynamic> e = events[i];
                    final dynamic start = e['start'];
                    DateTime? dt;
                    if (start is Timestamp) {
                      dt = start.toDate();
                    }
                    final String title =
                        e['title'] as String? ?? '제목 없음';
                    final String monthStr = dt != null
                        ? DateFormat('MMM', 'ko_KR').format(dt)
                        : '';
                    final String dayStr =
                        dt != null ? '${dt.day}' : '-';
                    return InkWell(
                      onTap: () => context.go('/calendar'),
                      borderRadius: BorderRadius.circular(32),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _slate50,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Text(
                                    monthStr.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: _slate400,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dayStr,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: _slate900,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF16A34A),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '사내 일정',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF16A34A),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _slate900,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  if (dt != null) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: <Widget>[
                                        Icon(Icons.access_time, size: 12, color: _slate400),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat('HH:mm').format(dt),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _slate400,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Icon(Icons.person_outline, size: 12, color: _slate400),
                                        const SizedBox(width: 8),
                                        Text(
                                          e['visibility'] as String? ?? '전략기획팀',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _slate400,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
  }
}

