import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/content_provider.dart';
import '../../core/file_upload_service.dart';
import '../../models/ci_info.dart';

class CIPage extends ConsumerStatefulWidget {
  const CIPage({super.key});

  @override
  ConsumerState<CIPage> createState() => _CIPageState();
}

class _CIPageState extends ConsumerState<CIPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _meaningController = TextEditingController();
  final _definitionContentController = TextEditingController();
  CIDefinitionType _definitionType = CIDefinitionType.text;
  String? _definitionImageUrl;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _meaningController.dispose();
    _definitionContentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final asyncValue = ref.read(ciInfoProvider);
    asyncValue.whenData((ciInfo) {
      if (ciInfo != null) {
        _titleController.text = ciInfo.title;
        _meaningController.text = ciInfo.meaning.content;
        _definitionType = ciInfo.definition.type;
        _definitionImageUrl = ciInfo.definition.imageUrl;
        _definitionContentController.text = ciInfo.definition.content ?? '';
        setState(() {});
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _definitionImageUrl = uploadService.getViewUrl(result['view_url']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final ciInfo = CIInfo(
        id: 'main',
        title: _titleController.text.trim(),
        meaning: CIMeaning(
          id: 'meaning',
          content: _meaningController.text.trim(),
        ),
        definition: CIDefinition(
          id: 'definition',
          type: _definitionType,
          imageUrl: _definitionType == CIDefinitionType.image
              ? _definitionImageUrl
              : null,
          content: _definitionType == CIDefinitionType.text
              ? _definitionContentController.text.trim()
              : null,
        ),
      );
      await ref.read(ciInfoControllerProvider).save(ciInfo);
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCI = ref.watch(ciInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CI 소개 관리')),
      body: asyncCI.when(
        data: (ciInfo) {
          if (ciInfo != null && _titleController.text.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 24),
                  const Text('의미', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _meaningController,
                    decoration: const InputDecoration(
                      labelText: 'CI 의미 *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '의미를 입력하세요' : null,
                  ),
                  const SizedBox(height: 24),
                  const Text('정의', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  SegmentedButton<CIDefinitionType>(
                    segments: const [
                      ButtonSegment(
                          value: CIDefinitionType.text, label: Text('텍스트')),
                      ButtonSegment(
                          value: CIDefinitionType.image, label: Text('이미지')),
                    ],
                    selected: {_definitionType},
                    onSelectionChanged: (Set<CIDefinitionType> selection) {
                      setState(() {
                        _definitionType = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_definitionType == CIDefinitionType.image) ...[
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _definitionImageUrl != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _definitionImageUrl!,
                                      width: double.infinity,
                                      height: 200,
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
                                        setState(
                                            () => _definitionImageUrl = null);
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
                                    Text('이미지 선택'),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _definitionContentController,
                      decoration: const InputDecoration(
                        labelText: '정의 내용 *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 10,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '정의 내용을 입력하세요' : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('저장'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류: $err')),
      ),
    );
  }
}

