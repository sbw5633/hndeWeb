import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../models/todo_item_model.dart' show TodoItemModel, TodoTypes;
import '../../repositories/work_firestore_repository.dart';
import '../common/loading_widget.dart';
import 'calendar_day_keys.dart';

Future<void> showCalendarScheduleModal(
  BuildContext context, {
  required DateTime baseDate,
  required String branchName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '일정 등록',
    // true면 루트(바깥 MaterialApp) 네비에 붙어 MaterialLocalizations가 없어질 수 있음
    useRootNavigator: false,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<double> scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      final Animation<double> fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );

      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          child: _CalendarScheduleDialog(
            branchName: branchName,
            baseDate: baseDate,
          ),
        ),
      );
    },
  );
}

class _CalendarScheduleDialog extends StatefulWidget {
  const _CalendarScheduleDialog({
    required this.branchName,
    required this.baseDate,
  });

  final String branchName;
  final DateTime baseDate;

  @override
  State<_CalendarScheduleDialog> createState() => _CalendarScheduleDialogState();
}

class _CalendarScheduleDialogState extends State<_CalendarScheduleDialog> {
  late final WorkFirestoreRepository _repo;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  late DateTimeRange _range;
  String _scope = 'private'; // private | branch
  bool _addToTodo = false;
  bool _saving = false;

  static DateTime _dayOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    final DateTime base = _dayOnly(widget.baseDate);
    _range = DateTimeRange(
      start: base,
      end: base.add(const Duration(hours: 1)),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _periodDisplayText() {
    final DateFormat dayFmt = DateFormat('yyyy-MM-dd');
    final DateFormat timeFmt = DateFormat('HH:mm');
    final DateTimeRange r = _range;
    final String ds = dayFmt.format(r.start);
    final String de = dayFmt.format(r.end);
    if (ds == de) {
      return '$ds · ${timeFmt.format(r.start)}–${timeFmt.format(r.end)}';
    }
    return '$ds ~ $de';
  }

  Future<void> _pickRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      useRootNavigator: false,
      locale: const Locale('ko', 'KR'),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
      // 이미 showDialog 라우트 안이므로 여기서는 크기만 제한 (Dialog 중첩 방지)
      builder: (BuildContext context, Widget? child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _range = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
    });

    final DateTimeRange range = _range;

    List<String> dayKeys =
        calendarDayKeysTouchingInterval(range.start, range.end);
    if (dayKeys.isEmpty) {
      dayKeys = <String>[calendarDayKeyString(range.start)];
    }

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final DocumentReference<Map<String, dynamic>> ref =
        await FirestorePaths.calendarEventsCol().add(<String, dynamic>{
      'title': _titleController.text.trim().isEmpty
          ? '제목 없음'
          : _titleController.text.trim(),
      'start': Timestamp.fromDate(range.start),
      'end': Timestamp.fromDate(range.end),
      'dayKeys': dayKeys,
      'content': _contentController.text.trim(),
      'scope': _scope,
      if (_scope == 'branch') 'branchName': widget.branchName,
      if (uid != null && uid.trim().isNotEmpty) 'createdByUid': uid.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final String savedTitle = _titleController.text.trim().isEmpty
        ? '제목 없음'
        : _titleController.text.trim();
    await _repo.notifyCalendarEventCreated(
      eventId: ref.id,
      scope: _scope,
      titleText: savedTitle,
      branchName: widget.branchName,
    );

    if (_addToTodo) {
      final String title = _titleController.text.trim().isEmpty
          ? '제목 없음'
          : _titleController.text.trim();
      await _repo.upsertTodo(
        TodoItemModel(
          id: '',
          title: title,
          dateKeys: dayKeys,
          completed: false,
          type: TodoTypes.calendar,
          linkedCalendarEventId: ref.id,
          detail: _contentController.text.trim(),
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '일정 등록',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '일정명',
                    hintText: '예) 4대보험 취득 점검 회의',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    hintText: '메모/상세 내용을 입력하세요',
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _addToTodo,
                  onChanged: (bool? v) {
                    if (v == null) return;
                    setState(() => _addToTodo = v);
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Todo에도 추가',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    '체크하면 해당 날짜 Todo 리스트에도 같이 등록됩니다.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '일자 · 기간',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(
                        tooltip: '기간 또는 날짜 변경',
                        onPressed: _saving ? null : _pickRange,
                        icon: const Icon(Icons.calendar_month_rounded),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Material(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _saving ? null : _pickRange,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    _periodDisplayText(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.edit_calendar_outlined,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _scope,
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'private',
                            child: Text('개인일정'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'branch',
                            child: Text('${widget.branchName} 일정'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _scope = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: '공개 범위',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: LoadingWidget(size: 16, duration: Duration(milliseconds: 1000)),
                            )
                          : const Text('저장'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

