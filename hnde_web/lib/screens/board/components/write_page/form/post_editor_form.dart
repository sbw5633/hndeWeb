import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../../core/select_info_provider.dart';
import '../../../../../core/page_state_provider.dart';
import '../../../../../core/auth_provider.dart';
import '../../../../../models/file_info_model.dart';
import '../../../../../const_value.dart';
import '../widgets/post_branch_selector.dart';
import '../widgets/post_file_upload_section.dart';
import '../widgets/post_form_submit.dart';
import '../widgets/data_request_branch_selector.dart';
import 'package:intl/date_symbol_data_local.dart';

class PostEditorForm extends StatefulWidget {
  final MenuType type;
  final void Function(
      String title,
      String content,
      List<Map<String, String>> images,
      List<Map<String, String>> files,
      String selectedBranch,
      Map<String, dynamic>? extraData) onSubmit;
  final AuthProvider authProvider;
  final SelectInfoProvider selectInfoProvider;
  final String? initialTitle;
  final String? initialContent;
  final List<String>? initialImages;
  final List<String>? initialFiles;
  final void Function(VoidCallback submitForm)? onFormReady;

  const PostEditorForm({
    super.key,
    required this.type,
    required this.onSubmit,
    required this.authProvider,
    required this.selectInfoProvider,
    this.initialTitle,
    this.initialContent,
    this.initialImages,
    this.initialFiles,
    this.onFormReady,
  });

  @override
  State<PostEditorForm> createState() => _PostEditorFormState();
}

class _PostEditorFormState extends State<PostEditorForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<FileInfo> _imageFiles = [];
  List<FileInfo> _documentFiles = [];
  String? _selectedBranch;
  List<String> _selectedBranches = []; // 자료요청용 다중 선택
  DateTime? _deadline; // 자료요청용 제출기한
  PageStateProvider? _pageStateProvider;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageStateProvider = context.read<PageStateProvider>();
        _pageStateProvider?.setEditing(true);
        widget.onFormReady?.call(_submit);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() async {
    Map<String, dynamic> extraData = {};
    if (widget.type == MenuType.dataRequest) {
      extraData['requestType'] = 'dataRequest';
      extraData['selectedBranches'] = _selectedBranches; // 선택된 사업소들 추가
      if (_deadline != null) {
        extraData['deadline'] = _deadline!.toIso8601String(); // 제출기한 추가
      }
    }

    // 자료요청의 경우 선택된 사업소들을 쉼표로 구분된 문자열로 변환
    String branchForSubmit = '';
    if (widget.type == MenuType.dataRequest) {
      branchForSubmit = _selectedBranches.join(',');
    } else {
      branchForSubmit = _selectedBranch ?? '';
    }

    await PostFormSubmit.submitForm(
      context: context,
      formKey: _formKey,
      type: widget.type,
      titleController: _titleController,
      contentController: _contentController,
      imageFiles: _imageFiles,
      documentFiles: _documentFiles,
      selectedBranch: branchForSubmit,
      extraData: extraData,
      onSubmit: widget.onSubmit,
      onSuccess: () => _pageStateProvider?.setUnsavedChanges(false),
    );
  }

  List<Map<String, String>> _getBranchOptions() {
    if (widget.authProvider.isAdmin) {
      return [
        {'id': '전체', 'name': '전체'},
        ...widget.selectInfoProvider.branches.map((b) => {
              'id': b['id']?.toString() ?? '',
              'name': b['name']?.toString() ?? ''
            }),
      ];
    }
    if (widget.authProvider.appUser?.affiliation == '본사') {
      return [
        {'id': '전체', 'name': '전체'},
        {'id': '본사', 'name': '본사'},
      ];
    }
    return [];
  }

  String _getAutoBranch() {
    if (widget.authProvider.isAdmin ||
        widget.authProvider.appUser?.affiliation == '본사') {
      return _selectedBranch ?? '전체';
    }
    return widget.authProvider.appUser?.affiliation ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == MenuType.notice) {
      _selectedBranch = _getAutoBranch();
    }

    final branchOptions = _getBranchOptions();
    final autoBranch = _getAutoBranch();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Form(
          key: _formKey,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사업소 선택기 (공지사항/자료요청)
                  if (widget.type == MenuType.notice ||
                      widget.type == MenuType.dataRequest) ...[
                    widget.type == MenuType.notice
                        ? PostBranchSelector(
                            branchOptions: branchOptions,
                            selectedBranch: _selectedBranch,
                            autoBranch: autoBranch,
                            onBranchChanged: (value) {
                              setState(() => _selectedBranch = value);
                              _pageStateProvider?.setUnsavedChanges(true);
                            },
                            onContentChanged: () =>
                                _pageStateProvider?.setUnsavedChanges(true),
                          )
                        : DataRequestBranchSelector(
                            branchOptions: branchOptions,
                            selectedBranches: _selectedBranches,
                            onBranchesChanged: (branches) {
                              setState(() => _selectedBranches = branches);
                              _pageStateProvider?.setUnsavedChanges(true);
                            },
                            onContentChanged: () =>
                                _pageStateProvider?.setUnsavedChanges(true),
                          ),

                    // 자료요청일 때만 제출기한 선택 필드 표시
                    if (widget.type == MenuType.dataRequest) ...[
                      const SizedBox(height: 24),
                      _buildDeadlineSelector(),
                    ],

                    const SizedBox(height: 24),
                  ],

                  // 제목 입력 필드
                  Row(
                    children: [
                      Icon(
                        Icons.title,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '제목',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    maxLength: 30,
                    decoration: InputDecoration(
                      hintText: '제목을 입력해주세요 (최대 30자)',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      counterText: '${_titleController.text.length}/30',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '제목을 입력하세요.' : null,
                    onChanged: (_) =>
                        _pageStateProvider?.setUnsavedChanges(true),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 24),

                  // 내용 입력 필드
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '내용',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      hintText: '내용을 입력해주세요',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    maxLines: 8,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '내용을 입력하세요.' : null,
                    onChanged: (_) =>
                        _pageStateProvider?.setUnsavedChanges(true),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 24),

                  // 파일 업로드 섹션
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '파일 첨부',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PostFileUploadSection(
                    imageFiles: _imageFiles,
                    documentFiles: _documentFiles,
                    onImageSelected: _handleImageSelected,
                    onDocumentSelected: _handleDocumentSelected,
                    onImageRemoved: (idx) =>
                        setState(() => _imageFiles.removeAt(idx)),
                    onDocumentRemoved: (idx) =>
                        setState(() => _documentFiles.removeAt(idx)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleImageSelected(FileInfo fileInfo) {
    if (_imageFiles.length < 5) {
      final isDuplicate =
          _imageFiles.any((file) => file.displayName == fileInfo.displayName);
      if (!isDuplicate) {
        final newFileInfo = FileInfo(
          fileName: fileInfo.fileName,
          fileExtension: fileInfo.fileExtension,
          bytes: fileInfo.bytes,
          isImage: true,
          originalFile: fileInfo.originalFile,
        );
        setState(() => _imageFiles = [..._imageFiles, newFileInfo]);
      }
    }
  }

  void _handleDocumentSelected(FileInfo fileInfo) {
    if (_documentFiles.length < 5) {
      final isDuplicate = _documentFiles
          .any((file) => file.displayName == fileInfo.displayName);
      if (!isDuplicate) {
        final newFileInfo = FileInfo(
          fileName: fileInfo.fileName,
          fileExtension: fileInfo.fileExtension,
          bytes: fileInfo.bytes,
          isImage: false,
          originalFile: fileInfo.originalFile,
        );
        setState(() => _documentFiles = [..._documentFiles, newFileInfo]);
      }
    }
  }

  /// 제출기한 선택 위젯 (자료요청용)
  Widget _buildDeadlineSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              '제출기한',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제출기한 선택 버튼
              InkWell(
                onTap: () => _selectDeadline(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _deadline != null
                        ? Colors.blue.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _deadline != null
                          ? Colors.blue.shade200
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: _deadline != null
                            ? Colors.blue.shade600
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _deadline != null
                              ? '${_deadline!.year}년 ${_deadline!.month}월 ${_deadline!.day}일 ${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}'
                              : '제출기한을 선택해주세요 (선택사항)',
                          style: TextStyle(
                            fontSize: 14,
                            color: _deadline != null
                                ? Colors.blue.shade800
                                : Colors.grey.shade600,
                            fontWeight: _deadline != null
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_deadline != null) ...[
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _deadline = null;
                            });
                            _pageStateProvider?.setUnsavedChanges(true);
                          },
                          icon: Icon(Icons.clear,
                              color: Colors.grey.shade600, size: 18),
                          tooltip: '기한 제거',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 빠른 선택 버튼들
              if (_deadline == null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickDeadlineButton('3일 후', 3),
                    _buildQuickDeadlineButton('1주일 후', 7),
                    _buildQuickDeadlineButton('2주일 후', 14),
                    _buildQuickDeadlineButton('1개월 후', 30),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 빠른 기한 선택 버튼
  Widget _buildQuickDeadlineButton(String label, int days) {
    return InkWell(
      onTap: () {
        final deadline = DateTime.now().add(Duration(days: days));
        setState(() {
          _deadline = deadline;
        });
        _pageStateProvider?.setUnsavedChanges(true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 제출기한 선택 다이얼로그 (table_calendar 사용)
  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    // 한국어 로케일 초기화
    await initializeDateFormatting('ko_KR', null);

    // 날짜 선택 다이얼로그
    final dateResult = await showDialog<DateTime>(
      context: context,
      builder: (context) => _CustomDatePickerDialog(
        initialDate: _deadline ?? now.add(const Duration(days: 7)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      ),
    );

    if (dateResult != null) {
      selectedDate = dateResult;

      // 시간 선택 다이얼로그
      final timeResult = await showDialog<TimeOfDay>(
        context: context,
        builder: (context) => _CustomTimePickerDialog(
          initialTime: _deadline != null
              ? TimeOfDay.fromDateTime(_deadline!)
              : const TimeOfDay(hour: 18, minute: 0),
        ),
      );

      if (timeResult != null) {
        selectedTime = timeResult;

        final deadline = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        setState(() {
          _deadline = deadline;
        });
        _pageStateProvider?.setUnsavedChanges(true);
      }
    }
  }
}

/// 커스텀 날짜 선택 다이얼로그 (table_calendar 사용)
class _CustomDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _CustomDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_CustomDatePickerDialog> createState() =>
      _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState extends State<_CustomDatePickerDialog> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  DateTime? _hoveredDay; // 이 줄을 추가

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate;
    _focusedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '날짜 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 달력
            TableCalendar<dynamic>(
              firstDay: widget.firstDate,
              lastDay: widget.lastDate,
              focusedDay: _focusedDay,
              locale: 'ko_KR',
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade600,
                ),
                leftChevronIcon:
                    Icon(Icons.chevron_left, color: Colors.blue.shade600),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: Colors.blue.shade600),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
                weekendStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                ),

                weekendTextStyle: TextStyle(
                  color: Colors.red.shade400,
                ),
                disabledTextStyle: TextStyle(
                  color: Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDay),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('선택'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 커스텀 시간 선택 다이얼로그
class _CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const _CustomTimePickerDialog({
    required this.initialTime,
  });

  @override
  State<_CustomTimePickerDialog> createState() =>
      _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<_CustomTimePickerDialog> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '시간 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 시간 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 시간
                Column(
                  children: [
                    Text(
                      '시간',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 40,
                        perspective: 0.005,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedTime = TimeOfDay(
                              hour: index,
                              minute: _selectedTime.minute,
                            );
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 24,
                          builder: (context, index) {
                            final isSelected = index == _selectedTime.hour;
                            return Container(
                              alignment: Alignment.center,
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.blue.shade600
                                      : Colors.black,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 20),
                // 분
                Column(
                  children: [
                    Text(
                      '분',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 40,
                        perspective: 0.005,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedTime = TimeOfDay(
                              hour: _selectedTime.hour,
                              minute: index * 5, // 5분 단위
                            );
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 12, // 0, 5, 10, ..., 55
                          builder: (context, index) {
                            final minute = index * 5;
                            final isSelected = minute == _selectedTime.minute;
                            return Container(
                              alignment: Alignment.center,
                              child: Text(
                                minute.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.blue.shade600
                                      : Colors.black,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 선택된 시간 표시
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '선택된 시간: ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedTime),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('선택'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
