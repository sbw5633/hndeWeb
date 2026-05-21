import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../models/branch_model.dart';
import '../../models/todo_item_model.dart' show TodoItemModel, TodoTypes;
import '../../repositories/work_firestore_repository.dart';
import '../common/loading_widget.dart';
import 'calendar_day_keys.dart';

Future<void> showCalendarScheduleModal(
  BuildContext context, {
  required DateTime baseDate,
  required String branchName,
  bool isMainAdmin = false,
  List<BranchModel> branches = const <BranchModel>[],
  String? editEventId,
  Map<String, dynamic>? existingData,
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
            isMainAdmin: isMainAdmin,
            branches: branches,
            editEventId: editEventId,
            existingData: existingData,
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
    this.isMainAdmin = false,
    this.branches = const <BranchModel>[],
    this.editEventId,
    this.existingData,
  });

  final String branchName;
  final DateTime baseDate;
  final bool isMainAdmin;
  final List<BranchModel> branches;
  final String? editEventId;
  final Map<String, dynamic>? existingData;

  @override
  State<_CalendarScheduleDialog> createState() => _CalendarScheduleDialogState();
}

class _CalendarScheduleDialogState extends State<_CalendarScheduleDialog> {
  late final WorkFirestoreRepository _repo;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  late DateTimeRange _range;

  /// 'private' | 'mine' | 'company' | 'other'
  /// - mine: 본인 사업소
  /// - company: 전사 (mainAdmin 전용)
  /// - other: 다른 사업소 다중 선택 (mainAdmin 전용)
  String _scopeKey = 'private';

  /// scopeKey == 'other' 일 때 선택된 사업소들
  final Set<String> _selectedOtherBranches = <String>{};

  bool _addToTodo = false;
  bool _saving = false;

  bool get _isEdit => widget.editEventId != null;

  static DateTime _dayOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    final Map<String, dynamic>? old = widget.existingData;
    if (old != null) {
      _titleController.text = (old['title'] as String?) ?? '';
      _contentController.text = (old['content'] as String?) ?? '';
      final Timestamp? ts = old['start'] as Timestamp?;
      final Timestamp? te = old['end'] as Timestamp?;
      final DateTime startDt = ts?.toDate() ?? _dayOnly(widget.baseDate);
      final DateTime endDt =
          te?.toDate() ?? startDt.add(const Duration(hours: 1));
      _range = DateTimeRange(start: startDt, end: endDt);

      final String scope = (old['scope'] as String?)?.trim() ?? 'private';
      if (scope == 'private') {
        _scopeKey = 'private';
      } else if (scope == 'company') {
        _scopeKey = 'company';
      } else if (scope == 'branch') {
        final List<String> targets = <String>[];
        final dynamic raw = old['targetBranches'];
        if (raw is List) {
          for (final dynamic e in raw) {
            if (e is String && e.trim().isNotEmpty) targets.add(e.trim());
          }
        }
        final String single =
            (old['branchName'] as String?)?.trim() ?? '';
        if (single.isNotEmpty && !targets.contains(single)) {
          targets.add(single);
        }
        final bool onlyMyBranch =
            targets.length == 1 && targets.first == widget.branchName;
        if (onlyMyBranch) {
          _scopeKey = 'mine';
        } else {
          _scopeKey = 'other';
          _selectedOtherBranches.addAll(targets);
        }
      } else {
        _scopeKey = 'private';
      }
    } else {
      final DateTime base = _dayOnly(widget.baseDate);
      _range = DateTimeRange(
        start: base,
        end: base.add(const Duration(hours: 1)),
      );
    }
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

  /// 현재 _scopeKey로부터 Firestore에 저장할 scope/branchName/targetBranches를 계산.
  Map<String, dynamic> _resolveScopeFields() {
    switch (_scopeKey) {
      case 'private':
        return <String, dynamic>{
          'scope': 'private',
        };
      case 'company':
        return <String, dynamic>{
          'scope': 'company',
        };
      case 'mine':
        return <String, dynamic>{
          'scope': 'branch',
          'branchName': widget.branchName,
          'targetBranches': <String>[widget.branchName],
        };
      case 'other':
        final List<String> list = _selectedOtherBranches.toList()..sort();
        return <String, dynamic>{
          'scope': 'branch',
          // 호환성을 위해 branchName 은 첫 번째 사업소 보존
          if (list.isNotEmpty) 'branchName': list.first,
          'targetBranches': list,
        };
      default:
        return <String, dynamic>{'scope': 'private'};
    }
  }

  String? _validateScope() {
    if (_scopeKey == 'other' && _selectedOtherBranches.isEmpty) {
      return '대상 사업소를 1개 이상 선택하세요.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final String? err = _validateScope();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    setState(() {
      _saving = true;
    });

    try {
      final DateTimeRange range = _range;

      List<String> dayKeys =
          calendarDayKeysTouchingInterval(range.start, range.end);
      if (dayKeys.isEmpty) {
        dayKeys = <String>[calendarDayKeyString(range.start)];
      }

      final Map<String, dynamic> scopeFields = _resolveScopeFields();
      final String resolvedScope = scopeFields['scope'] as String;
      final String savedTitle = _titleController.text.trim().isEmpty
          ? '제목 없음'
          : _titleController.text.trim();

      final String? uid = FirebaseAuth.instance.currentUser?.uid;

      final Map<String, dynamic> payload = <String, dynamic>{
        'title': savedTitle,
        'start': Timestamp.fromDate(range.start),
        'end': Timestamp.fromDate(range.end),
        'dayKeys': dayKeys,
        'content': _contentController.text.trim(),
        ...scopeFields,
      };

      late final String eventId;

      if (_isEdit) {
        eventId = widget.editEventId!;
        await _repo.updateCalendarEvent(eventId, payload);
      } else {
        if (uid != null && uid.trim().isNotEmpty) {
          payload['createdByUid'] = uid.trim();
        }
        payload['createdAt'] = FieldValue.serverTimestamp();
        final DocumentReference<Map<String, dynamic>> ref =
            await FirestorePaths.calendarEventsCol().add(payload);
        eventId = ref.id;

        final List<String> notifyBranches = <String>[];
        if (resolvedScope == 'branch') {
          final dynamic tb = scopeFields['targetBranches'];
          if (tb is List<String>) {
            notifyBranches.addAll(tb);
          }
        }
        await _repo.notifyCalendarEventCreated(
          eventId: eventId,
          scope: resolvedScope,
          titleText: savedTitle,
          branchNames: notifyBranches,
        );

        if (_addToTodo) {
          await _repo.upsertTodo(
            TodoItemModel(
              id: '',
              title: savedTitle,
              dateKeys: dayKeys,
              completed: false,
              type: TodoTypes.calendar,
              linkedCalendarEventId: eventId,
              detail: _contentController.text.trim(),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류: $e')),
        );
      }
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
                Text(
                  _isEdit ? '일정 수정' : '일정 등록',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
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
                if (!_isEdit)
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
                        value: _scopeKey,
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: 'private',
                            child: Text('개인일정'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'mine',
                            child: Text('${widget.branchName} 일정'),
                          ),
                          if (widget.isMainAdmin) ...<DropdownMenuItem<String>>[
                            const DropdownMenuItem<String>(
                              value: 'company',
                              child: Text('전사 일정'),
                            ),
                            const DropdownMenuItem<String>(
                              value: 'other',
                              child: Text('다른 사업소 일정 (선택)'),
                            ),
                          ],
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _scopeKey = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: '공개 범위',
                        ),
                      ),
                    ),
                  ],
                ),
                if (_scopeKey == 'other' && widget.isMainAdmin) ...<Widget>[
                  const SizedBox(height: 12),
                  _OtherBranchesPicker(
                    branches: widget.branches,
                    selected: _selectedOtherBranches,
                    onChanged: (Set<String> next) {
                      setState(() {
                        _selectedOtherBranches
                          ..clear()
                          ..addAll(next);
                      });
                    },
                  ),
                ],
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
                          : Text(_isEdit ? '저장' : '등록'),
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

class _OtherBranchesPicker extends StatelessWidget {
  const _OtherBranchesPicker({
    required this.branches,
    required this.selected,
    required this.onChanged,
  });

  final List<BranchModel> branches;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<BranchModel> sorted = <BranchModel>[...branches]
      ..sort((BranchModel a, BranchModel b) => a.name.compareTo(b.name));
    final bool allSelected =
        sorted.isNotEmpty && sorted.every((BranchModel b) => selected.contains(b.name));

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                '대상 사업소',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  if (allSelected) {
                    onChanged(<String>{});
                  } else {
                    onChanged(
                      sorted.map((BranchModel b) => b.name).toSet(),
                    );
                  }
                },
                child: Text(allSelected ? '전체 해제' : '전체 선택'),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sorted.map((BranchModel b) {
                  final bool checked = selected.contains(b.name);
                  return FilterChip(
                    label: Text(b.name),
                    selected: checked,
                    onSelected: (bool v) {
                      final Set<String> next = <String>{...selected};
                      if (v) {
                        next.add(b.name);
                      } else {
                        next.remove(b.name);
                      }
                      onChanged(next);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

