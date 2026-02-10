import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/company_provider.dart';
import '../../core/file_upload_service.dart';
import '../../models/vision_content.dart';

class VisionPage extends ConsumerStatefulWidget {
  const VisionPage({super.key});

  @override
  ConsumerState<VisionPage> createState() => _VisionPageState();
}

class _VisionPageState extends ConsumerState<VisionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _imageUrl;
  String? _imageFit = 'cover';
  bool _isLoading = false;
  bool _isDataLoaded = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _loadData(VisionContent? vision) {
    if (vision != null) {
      _titleController.text = vision.title ?? '';
      _contentController.text = vision.content ?? '';
      _imageUrl = vision.imageUrl;
      _imageFit = vision.imageFit ?? 'cover';
      _isDataLoaded = true;
      setState(() {});
    }
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
          _imageUrl = uploadService.getViewUrl(result['view_url']);
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
    setState(() => _isLoading = true);
    try {
      final vision = VisionContent(
        id: 'main',
        imageUrl: _imageUrl,
        imageFit: _imageFit,
        title: _titleController.text.trim().isEmpty 
            ? null 
            : _titleController.text.trim(),
        content: _contentController.text.trim().isEmpty 
            ? null 
            : _contentController.text.trim(),
      );
      await ref.read(visionControllerProvider).save(vision);
      // 저장 후 provider가 갱신되면 데이터 다시 로드
      // 약간의 지연을 두어 provider 갱신을 기다림
      await Future.delayed(const Duration(milliseconds: 300));
      final updatedVision = await ref.read(visionProvider.future);
      if (updatedVision != null && mounted) {
        _loadData(updatedVision);
      }
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncVision = ref.watch(visionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('경영이념 및 비전 관리')),
      body: asyncVision.when(
        data: (vision) {
          if (vision != null && !_isDataLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadData(vision));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 이미지 업로드
                  Text(
                    '이미지 (선택사항)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
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
                                    height: 200,
                                    fit: _getBoxFit(_imageFit ?? 'cover'),
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.error),
                                    ),
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
                                  Text('이미지 선택'),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 이미지 표시 방식
                  if (_imageUrl != null) ...[
                    Text(
                      '이미지 표시 방식',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _imageFit,
                      decoration: const InputDecoration(
                        labelText: '이미지 표시 방식',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cover',
                          child: Text('Cover (커버)'),
                        ),
                        DropdownMenuItem(
                          value: 'contain',
                          child: Text('Contain (포함)'),
                        ),
                        DropdownMenuItem(
                          value: 'fill',
                          child: Text('Fill (채우기)'),
                        ),
                        DropdownMenuItem(
                          value: 'fitWidth',
                          child: Text('Fit Width (너비 맞춤)'),
                        ),
                        DropdownMenuItem(
                          value: 'fitHeight',
                          child: Text('Fit Height (높이 맞춤)'),
                        ),
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('None (원본 크기)'),
                        ),
                        DropdownMenuItem(
                          value: 'scaleDown',
                          child: Text('Scale Down (축소)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _imageFit = value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  // 제목
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '제목 (선택사항)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 내용
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: '내용 (선택사항)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                  ),
                  const SizedBox(height: 24),
                  // 저장 버튼
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

  BoxFit _getBoxFit(String fit) {
    switch (fit) {
      case 'cover':
        return BoxFit.cover;
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }
}

