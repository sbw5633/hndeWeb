import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/history_item.dart';

class HistoryEditDialog extends StatefulWidget {
  final HistoryItem? initialItem;
  final Future<void> Function(HistoryItem) onSave;

  const HistoryEditDialog({
    super.key,
    this.initialItem,
    required this.onSave,
  });

  @override
  State<HistoryEditDialog> createState() => _HistoryEditDialogState();
}

class _HistoryEditDialogState extends State<HistoryEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _yearController.text = widget.initialItem!.year;
      _monthController.text = widget.initialItem!.month ?? '';
      _contentController.text = widget.initialItem!.content;
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final monthText = _monthController.text.trim();
      final item = HistoryItem(
        id: widget.initialItem?.id ?? const Uuid().v4(),
        year: _yearController.text.trim(),
        month: monthText.isEmpty ? null : monthText,
        content: _contentController.text.trim(),
      );
      await widget.onSave(item);
      if (mounted) {
        // 다이얼로그 닫기
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialItem == null ? '연혁 추가' : '연혁 수정'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: '연도 *',
                        border: OutlineInputBorder(),
                        hintText: '예: 2024',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return '연도를 입력하세요';
                        }
                        final year = int.tryParse(v);
                        if (year == null || year < 1900 || year > 2100) {
                          return '올바른 연도를 입력하세요';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _monthController,
                      decoration: const InputDecoration(
                        labelText: '월 (선택)',
                        border: OutlineInputBorder(),
                        hintText: '1-12',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final month = int.tryParse(v);
                          if (month == null || month < 1 || month > 12) {
                            return '1-12 사이의 숫자';
                          }
                        }
                        return null;
                      },
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
                maxLines: 3,
                validator: (v) => (v == null || v.isEmpty) ? '내용을 입력하세요' : null,
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

