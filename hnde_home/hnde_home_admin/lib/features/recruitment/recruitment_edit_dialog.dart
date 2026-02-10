import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/file_upload_service.dart';
import '../../models/recruitment.dart';

class JobOpeningEditDialog extends StatefulWidget {
  final JobOpening? initialJob;
  final Future<void> Function(JobOpening) onSave;

  const JobOpeningEditDialog({
    super.key,
    this.initialJob,
    required this.onSave,
  });

  @override
  State<JobOpeningEditDialog> createState() => _JobOpeningEditDialogState();
}

class _JobOpeningEditDialogState extends State<JobOpeningEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialJob != null) {
      _titleController.text = widget.initialJob!.title;
      _departmentController.text = widget.initialJob!.department;
      _locationController.text = widget.initialJob!.location;
      _deadline = widget.initialJob!.deadline;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _departmentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final job = JobOpening(
        id: widget.initialJob?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        department: _departmentController.text.trim(),
        location: _locationController.text.trim(),
        deadline: _deadline,
      );
      await widget.onSave(job);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialJob == null ? '채용공고 추가' : '채용공고 수정'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '제목 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? '제목을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: '부서 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? '부서를 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '근무지 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? '근무지를 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '마감일 *',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    '${_deadline.year}-${_deadline.month.toString().padLeft(2, '0')}-${_deadline.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}

class RecruitmentSectionEditDialog extends StatefulWidget {
  final String title;
  final RecruitmentSection initialSection;
  final Future<void> Function(RecruitmentSection) onSave;

  const RecruitmentSectionEditDialog({
    super.key,
    required this.title,
    required this.initialSection,
    required this.onSave,
  });

  @override
  State<RecruitmentSectionEditDialog> createState() =>
      _RecruitmentSectionEditDialogState();
}

class _RecruitmentSectionEditDialogState
    extends State<RecruitmentSectionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String? _imageUrl;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _contentController.text = widget.initialSection.content ?? '';
    _imageUrl = widget.initialSection.imageUrl;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _imageUrl = uploadService.getViewUrl(result['view_url']);
        });
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final section = RecruitmentSection(
        title: widget.title,
        imageUrl: _imageUrl,
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
      );
      await widget.onSave(section);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.title} 수정'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _isUploading ? null : _pickImage,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _isUploading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _imageUrl != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _imageUrl!,
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white),
                                      onPressed: () {
                                        setState(() => _imageUrl = null);
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, size: 48),
                                    SizedBox(height: 8),
                                    Text('이미지 선택 (선택사항)'),
                                  ],
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: '내용 (선택사항)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 10,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}

