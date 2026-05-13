import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/file_upload_service.dart';
import '../../models/business_category.dart';

class CategoryCard extends StatefulWidget {
  final BusinessCategory category;
  final Function(BusinessCategory) onUpdate;
  final VoidCallback? onDelete;
  final bool canEdit;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onUpdate,
    this.onDelete,
    required this.canEdit,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  late TextEditingController _nameController;
  late List<CategoryItem> _items;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _items = List.from(widget.category.items)
      ..sort((a, b) => a.order.compareTo(b.order));
    _nameController.addListener(_updateCategory);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateCategory() {
    widget.onUpdate(BusinessCategory(
      id: widget.category.id,
      name: _nameController.text.trim(),
      items: _items,
      order: widget.category.order,
    ));
  }

  void _addItem() {
    setState(() {
      _items.add(CategoryItem(
        id: const Uuid().v4(),
        imageUrl: null,
        type: null,
        title: null,
        content: null,
        order: _items.length,
      ));
    });
    _updateCategory();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      // 순서 재정렬
      for (int i = 0; i < _items.length; i++) {
        _items[i] = CategoryItem(
          id: _items[i].id,
          imageUrl: _items[i].imageUrl,
          type: _items[i].type,
          title: _items[i].title,
          content: _items[i].content,
          order: i,
        );
      }
    });
    _updateCategory();
  }

  void _updateItem(int index, CategoryItem item) {
    setState(() {
      _items[index] = item;
    });
    _updateCategory();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    enabled: widget.canEdit,
                    decoration: const InputDecoration(
                      labelText: '분류명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (widget.canEdit && widget.onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: widget.onDelete,
                    color: Colors.red,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '항목',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if (widget.canEdit)
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('항목 추가'),
                  ),
              ],
            ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('등록된 항목이 없습니다.'),
                ),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return CategoryItemCard(
                  item: item,
                  onUpdate: (updated) => _updateItem(index, updated),
                  onDelete: widget.canEdit ? () => _removeItem(index) : null,
                  canEdit: widget.canEdit,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class CategoryItemCard extends StatefulWidget {
  final CategoryItem item;
  final Function(CategoryItem) onUpdate;
  final VoidCallback? onDelete;
  final bool canEdit;

  const CategoryItemCard({
    super.key,
    required this.item,
    required this.onUpdate,
    this.onDelete,
    required this.canEdit,
  });

  @override
  State<CategoryItemCard> createState() => _CategoryItemCardState();
}

class _CategoryItemCardState extends State<CategoryItemCard> {
  late TextEditingController _typeController;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _imageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _typeController = TextEditingController(text: widget.item.type ?? '');
    _titleController = TextEditingController(text: widget.item.title ?? '');
    _contentController = TextEditingController(text: widget.item.content ?? '');
    _imageUrl = widget.item.imageUrl;
    _typeController.addListener(_updateItem);
    _titleController.addListener(_updateItem);
    _contentController.addListener(_updateItem);
  }

  @override
  void dispose() {
    _typeController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _updateItem() {
    widget.onUpdate(CategoryItem(
      id: widget.item.id,
      imageUrl: _imageUrl,
      type: _typeController.text.trim().isEmpty ? null : _typeController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      content: _contentController.text.trim().isEmpty ? null : _contentController.text.trim(),
      order: widget.item.order,
    ));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _imageUrl = uploadService.getViewUrl(result['view_url']);
        });
        _updateItem();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌측 이미지
            GestureDetector(
              onTap: widget.canEdit && !_isUploadingImage ? _pickImage : null,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _isUploadingImage
                    ? const Center(child: CircularProgressIndicator())
                    : _imageUrl != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _imageUrl!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.error),
                                ),
                              ),
                              if (widget.canEdit)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                      onPressed: () {
                                        setState(() {
                                          _imageUrl = null;
                                        });
                                        _updateItem();
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 24),
                                SizedBox(height: 4),
                                Text('이미지', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 16),
            // 우측 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 구분
                  TextField(
                    controller: _typeController,
                    enabled: widget.canEdit,
                    decoration: const InputDecoration(
                      labelText: '구분',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 제목
                  TextField(
                    controller: _titleController,
                    enabled: widget.canEdit,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  // 내용
                  TextField(
                    controller: _contentController,
                    enabled: widget.canEdit,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '내용',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.canEdit && widget.onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: widget.onDelete,
                color: Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

