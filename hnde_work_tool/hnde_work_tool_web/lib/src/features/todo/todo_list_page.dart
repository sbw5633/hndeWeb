import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../models/todo_item_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../utils/app_date_key.dart';
import 'widgets/todo_task_row.dart';
import '../common/enterprise_scaffold.dart';
import '../common/message_alert.dart';
import '../common/loading_widget.dart';
import '../calendar/calendar_day_keys.dart';

const Color _navy = Color(0xFF1E3A8A);

const double _kTodoWideBreakpoint = 920;

/// [PageView] 기준일(가운데 열)과 동일한 날짜만 사용.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// PageView 인덱스 ↔ 날짜 (로컬 자정 기준)
final DateTime _kTodoPageEpoch = DateTime(2020, 1, 1);

int _dayPageIndex(DateTime d) => _dateOnly(d).difference(_kTodoPageEpoch).inDays;

DateTime _dayAtPageIndex(int index) =>
    _kTodoPageEpoch.add(Duration(days: index));

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 이전·당일·다음 일을 한 화면에 두고 좌우 스와이프로 기준일 이동
class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  late final WorkFirestoreRepository _repo;
  late final PageController _pageController;

  /// PageView 가운데 열에 해당하는 날짜
  DateTime _centerDate = _dateOnly(DateTime.now());
  TodoItemModel? _selectedTodo;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    _pageController = PageController(
      initialPage: _dayPageIndex(_centerDate),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToDate(DateTime d, {bool animate = true}) {
    final DateTime day = _dateOnly(d);
    final int page = _dayPageIndex(day);
    if (animate) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(page);
    }
    setState(() {
      _centerDate = day;
      _selectedTodo = null;
    });
  }

  void _onPageChanged(int page) {
    final DateTime next = _dayAtPageIndex(page);
    if (!_sameDate(next, _centerDate)) {
      setState(() {
        _centerDate = next;
        _selectedTodo = null;
      });
    }
  }

  void _selectTodo(TodoItemModel? item) {
    setState(() {
      if (item != null && _selectedTodo?.id == item.id) {
        _selectedTodo = null;
      } else {
        _selectedTodo = item;
      }
    });
  }

  Future<void> _editDetailIfNeeded(BuildContext context) async {
    final TodoItemModel? cur = _selectedTodo;
    if (cur == null || cur.id.isEmpty) {
      return;
    }
    final TextEditingController c = TextEditingController(text: cur.detail);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('세부 내용 수정'),
          content: TextField(
            controller: c,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '세부 내용',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    final TodoItemModel next = cur.copyWith(detail: c.text.trim());
    try {
      await _repo.upsertTodo(next);
      setState(() => _selectedTodo = next);
    } catch (e) {
      if (context.mounted) {
        showMessageAlert(context, message: '저장 실패: $e', title: '저장 실패');
      }
    }
  }

  Future<void> _addTodo(BuildContext context) async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController detailCtrl = TextEditingController();
    final TextEditingController timeCtrl =
        TextEditingController(text: '14:00');
    String type = 'custom';

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setSt) {
            final bool isCalendar = type == TodoTypes.calendar;
            return AlertDialog(
              title: const Text('새 작업'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'custom',
                          child: Text('일반'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'calendar',
                          child: Text('캘린더 연동'),
                        ),
                      ],
                      onChanged: (String? v) =>
                          setSt(() => type = v ?? 'custom'),
                      decoration: const InputDecoration(labelText: '유형'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      maxLength: 30,
                      inputFormatters: <TextInputFormatter>[
                        LengthLimitingTextInputFormatter(30),
                      ],
                      decoration: InputDecoration(
                        labelText: isCalendar ? '일정명 (최대 30자)' : '제목 (최대 30자)',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailCtrl,
                      maxLines: 5,
                      maxLength: 400,
                      inputFormatters: <TextInputFormatter>[
                        LengthLimitingTextInputFormatter(400),
                      ],
                      decoration: InputDecoration(
                        labelText: isCalendar ? '내용 (최대 400자)' : '세부 내용 (최대 400자)',
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '시간',
                        hintText: 'HH:mm',
                        suffixIcon: Icon(Icons.access_time_rounded),
                      ),
                      onTap: () async {
                        final TimeOfDay initial = () {
                          final List<String> p = timeCtrl.text.trim().split(':');
                          final int h = p.isNotEmpty ? int.tryParse(p[0]) ?? 14 : 14;
                          final int m = p.length >= 2 ? int.tryParse(p[1]) ?? 0 : 0;
                          return TimeOfDay(
                            hour: h.clamp(0, 23),
                            minute: m.clamp(0, 59),
                          );
                        }();
                        final TimeOfDay? picked = await showTimePicker(
                          context: ctx,
                          initialTime: initial,
                        );
                        if (picked != null) {
                          final String hh = picked.hour.toString().padLeft(2, '0');
                          final String mm = picked.minute.toString().padLeft(2, '0');
                          setSt(() => timeCtrl.text = '$hh:$mm');
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !context.mounted) {
      return;
    }
    if (titleCtrl.text.trim().isEmpty) return;

    final String dayKey = appDateKeyFromDateTime(_centerDate);
    try {
      // 캘린더 연동이면: 동일 내용으로 calendar_events 문서도 생성하고, 그 id를 투두에 링크
      String? linkedCalendarEventId;
      if (type == TodoTypes.calendar) {
        final List<String> p = timeCtrl.text.trim().split(':');
        final int hh = p.isNotEmpty ? int.tryParse(p[0]) ?? 14 : 14;
        final int mm = p.length >= 2 ? int.tryParse(p[1]) ?? 0 : 0;
        final DateTime start = DateTime(
          _centerDate.year,
          _centerDate.month,
          _centerDate.day,
          hh.clamp(0, 23),
          mm.clamp(0, 59),
        );
        final DateTime end = start.add(const Duration(hours: 1));
        final List<String> dayKeys = <String>[calendarDayKeyString(start)];

        final String? uid = FirebaseAuth.instance.currentUser?.uid;
        final DocumentReference<Map<String, dynamic>> ref =
            await FirestorePaths.calendarEventsCol().add(<String, dynamic>{
          'title': titleCtrl.text.trim(),
          'start': Timestamp.fromDate(start),
          'end': Timestamp.fromDate(end),
          'dayKeys': dayKeys,
          'content': detailCtrl.text.trim(),
          // 캘린더 모달 기본과 동일하게 private부터 시작 (필요 시 UI로 확장)
          'scope': 'private',
          if (uid != null && uid.trim().isNotEmpty) 'createdByUid': uid.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        linkedCalendarEventId = ref.id;
        await _repo.notifyCalendarEventCreated(
          eventId: ref.id,
          scope: 'private',
          titleText: titleCtrl.text.trim(),
        );
      }

      final TodoItemModel draft = TodoItemModel(
        id: '',
        title: titleCtrl.text.trim(),
        dateKeys: <String>[dayKey],
        timeStr: timeCtrl.text.trim(),
        type: type,
        linkedCalendarEventId: linkedCalendarEventId,
        detail: detailCtrl.text.trim(),
      );
      await _repo.upsertTodo(draft);
    } catch (e) {
      if (context.mounted) {
        showMessageAlert(context, message: '저장 실패: $e', title: '저장 실패');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: '해야할 일',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DateHeaderBar(
            centerDate: _centerDate,
            onJumpToDate: _jumpToDate,
            onPickCalendar: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _centerDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                _jumpToDate(picked, animate: true);
              }
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints c) {
                        final bool wide = c.maxWidth >= _kTodoWideBreakpoint;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _TaskGridHeader(
                              wide: wide,
                              onTapPreviousDay: wide
                                  ? () => _jumpToDate(
                                        _centerDate.subtract(
                                          const Duration(days: 1),
                                        ),
                                      )
                                  : null,
                              onTapNextDay: wide
                                  ? () => _jumpToDate(
                                        _centerDate.add(
                                          const Duration(days: 1),
                                        ),
                                      )
                                  : null,
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                onPageChanged: _onPageChanged,
                                itemBuilder: (BuildContext context, int page) {
                                  final DateTime center = _dayAtPageIndex(page);

                                  Future<void> onToggle(
                                      TodoItemModel it, bool v) async {
                                    await _repo.setTodoCompleted(it.id, v);
                                    if (_selectedTodo?.id == it.id) {
                                      setState(
                                        () => _selectedTodo =
                                            it.copyWith(completed: v),
                                      );
                                    }
                                  }

                                  Future<void> onDelete(TodoItemModel it) async {
                                    await _repo.deleteTodo(it.id);
                                    if (_selectedTodo?.id == it.id) {
                                      setState(() => _selectedTodo = null);
                                    }
                                  }

                                  final EdgeInsets pad = wide
                                      ? const EdgeInsets.fromLTRB(6, 4, 6, 0)
                                      : const EdgeInsets.fromLTRB(10, 6, 10, 0);

                                  if (!wide) {
                                    return Padding(
                                      padding: pad,
                                      child: _DayTodosColumn(
                                        key: ValueKey<String>(
                                          'todo-${appDateKeyFromDateTime(center)}',
                                        ),
                                        repo: _repo,
                                        day: center,
                                        muted: false,
                                        selected: _selectedTodo,
                                        onSelect: _selectTodo,
                                        onToggle: onToggle,
                                        onDelete: onDelete,
                                        onAddTodo: () => _addTodo(context),
                                      ),
                                    );
                                  }

                                  Widget col(
                                    Widget inner, {
                                    required VoidCallback? onTapNavigate,
                                  }) {
                                    if (onTapNavigate == null) {
                                      return inner;
                                    }
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: onTapNavigate,
                                        child: inner,
                                      ),
                                    );
                                  }

                                  return Padding(
                                    padding: pad,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        Expanded(
                                          child: col(
                                            _DayTodosColumn(
                                              key: ValueKey<String>(
                                                'todo-${appDateKeyFromDateTime(center.subtract(const Duration(days: 1)))}',
                                              ),
                                              repo: _repo,
                                              day: center.subtract(
                                                const Duration(days: 1),
                                              ),
                                              muted: true,
                                              selected: _selectedTodo,
                                              onSelect: _selectTodo,
                                              onToggle: onToggle,
                                              onDelete: onDelete,
                                              onAddTodo: null,
                                            ),
                                            onTapNavigate: () => _jumpToDate(
                                              center.subtract(
                                                const Duration(days: 1),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const VerticalDivider(width: 1),
                                        Expanded(
                                          child: _DayTodosColumn(
                                            key: ValueKey<String>(
                                              'todo-${appDateKeyFromDateTime(center)}',
                                            ),
                                            repo: _repo,
                                            day: center,
                                            muted: false,
                                            selected: _selectedTodo,
                                            onSelect: _selectTodo,
                                            onToggle: onToggle,
                                            onDelete: onDelete,
                                            onAddTodo: () => _addTodo(context),
                                          ),
                                        ),
                                        const VerticalDivider(width: 1),
                                        Expanded(
                                          child: col(
                                            _DayTodosColumn(
                                              key: ValueKey<String>(
                                                'todo-${appDateKeyFromDateTime(center.add(const Duration(days: 1)))}',
                                              ),
                                              repo: _repo,
                                              day: center.add(
                                                const Duration(days: 1),
                                              ),
                                              muted: true,
                                              selected: _selectedTodo,
                                              onSelect: _selectTodo,
                                              onToggle: onToggle,
                                              onDelete: onDelete,
                                              onAddTodo: null,
                                            ),
                                            onTapNavigate: () => _jumpToDate(
                                              center.add(
                                                const Duration(days: 1),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: 2,
            child: _TodoDetailPanel(
              item: _selectedTodo,
              onEditDetail: () => _editDetailIfNeeded(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTodosColumn extends StatefulWidget {
  const _DayTodosColumn({
    super.key,
    required this.repo,
    required this.day,
    required this.muted,
    required this.selected,
    required this.onSelect,
    required this.onToggle,
    required this.onDelete,
    required this.onAddTodo,
  });

  final WorkFirestoreRepository repo;
  final DateTime day;
  final bool muted;
  final TodoItemModel? selected;
  final void Function(TodoItemModel?) onSelect;
  final Future<void> Function(TodoItemModel it, bool v) onToggle;
  final Future<void> Function(TodoItemModel it) onDelete;
  final VoidCallback? onAddTodo;

  @override
  State<_DayTodosColumn> createState() => _DayTodosColumnState();
}

class _DayTodosColumnState extends State<_DayTodosColumn> {
  late Stream<List<TodoItemModel>> _todosForDay;

  @override
  void initState() {
    super.initState();
    _todosForDay =
        widget.repo.watchTodosForDate(appDateKeyFromDateTime(widget.day));
  }

  @override
  void didUpdateWidget(covariant _DayTodosColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextKey = appDateKeyFromDateTime(widget.day);
    final String prevKey = appDateKeyFromDateTime(oldWidget.day);
    if (nextKey != prevKey || !identical(oldWidget.repo, widget.repo)) {
      _todosForDay = widget.repo.watchTodosForDate(nextKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.muted
        ? const Color(0xFFF8FAFC)
        : Colors.white.withOpacity(0.98);

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            child: Text(
              DateFormat.MMMEd('ko_KR').format(widget.day),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.muted ? 12 : 13,
                fontWeight: FontWeight.w900,
                color: widget.muted ? Colors.grey.shade500 : _navy,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TodoItemModel>>(
              stream: _todosForDay,
              builder: (
                BuildContext context,
                AsyncSnapshot<List<TodoItemModel>> snap,
              ) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '오류: ${snap.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: LoadingWidget(size: 48));
                }
                final List<TodoItemModel> list =
                    snap.data ?? <TodoItemModel>[];
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                  itemCount:
                      list.length + (widget.onAddTodo != null ? 1 : 0),
                  itemBuilder: (BuildContext context, int i) {
                    if (widget.onAddTodo != null && i == list.length) {
                      return _CreateTaskButton(onPressed: widget.onAddTodo!);
                    }
                    final TodoItemModel it = list[i];
                    return TodoTaskRow(
                      item: it,
                      selected: widget.selected?.id == it.id,
                      onTap: () => widget.onSelect(it),
                      onToggle: (bool v) => widget.onToggle(it, v),
                      onDelete: () => widget.onDelete(it),
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

class _TodoDetailPanel extends StatelessWidget {
  const _TodoDetailPanel({
    required this.item,
    required this.onEditDetail,
  });

  final TodoItemModel? item;
  final VoidCallback onEditDetail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.notes_rounded, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  '세부 내용',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                if (item != null && item!.id.isNotEmpty) ...<Widget>[
                  TextButton.icon(
                    onPressed: onEditDetail,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('수정'),
                  ),
                ],
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: item == null
                  ? Center(
                      child: Text(
                        '목록에서 작업을 선택하면\n세부 내용이 여기에 표시됩니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : Builder(
                      builder: (BuildContext context) {
                        final TodoItemModel sel = item!;
                        final String body = sel.detail.trim();
                        return SingleChildScrollView(
                          child: SelectableText(
                            body.isEmpty
                                ? '(등록된 세부 내용이 없습니다)'
                                : sel.detail,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: body.isEmpty
                                  ? Colors.grey.shade400
                                  : const Color(0xFF334155),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeaderBar extends StatelessWidget {
  _DateHeaderBar({
    required this.centerDate,
    required this.onJumpToDate,
    required this.onPickCalendar,
  });

  final DateTime centerDate;
  final void Function(DateTime d) onJumpToDate;
  final VoidCallback onPickCalendar;

  @override
  Widget build(BuildContext context) {
    final DateTime today = _dateOnly(DateTime.now());
    final DateTime y = today.subtract(const Duration(days: 1));
    final DateTime t = today;
    final DateTime tm = today.add(const Duration(days: 1));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _DayChip(
                    label: '어제',
                    selected: _sameDate(centerDate, y),
                    onTap: () => onJumpToDate(y),
                  ),
                  _DayChip(
                    label: '오늘',
                    selected: _sameDate(centerDate, t),
                    onTap: () => onJumpToDate(t),
                  ),
                  _DayChip(
                    label: '내일',
                    selected: _sameDate(centerDate, tm),
                    onTap: () => onJumpToDate(tm),
                  ),
                ],
              ),
            ),
            Material(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onPickCalendar,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _navy.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: _navy, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat.yMMMEd('ko_KR').format(centerDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _navy : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: selected ? Colors.white : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskGridHeader extends StatelessWidget {
  const _TaskGridHeader({
    required this.wide,
    this.onTapPreviousDay,
    this.onTapNextDay,
  });

  final bool wide;
  final VoidCallback? onTapPreviousDay;
  final VoidCallback? onTapNextDay;

  Widget _wideDaySegment({
    required String label,
    required VoidCallback? onTap,
    required bool emphasize,
  }) {
    final TextStyle style = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      color: emphasize ? _navy : const Color(0xFF94A3B8),
      letterSpacing: -0.3,
    );
    if (onTap == null) {
      return Center(child: Text(label, style: style));
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(child: Text(label, style: style)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC).withOpacity(0.95),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(14),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _navy.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.check_box_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: wide &&
                    onTapPreviousDay != null &&
                    onTapNextDay != null
                ? Row(
                    children: <Widget>[
                      Expanded(
                        child: _wideDaySegment(
                          label: '이전',
                          onTap: onTapPreviousDay,
                          emphasize: true,
                        ),
                      ),
                      Text(
                        '·',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Expanded(
                        child: _wideDaySegment(
                          label: '당일',
                          onTap: null,
                          emphasize: true,
                        ),
                      ),
                      Text(
                        '·',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Expanded(
                        child: _wideDaySegment(
                          label: '다음',
                          onTap: onTapNextDay,
                          emphasize: true,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '이전 · 당일 · 다음 일정',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _navy,
                      letterSpacing: -0.3,
                    ),
                  ),
          ),
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              // 안내 문구 제거 (웹에서는 마우스 드래그 스와이프 체감이 약함)
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateTaskButton extends StatelessWidget {
  const _CreateTaskButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add_circle_outline_rounded,
                    size: 26, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  '새 작업 추가',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

