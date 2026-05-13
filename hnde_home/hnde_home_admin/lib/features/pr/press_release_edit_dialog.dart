import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/file_upload_service.dart';
import '../../models/press_release.dart';

class PressReleaseEditDialog extends StatefulWidget {
  final PressRelease? initialItem;
  final Future<void> Function(PressRelease) onSave;

  const PressReleaseEditDialog({
    super.key,
    this.initialItem,
    required this.onSave,
  });

  @override
  State<PressReleaseEditDialog> createState() => _PressReleaseEditDialogState();
}

class _PressReleaseEditDialogState extends State<PressReleaseEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _authorController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _imageUrl;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _titleController.text = widget.initialItem!.title;
      _contentController.text = widget.initialItem!.content;
      _authorController.text = widget.initialItem!.author ?? '';
      _selectedDate = widget.initialItem!.date;
      _imageUrl = widget.initialItem!.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final item = PressRelease(
        id: widget.initialItem?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        date: _selectedDate,
        imageUrl: _imageUrl,
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
      );
      await widget.onSave(item);
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
      title: Text(widget.initialItem == null ? '보도자료 추가' : '보도자료 수정'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '제목 *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '제목을 입력하세요' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _authorController,
                        decoration: const InputDecoration(
                          labelText: '작성자',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '날짜 *',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: '내용 *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '내용을 입력하세요' : null,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _imageUrl != null
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

