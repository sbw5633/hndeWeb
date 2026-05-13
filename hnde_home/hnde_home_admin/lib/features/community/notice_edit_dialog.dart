import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/notice.dart';

class NoticeEditDialog extends StatefulWidget {
  final Notice? initialItem;
  final Future<void> Function(Notice) onSave;

  const NoticeEditDialog({
    super.key,
    this.initialItem,
    required this.onSave,
  });

  @override
  State<NoticeEditDialog> createState() => _NoticeEditDialogState();
}

class _NoticeEditDialogState extends State<NoticeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _authorController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isImportant = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _titleController.text = widget.initialItem!.title;
      _contentController.text = widget.initialItem!.content;
      _authorController.text = widget.initialItem!.author ?? '';
      _selectedDate = widget.initialItem!.date;
      _isImportant = widget.initialItem!.isImportant;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final item = Notice(
        id: widget.initialItem?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        date: _selectedDate,
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        isImportant: _isImportant,
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
      title: Text(widget.initialItem == null ? '공지사항 추가' : '공지사항 수정'),
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
                SwitchListTile(
                  title: const Text('중요 공지'),
                  value: _isImportant,
                  onChanged: (value) => setState(() => _isImportant = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: '내용 *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 10,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '내용을 입력하세요' : null,
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

