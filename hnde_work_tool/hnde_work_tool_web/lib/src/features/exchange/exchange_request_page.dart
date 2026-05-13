import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/branch_group_model.dart';
import '../../models/branch_model.dart';
import '../../models/submission_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../services/r2_storage_service.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import '../common/message_alert.dart';

class ExchangeRequestPage extends StatefulWidget {
  const ExchangeRequestPage({super.key});

  @override
  State<ExchangeRequestPage> createState() => _ExchangeRequestPageState();
}

class _ExchangeRequestPageState extends State<ExchangeRequestPage> {
  late final WorkFirestoreRepository _repo;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  String _urgency = 'general';
  DateTime? _dueDate;
  bool _branchesExpanded = true;
  bool _selectAll = false;
  final Set<String> _selectedGroupKeys = <String>{};
  final Set<String> _selectedBranchIds = <String>{};
  PlatformFile? _cachedTemplateFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Widget _branchCheckbox(BranchModel b) {
    return CheckboxListTile(
      title: Text(b.name),
      value: _selectAll || _selectedBranchIds.contains(b.id),
      onChanged: _selectAll
          ? null
          : (bool? v) {
              setState(() {
                if (v == true) {
                  _selectedBranchIds.add(b.id);
                } else {
                  _selectedBranchIds.remove(b.id);
                }
              });
            },
    );
  }

  Widget _groupCheckbox(BranchGroupModel g) {
    return CheckboxListTile(
      title: Text(g.label),
      value: _selectAll || _selectedGroupKeys.contains(g.key),
      onChanged: _selectAll
          ? null
          : (bool? v) {
              setState(() {
                if (v == true) {
                  _selectedGroupKeys.add(g.key);
                  _selectedBranchIds.addAll(g.branchNames);
                } else {
                  _selectedGroupKeys.remove(g.key);
                  _selectedBranchIds.removeWhere(g.branchNames.contains);
                }
              });
            },
    );
  }

  List<String> _resolveTargetBranchIds(
    List<BranchModel> branches,
    List<BranchGroupModel> groups,
  ) {
    if (_selectAll) {
      return branches.map((BranchModel b) => b.id).toList();
    }
    final Set<String> ids = <String>{};
    for (final BranchGroupModel g in groups) {
      if (_selectedGroupKeys.contains(g.key)) {
        ids.addAll(g.branchNames);
      }
    }
    ids.addAll(_selectedBranchIds);
    return ids.toList();
  }

  Future<void> _pickTemplate() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _cachedTemplateFile = result.files.first);
  }

  Future<void> _submit(
    List<BranchModel> branches,
    List<BranchGroupModel> groups,
  ) async {
    if (_titleCtrl.text.trim().isEmpty) {
      showMessageAlert(context, message: '제목을 입력하세요.');
      return;
    }

    final List<String> targetIds =
        _resolveTargetBranchIds(branches, groups);
    if (targetIds.isEmpty) {
      showMessageAlert(context, message: '대상 사업소를 선택하세요.');
      return;
    }

    setState(() => _saving = true);
    try {
      R2UploadResult? templateUpload;
      if (_cachedTemplateFile != null) {
        templateUpload = await _repo.uploadTemplateToR2(
          _cachedTemplateFile!,
          r2RegistrySource: '자료송수신',
          r2RegistrySourcePath:
              '자료송수신 > ${_titleCtrl.text.trim()} (양식)',
        );
      }

      final SubmissionModel draft = SubmissionModel(
        id: '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        urgency: _urgency,
        dueDate: _dueDate == null
            ? null
            : Timestamp.fromDate(_dueDate!),
        departmentLabel: '자료 요청',
      );

      final String id = await _repo.createSubmissionWithSites(
        draft,
        targetBranchIds: targetIds,
        templateFileName: _cachedTemplateFile?.name,
        templateFileUrl: templateUpload?.fileUrl,
        templateR2Key: templateUpload?.fileKey,
      );

      if (mounted) {
        context.go('/exchange/$id');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessageAlert(context, message: '저장 실패: $e', title: '저장 실패');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: '자료송수신',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextButton.icon(
            onPressed: () => context.go('/exchange'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('목록으로'),
          ),
          const SizedBox(height: 16),
          const Text(
            '자료 요청 작성',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<
                (List<BranchModel> branches, List<BranchGroupModel> groups)>(
              stream: _repo.watchBranchesAndGroups(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                    (List<BranchModel> branches, List<BranchGroupModel> groups)>
                    snap,
              ) {
                if (!snap.hasData) {
                  return const Center(child: LoadingWidget(size: 60));
                }
                final List<BranchModel> branches = snap.data!.$1;
                final List<BranchGroupModel> groups = snap.data!.$2;

                final List<String> selectedIds =
                    _resolveTargetBranchIds(branches, groups);

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: '제목',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: '설명',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _urgency,
                        decoration: const InputDecoration(
                          labelText: '긴급도',
                          border: OutlineInputBorder(),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'general',
                            child: Text('일반'),
                          ),
                          DropdownMenuItem(
                            value: 'urgent',
                            child: Text('긴급'),
                          ),
                        ],
                        onChanged: (String? v) =>
                            setState(() => _urgency = v ?? 'general'),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('마감일'),
                        subtitle: Text(
                          _dueDate == null
                              ? '미정'
                              : DateFormat('yyyy-MM-dd').format(_dueDate!),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _dueDate ?? DateTime.now().add(const Duration(days: 14)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() => _dueDate = picked);
                            }
                          },
                          child: const Text('날짜 선택'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '양식 파일',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _saving ? null : _pickTemplate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.upload_file,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _cachedTemplateFile?.name ??
                                      '양식 파일을 선택하세요 (선택사항)',
                                  style: TextStyle(
                                    color: _cachedTemplateFile != null
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              if (_cachedTemplateFile != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => setState(() {
                                    _cachedTemplateFile = null;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '대상 사업소',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => setState(
                          () => _branchesExpanded = !_branchesExpanded,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                _branchesExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _branchesExpanded
                                    ? '대상 사업소 선택'
                                    : '선택된 사업소: ${selectedIds.length}개',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_branchesExpanded) ...[
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          title: const Text('전체'),
                          value: _selectAll,
                          onChanged: (bool? v) {
                            setState(() {
                              _selectAll = v ?? false;
                              if (!_selectAll) {
                                _selectedGroupKeys.clear();
                                _selectedBranchIds.clear();
                              }
                            });
                          },
                        ),
                        ...groups.map(
                          (BranchGroupModel g) => _groupCheckbox(g),
                        ),
                        const Divider(height: 24),
                        const Text(
                          '개별 사업소',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...branches.map(
                          (BranchModel b) => _branchCheckbox(b),
                        ),
                      ],
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: _saving
                            ? null
                            : () => _submit(branches, groups),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('요청 생성'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
