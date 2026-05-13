import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../models/branch_model.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import 'calendar_day_keys.dart';
import 'calendar_schedule_modal.dart';
import 'korean_holidays.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// 달력이 가리키는 **중심 월**(1일 기준). 좌·우는 이전·다음 달.
  DateTime _centerMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay = _todayDateOnly();
  late final WorkFirestoreRepository _repo;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _calendarEventsSub;
  int _subscriptionCenterYear = 0;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _calendarDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  bool _calendarLoaded = false;
  String? _calendarError;

  /// 월 변경 애니메이션 방향: -1 이전 달, 1 다음 달
  int _monthSlideDir = 0;

  static DateTime _todayDateOnly() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _monthFirst(DateTime d) => DateTime(d.year, d.month, 1);

  DateTime get _prevMonthFirst =>
      DateTime(_centerMonth.year, _centerMonth.month - 1, 1);

  DateTime get _nextMonthFirst =>
      DateTime(_centerMonth.year, _centerMonth.month + 1, 1);

  static String _formatYearMonth(DateTime monthFirst) =>
      '${monthFirst.year}년 ${monthFirst.month}월';

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    _syncCalendarSubscriptionToFocusedYear();
  }

  @override
  void dispose() {
    _calendarEventsSub?.cancel();
    super.dispose();
  }

  void _syncCalendarSubscriptionToFocusedYear() {
    final int y = _centerMonth.year;
    if (_subscriptionCenterYear == y && _calendarEventsSub != null) {
      return;
    }
    _subscribeCalendarForCenterYear(y);
  }

  void _subscribeCalendarForCenterYear(int centerYear) {
    _calendarEventsSub?.cancel();
    _subscriptionCenterYear = centerYear;
    if (mounted) {
      setState(() {
        _calendarDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        _calendarLoaded = false;
        _calendarError = null;
      });
    }
    final DateTime from = DateTime(centerYear - 1, 1, 1);
    final DateTime to = DateTime(centerYear + 1, 12, 31, 23, 59, 59, 999);

    _calendarEventsSub = FirestorePaths.calendarEventsCol()
        .where(
          'start',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from),
        )
        .where(
          'start',
          isLessThanOrEqualTo: Timestamp.fromDate(to),
        )
        .orderBy('start')
        .snapshots()
        .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            if (!mounted) {
              return;
            }
            setState(() {
              _calendarDocs = snapshot.docs;
              _calendarLoaded = true;
              _calendarError = null;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) {
              return;
            }
            setState(() {
              _calendarError = error.toString();
              _calendarLoaded = true;
            });
          },
        );
  }

  void _onDayPicked(DateTime day) {
    final DateTime dayOnly = DateTime(day.year, day.month, day.day);
    final DateTime newCenter = _monthFirst(dayOnly);
    setState(() {
      if (newCenter != _centerMonth) {
        _monthSlideDir = newCenter.isBefore(_centerMonth) ? -1 : 1;
        _centerMonth = newCenter;
      }
      _selectedDay = dayOnly;
    });
    _syncCalendarSubscriptionToFocusedYear();
  }

  void _onCenterPageChanged(DateTime focusedDay) {
    final DateTime newCenter = _monthFirst(focusedDay);
    if (newCenter == _centerMonth) {
      return;
    }
    setState(() {
      _monthSlideDir = newCenter.isBefore(_centerMonth) ? -1 : 1;
      _centerMonth = newCenter;
    });
    _syncCalendarSubscriptionToFocusedYear();
  }

  BranchModel? _resolveUserBranch(
    Map<String, dynamic>? prof,
    List<BranchModel> branches,
  ) {
    if (prof == null) {
      return null;
    }
    final String? bn = (prof['branchName'] as String?)?.trim();
    final String? br = (prof['branch'] as String?)?.trim();
    final String key = (bn != null && bn.isNotEmpty) ? bn : (br ?? '');
    if (key.isEmpty) {
      return null;
    }
    for (final BranchModel b in branches) {
      if (b.id == key || b.name == key) {
        return b;
      }
    }
    return null;
  }

  CalendarBuilders<void> _calendarBuilders() {
    return CalendarBuilders<void>(
      dowBuilder: (BuildContext context, DateTime day) {
        final String text = <int, String>{
              DateTime.monday: '월',
              DateTime.tuesday: '화',
              DateTime.wednesday: '수',
              DateTime.thursday: '목',
              DateTime.friday: '금',
              DateTime.saturday: '토',
              DateTime.sunday: '일',
            }[day.weekday] ??
            '';
        final bool weekend = day.weekday == DateTime.saturday ||
            day.weekday == DateTime.sunday;
        return Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: weekend ? Colors.red.shade700 : null,
            ),
          ),
        );
      },
      defaultBuilder: (BuildContext context, DateTime day, DateTime _) {
        final String? hn = koreanHolidayName(day);
        final bool weekend = day.weekday == DateTime.saturday ||
            day.weekday == DateTime.sunday;
        final bool holiday = hn != null;
        if (!holiday && !weekend) {
          return null;
        }
        return Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: holiday ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        );
      },
      markerBuilder: (BuildContext context, DateTime day, List<void> events) {
        final String? hn = koreanHolidayName(day);
        if (hn == null) {
          return null;
        }
        return Positioned(
          bottom: 2,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                hn,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _monthTableCell({
    required DateTime focusedMonthFirst,
    required bool allowSwipe,
    required double opacity,
  }) {
    final DateTime today = DateTime.now();
    final DateTime firstDay = DateTime(today.year - 1, 1, 1);
    final DateTime lastDay = DateTime(today.year + 1, 12, 31);

    final Widget cal = TableCalendar<void>(
      locale: 'ko_KR',
      firstDay: firstDay,
      lastDay: lastDay,
      focusedDay: focusedMonthFirst,
      holidayPredicate: isKoreanHoliday,
      headerVisible: false,
      availableGestures:
          allowSwipe ? AvailableGestures.horizontalSwipe : AvailableGestures.none,
      selectedDayPredicate: (DateTime day) =>
          _selectedDay != null &&
          day.year == _selectedDay!.year &&
          day.month == _selectedDay!.month &&
          day.day == _selectedDay!.day,
      onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
        _onDayPicked(selectedDay);
      },
      onPageChanged: allowSwipe ? _onCenterPageChanged : null,
      calendarFormat: CalendarFormat.month,
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronVisible: false,
        rightChevronVisible: false,
      ),
      calendarBuilders: _calendarBuilders(),
    );

    if (opacity >= 0.999) {
      return cal;
    }
    return Opacity(opacity: opacity, child: cal);
  }

  /// 이전/다음 달: 중앙 월과의 구분만 살짝 나게(과한 그라데이션 금지)
  Widget _sideMonthWithGradient({
    required bool isPreviousMonth,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
            ),
          ),
          // 중앙 월과의 경계만 은은하게 표시
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isPreviousMonth ? Alignment.centerRight : Alignment.centerLeft,
                    end: isPreviousMonth ? Alignment.centerLeft : Alignment.centerRight,
                    colors: <Color>[
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.55),
                    ],
                    stops: const <double>[0.0, 0.22],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _centerMonthPanel(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: child,
      ),
    );
  }

  Widget _wideThreeMonthsBlock() {
    final TextStyle mutedYm = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade500,
    );
    final TextStyle strongYm = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w900,
      color: Colors.grey.shade900,
    );

    final Widget block = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Text(_formatYearMonth(_prevMonthFirst), style: mutedYm),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(_formatYearMonth(_centerMonth), style: strongYm),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(_formatYearMonth(_nextMonthFirst), style: mutedYm),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _sideMonthWithGradient(
                  isPreviousMonth: true,
                  child: _monthTableCell(
                    focusedMonthFirst: _prevMonthFirst,
                    allowSwipe: false,
                    opacity: 0.72,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _centerMonthPanel(
                  _monthTableCell(
                    focusedMonthFirst: _centerMonth,
                    allowSwipe: true,
                    opacity: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _sideMonthWithGradient(
                  isPreviousMonth: false,
                  child: _monthTableCell(
                    focusedMonthFirst: _nextMonthFirst,
                    allowSwipe: false,
                    opacity: 0.72,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final double dx = _monthSlideDir == 0 ? 0 : (_monthSlideDir * 0.08);
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(dx, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(
          '${_centerMonth.year}-${_centerMonth.month.toString().padLeft(2, '0')}',
        ),
        child: block,
      ),
    );
  }

  static const double _kWideBreakpoint = 920;
  static const double _kMaxCalendarRowWidth = 1240;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final DateTime firstDay = DateTime(today.year - 1, 1, 1);
    final DateTime lastDay = DateTime(today.year + 1, 12, 31);

    return EnterpriseScaffold(
      title: '업무 캘린더',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                '업무 캘린더',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final DateTime t = _todayDateOnly();
                  setState(() {
                    _selectedDay = t;
                    _centerMonth = _monthFirst(t);
                    _monthSlideDir = 0;
                  });
                  _syncCalendarSubscriptionToFocusedYear();
                },
                icon: const Icon(Icons.today, size: 18),
                label: const Text('오늘'),
              ),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: () {
                  final String? uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) {
                    return Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
                  }
                  return FirestorePaths.userProfileMainDoc(uid).snapshots();
                }(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> profSnap,
                ) {
                  return StreamBuilder<List<BranchModel>>(
                    stream: _repo.watchBranches(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<List<BranchModel>> branchSnap,
                    ) {
                      final Map<String, dynamic>? prof = profSnap.data?.data();
                      final List<BranchModel> branches =
                          branchSnap.data ?? <BranchModel>[];
                      final BranchModel? branch =
                          _resolveUserBranch(prof, branches);
                      final String branchName = branch?.name ?? '사업소';

                      return ElevatedButton.icon(
                        onPressed: () async {
                          final DateTime baseDate =
                              _selectedDay ?? _todayDateOnly();
                          await showCalendarScheduleModal(
                            context,
                            baseDate: baseDate,
                            branchName: branchName,
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('일정 등록'),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double w = constraints.maxWidth;
              final bool wide = w >= _kWideBreakpoint;
              final double capW = math.min(w, _kMaxCalendarRowWidth);

              final Widget calendarArea = wide
                  ? Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: capW),
                        child: _wideThreeMonthsBlock(),
                      ),
                    )
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TableCalendar<void>(
                          locale: 'ko_KR',
                          firstDay: firstDay,
                          lastDay: lastDay,
                          focusedDay: _centerMonth,
                          holidayPredicate: isKoreanHoliday,
                          selectedDayPredicate: (DateTime day) =>
                              _selectedDay != null &&
                              day.year == _selectedDay!.year &&
                              day.month == _selectedDay!.month &&
                              day.day == _selectedDay!.day,
                          onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
                            _onDayPicked(selectedDay);
                          },
                          onPageChanged: _onCenterPageChanged,
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: false,
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          calendarBuilders: _calendarBuilders(),
                        ),
                      ),
                    );

              return Align(
                alignment: Alignment.topCenter,
                child: wide
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                            child: calendarArea,
                          ),
                        ),
                      )
                    : calendarArea,
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_selectedDay != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        '${_selectedDay!.year}년 '
                        '${_selectedDay!.month}월 '
                        '${_selectedDay!.day}일 일정',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  if (_selectedDay == null)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        '날짜를 선택해 주세요.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: () {
                          final String? uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid == null) {
                            return Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
                          }
                          return FirestorePaths.userProfileMainDoc(uid).snapshots();
                        }(),
                        builder: (
                          BuildContext context,
                          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> profSnap,
                        ) {
                          return StreamBuilder<List<BranchModel>>(
                            stream: _repo.watchBranches(),
                            builder: (
                              BuildContext context,
                              AsyncSnapshot<List<BranchModel>> branchSnap,
                            ) {
                              final String? uid = FirebaseAuth.instance.currentUser?.uid;
                              final Map<String, dynamic>? prof = profSnap.data?.data();
                              final List<BranchModel> branches = branchSnap.data ?? <BranchModel>[];
                              final BranchModel? branch = _resolveUserBranch(prof, branches);
                              final String myBranchId = branch?.id ?? '';
                              final String myBranchName = branch?.name ?? '';

                              return _CalendarEventList(
                                selectedDay: _selectedDay,
                                docs: _calendarDocs,
                                loaded: _calendarLoaded,
                                errorMessage: _calendarError,
                                myUid: uid,
                                myBranchId: myBranchId,
                                myBranchName: myBranchName,
                                onAddEvent: () async {
                                  final DateTime baseDate = _selectedDay ?? _todayDateOnly();
                                  await showCalendarScheduleModal(
                                    context,
                                    baseDate: baseDate,
                                    branchName: myBranchName.isNotEmpty ? myBranchName : '사업소',
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEventList extends StatelessWidget {
  const _CalendarEventList({
    required this.selectedDay,
    required this.docs,
    required this.loaded,
    this.errorMessage,
    this.myUid,
    this.myBranchId = '',
    this.myBranchName = '',
    required this.onAddEvent,
  });

  final DateTime? selectedDay;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool loaded;
  final String? errorMessage;
  final String? myUid;
  final String myBranchId;
  final String myBranchName;
  final VoidCallback onAddEvent;

  bool _isVisibleToMe(Map<String, dynamic> data) {
    final String scope = (data['scope'] as String?)?.trim() ?? 'private';
    if (scope == 'private') {
      final String owner = (data['createdByUid'] as String?)?.trim() ?? '';
      final String me = (myUid ?? '').trim();
      return me.isNotEmpty && owner.isNotEmpty && owner == me;
    }
    if (scope == 'branch') {
      final String eventBranch = (data['branchName'] as String?)?.trim() ?? '';
      if (eventBranch.isEmpty) return false;
      if (myBranchName.trim().isNotEmpty && eventBranch == myBranchName.trim()) {
        return true;
      }
      if (myBranchId.trim().isNotEmpty && eventBranch == myBranchId.trim()) {
        return true;
      }
      return false;
    }
    // 요구사항: 본인/본인 사업소 관련만 표시. 전사(company) 등은 숨김.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return const Center(
        child: Text(
          '달력에서 일자를 선택해 주세요.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (!loaded) {
      return const Center(child: LoadingWidget(size: 80));
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          '일정을 불러오지 못했습니다.\n$errorMessage',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    final String dayKey = calendarDayKeyString(selectedDay!);
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> forDay = docs
        .where(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              calendarEventTouchesDayKey(d.data(), dayKey) &&
              _isVisibleToMe(d.data()),
        )
        .toList();

    if (forDay.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '등록된 일정이 없습니다.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAddEvent,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('일정 추가하기'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemBuilder: (BuildContext context, int index) {
        if (index == forDay.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            child: OutlinedButton.icon(
              onPressed: onAddEvent,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('일정 추가하기'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          );
        }
        final Map<String, dynamic> data = forDay[index].data();
        final String title = data['title'] as String? ?? '제목 없음';
        final String content = data['content'] as String? ?? '';
        final String scope = data['scope'] as String? ?? 'private';
        final String branchName = data['branchName'] as String? ?? '';
        final String visibility = scope == 'private'
            ? '개인일정'
            : scope == 'branch'
                ? (branchName.isNotEmpty ? '$branchName 일정' : '사업소 일정')
                : '전사일정';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            content.trim().isEmpty ? visibility : '$visibility\n$content',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: forDay.length + 1,
    );
  }
}
