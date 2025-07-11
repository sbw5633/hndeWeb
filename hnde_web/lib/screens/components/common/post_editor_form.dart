import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;

class PostEditorForm extends StatefulWidget {
  final String type; // 'notice' | 'board' | 'dataRequest' 등
  final void Function(String title, String content, List<XFile> images, List<html.File> files) onSubmit;
  final String? initialTitle;
  final String? initialContent;
  final List<XFile>? initialImages;
  final List<html.File>? initialFiles;
  const PostEditorForm({
    super.key,
    required this.type,
    required this.onSubmit,
    this.initialTitle,
    this.initialContent,
    this.initialImages,
    this.initialFiles,
  });

  @override
  State<PostEditorForm> createState() => _PostEditorFormState();
}

class _PostEditorFormState extends State<PostEditorForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<XFile> _images = [];
  List<html.File> _files = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    _images = widget.initialImages ?? [];
    _files = widget.initialFiles ?? [];
  }

  bool _isImageFile(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif');
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked != null && picked.isNotEmpty) {
      final existingHashes = <int>{};
      for (final img in _images) {
        final bytes = await img.readAsBytes();
        existingHashes.add(bytes.hashCode);
      }
      final List<XFile> newImages = [];
      for (final img in picked) {
        final bytes = await img.readAsBytes();
        if (!existingHashes.contains(bytes.hashCode)) {
          newImages.add(img);
          existingHashes.add(bytes.hashCode);
        }
      }
      setState(() {
        _images = (_images + newImages).take(5).toList();
      });
    }
  }

  void _removeImage(int idx) {
    setState(() {
      _images.removeAt(idx);
    });
  }

  void _removeFile(int idx) {
    setState(() {
      _files.removeAt(idx);
    });
  }

  void _pickFiles() {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.multiple = true;
    uploadInput.accept = '';
    uploadInput.onChange.listen((e) {
      final selected = uploadInput.files;
      if (selected != null && selected.isNotEmpty) {
        final existingNames = _files.map((f) => f.name).toSet();
        final newFiles = selected.where((f) => !_isImageFile(f.name) && !existingNames.contains(f.name)).toList();
        setState(() {
          _files = (_files + newFiles).take(5).toList();
        });
      }
    });
    uploadInput.click();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(_titleController.text.trim(), _contentController.text.trim(), _images, _files);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요.' : null,
              onChanged: (_) => setState(() {}),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: '내용'),
              maxLines: 8,
              validator: (v) => (v == null || v.trim().isEmpty) ? '내용을 입력하세요.' : null,
              onChanged: (_) => setState(() {}),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _images.length >= 5 ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text('이미지 첨부 (${_images.length}/5)'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _files.length >= 5 ? null : _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: Text('파일 첨부 (${_files.length}/5)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_images.isNotEmpty)
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, idx) {
                    return _ImageWithTooltip(
                      xfile: _images[idx],
                      onRemove: () => _removeImage(idx),
                    );
                  },
                ),
              ),
            if (_files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('첨부 파일', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._files.asMap().entries.map((entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file, color: Colors.grey),
                          title: Text(entry.value.name, style: const TextStyle(fontSize: 15)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeFile(entry.key),
                          ),
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(widget.type == 'notice' ? '공지사항 등록' : widget.type == 'board' ? '게시글 등록' : '등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageWithTooltip extends StatefulWidget {
  final XFile xfile;
  final VoidCallback onRemove;
  const _ImageWithTooltip({required this.xfile, required this.onRemove});

  @override
  State<_ImageWithTooltip> createState() => _ImageWithTooltipState();
}

class _ImageWithTooltipState extends State<_ImageWithTooltip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          Tooltip(
            message: widget.xfile.name,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<Uint8List>(
                future: widget.xfile.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                    return Stack(
                      children: [
                        Image.memory(
                          snapshot.data!,
                          width: 84,
                          height: 84,
                          fit: BoxFit.contain,
                        ),
                        if (_hovered)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.25),
                              child: Center(
                                child: Text(
                                  widget.xfile.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                  return const SizedBox(
                    width: 84,
                    height: 84,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: widget.onRemove,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 