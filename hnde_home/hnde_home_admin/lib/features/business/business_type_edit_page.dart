import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/content_provider.dart';
import '../../models/business_type.dart';

class BusinessTypeEditPage extends ConsumerStatefulWidget {
  final BusinessType? businessType;

  const BusinessTypeEditPage({super.key, this.businessType});

  @override
  ConsumerState<BusinessTypeEditPage> createState() =>
      _BusinessTypeEditPageState();
}

class _BusinessTypeEditPageState extends ConsumerState<BusinessTypeEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String _layoutType = 'layout1';
  String? _iconName;
  String? _colorHex;
  int _order = 0;

  @override
  void initState() {
    super.initState();
    if (widget.businessType != null) {
      _nameController = TextEditingController(text: widget.businessType!.name);
      _descriptionController =
          TextEditingController(text: widget.businessType!.description ?? '');
      _layoutType = widget.businessType!.layoutType;
      _iconName = widget.businessType!.iconName;
      _colorHex = widget.businessType!.colorHex;
      _order = widget.businessType!.order;
    } else {
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      // 새로 추가하는 경우 order는 목록 길이로 설정
      ref.read(businessTypeListProvider).whenData((list) {
        _order = list.length;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final businessType = BusinessType(
      id: widget.businessType?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      layoutType: _layoutType,
      order: _order,
      iconName: _iconName,
      colorHex: _colorHex,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    try {
      if (widget.businessType != null) {
        await ref.read(businessTypeControllerProvider).update(businessType);
      } else {
        await ref.read(businessTypeControllerProvider).add(businessType);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.businessType == null ? '사업 추가' : '사업 수정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '사업명',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '사업명을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _layoutType,
              decoration: const InputDecoration(
                labelText: '레이아웃',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'layout1',
                  child: Text('레이아웃 1'),
                ),
                DropdownMenuItem(
                  value: 'layout2',
                  child: Text('레이아웃 2'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _layoutType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _iconName,
              decoration: const InputDecoration(
                labelText: '아이콘 (선택)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('없음')),
                DropdownMenuItem(value: 'restaurant', child: Text('레스토랑')),
                DropdownMenuItem(value: 'factory', child: Text('공장')),
                DropdownMenuItem(value: 'local_dining', child: Text('식음료')),
                DropdownMenuItem(value: 'business', child: Text('사업')),
              ],
              onChanged: (value) {
                setState(() => _iconName = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _colorHex,
              decoration: const InputDecoration(
                labelText: '색상 (선택, 예: #2196F3)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _colorHex = value.trim().isEmpty ? null : value.trim();
              },
            ),
          ],
        ),
      ),
    );
  }
}

