import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/company_provider.dart';
import '../../core/file_upload_service.dart';
import '../../models/ceo_greeting.dart';
import '../../models/home_page_config.dart';

class CEOGreetingPage extends ConsumerStatefulWidget {
  const CEOGreetingPage({super.key});

  @override
  ConsumerState<CEOGreetingPage> createState() => _CEOGreetingPageState();
}

class _CEOGreetingPageState extends ConsumerState<CEOGreetingPage> {
  String? _imageUrl;
  String _imageFit = 'cover';
  List<TextLineConfig> _textLines = [];
  final Map<int, TextEditingController> _textLineControllers = {};
  bool _isLoading = false;

  TextEditingController _getTextLineController(int index) {
    if (!_textLineControllers.containsKey(index)) {
      final text = index < _textLines.length ? _textLines[index].text : '';
      _textLineControllers[index] = TextEditingController(text: text);
    }
    return _textLineControllers[index]!;
  }

  void _updateTextLine(int index, String text) {
    if (index < _textLines.length) {
      final line = _textLines[index];
      _textLines[index] = TextLineConfig(
        text: text,
        fontSize: line.fontSize,
        color: line.color,
        fontWeight: line.fontWeight,
        textAlign: line.textAlign,
        isDivider: line.isDivider,
        dividerWidth: line.dividerWidth,
      );
    }
  }

  void _removeTextLine(int index) {
    _textLineControllers[index]?.dispose();
    _textLineControllers.remove(index);
    
    final keysToUpdate = _textLineControllers.keys.where((k) => k > index).toList()..sort();
    final tempControllers = <int, TextEditingController>{};
    for (var oldKey in keysToUpdate) {
      final controller = _textLineControllers[oldKey]!;
      tempControllers[oldKey - 1] = controller;
    }
    for (var oldKey in keysToUpdate) {
      _textLineControllers.remove(oldKey);
    }
    _textLineControllers.addAll(tempControllers);
    
    _textLines.removeAt(index);
  }

  void _addTextLine() {
    final newIndex = _textLines.length;
    _textLines.add(TextLineConfig(text: ''));
    _textLineControllers[newIndex] = TextEditingController(text: '');
  }

  @override
  void dispose() {
    for (var controller in _textLineControllers.values) {
      controller.dispose();
    }
    _textLineControllers.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    final asyncValue = ref.read(ceoGreetingProvider);
    asyncValue.whenData((greeting) {
      if (greeting != null) {
        _imageUrl = greeting.imageUrl;
        _imageFit = greeting.imageFit ?? 'cover';
        _textLines = List<TextLineConfig>.from(greeting.textLines);
        if (_textLines.isEmpty && greeting.content != null && greeting.content!.isNotEmpty) {
          // 호환성: 기존 content를 첫 번째 라인으로 변환
          _textLines = [TextLineConfig(text: greeting.content!)];
        }
        // 기존 controller들 dispose
        for (var controller in _textLineControllers.values) {
          controller.dispose();
        }
        _textLineControllers.clear();
        // 새로운 controller들 생성
        for (int i = 0; i < _textLines.length; i++) {
          _textLineControllers[i] = TextEditingController(text: _textLines[i].text);
        }
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

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
      return Color(int.parse(colorString, radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.white;
    }
  }

  FontWeight _getFontWeight(String? weight) {
    switch (weight) {
      case 'normal':
        return FontWeight.normal;
      case 'w300':
        return FontWeight.w300;
      case 'w400':
        return FontWeight.w400;
      case 'w500':
        return FontWeight.w500;
      case 'w600':
        return FontWeight.w600;
      case 'bold':
        return FontWeight.bold;
      case 'w700':
        return FontWeight.w700;
      case 'w800':
        return FontWeight.w800;
      case 'w900':
        return FontWeight.w900;
      default:
        return FontWeight.bold;
    }
  }

  TextAlign _getTextAlign(String? align) {
    switch (align) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final greeting = CEOGreeting(
        id: 'main',
        imageUrl: _imageUrl,
        imageFit: _imageFit,
        textLines: _textLines.where((line) => line.text.isNotEmpty || line.isDivider).toList(),
      );
      await ref.read(ceoGreetingControllerProvider).save(greeting);
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
    final asyncGreeting = ref.watch(ceoGreetingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CEO 인사말 관리')),
      body: asyncGreeting.when(
        data: (greeting) {
          if (greeting != null && _textLines.isEmpty && _imageUrl == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 이미지 업로드
                Text(
                  '이미지',
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
                                  fit: _getBoxFit(_imageFit),
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.error),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
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
                const SizedBox(height: 16),
                // 이미지 fit 선택
                if (_imageUrl != null) ...[
                  Text(
                    '이미지 표시 방식',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _imageFit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cover', child: Text('Cover (영역 채우기)')),
                      DropdownMenuItem(value: 'contain', child: Text('Contain (전체 보이기)')),
                      DropdownMenuItem(value: 'fill', child: Text('Fill (늘리기)')),
                      DropdownMenuItem(value: 'fitWidth', child: Text('Fit Width (너비 맞추기)')),
                      DropdownMenuItem(value: 'fitHeight', child: Text('Fit Height (높이 맞추기)')),
                      DropdownMenuItem(value: 'none', child: Text('None (원본 크기)')),
                      DropdownMenuItem(value: 'scaleDown', child: Text('Scale Down (축소만)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _imageFit = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                // 텍스트 줄 관리
                Text(
                  '텍스트 줄 (최대 5줄)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  _textLines.length > 5 ? 5 : (_textLines.length + 1).clamp(1, 6),
                  (index) {
                    if (index >= _textLines.length) {
                      // 새 줄 추가 버튼
                      if (_textLines.length < 5) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _addTextLine();
                              setState(() {});
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('줄 추가'),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    final line = _textLines[index];
                    final lineController = _getTextLineController(index);

                    return Card(
                      key: ValueKey('text_line_$index'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(
                          line.isDivider
                              ? '줄 ${index + 1}: 구분선'
                              : '줄 ${index + 1}: ${line.text.isEmpty ? "(비어있음)" : line.text}'),
                        subtitle: Text(
                          line.isDivider
                              ? '길이: ${((line.dividerWidth ?? 0.5) * 100).toInt()}%, 색상: ${line.color ?? "기본"}'
                              : '크기: ${line.fontSize?.toInt() ?? 24}px, 색상: ${line.color ?? "기본"}, 정렬: ${line.textAlign ?? "center"}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 텍스트/구분선 선택
                                Text('타입',
                                    style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 8),
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      label: Text('텍스트'),
                                      icon: Icon(Icons.text_fields),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('구분선'),
                                      icon: Icon(Icons.horizontal_rule),
                                    ),
                                  ],
                                  selected: {line.isDivider},
                                  onSelectionChanged: (Set<bool> newSelection) {
                                    final isDivider = newSelection.first;
                                    setState(() {
                                      _textLines[index] = TextLineConfig(
                                        text: line.text,
                                        fontSize: line.fontSize,
                                        color: line.color,
                                        fontWeight: line.fontWeight,
                                        textAlign: line.textAlign,
                                        isDivider: isDivider,
                                        dividerWidth: isDivider ? (line.dividerWidth ?? 0.5) : null,
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                // 텍스트 입력 또는 구분선 설정
                                if (!line.isDivider) ...[
                                  TextFormField(
                                    key: ValueKey('text_field_$index'),
                                    controller: lineController,
                                    decoration: InputDecoration(
                                      labelText: '줄 ${index + 1} 텍스트',
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      _updateTextLine(index, value);
                                      setState(() {});
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // 폰트 크기
                                  Text('폰트 크기',
                                      style: Theme.of(context).textTheme.titleSmall),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Slider(
                                          value: (line.fontSize ?? 24).toDouble(),
                                          min: 12.0,
                                          max: 72.0,
                                          divisions: 30,
                                          label: '${(line.fontSize ?? 24).toInt()}px',
                                          onChanged: (value) {
                                            setState(() {
                                              _textLines[index] = TextLineConfig(
                                                text: line.text,
                                                fontSize: value,
                                                color: line.color,
                                                fontWeight: line.fontWeight,
                                                textAlign: line.textAlign,
                                                isDivider: line.isDivider,
                                                dividerWidth: line.dividerWidth,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          '${(line.fontSize ?? 24).toInt()}px',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // 텍스트 색상
                                  Text('텍스트 색상',
                                      style: Theme.of(context).textTheme.titleSmall),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: line.color ?? '#000000',
                                          decoration: const InputDecoration(
                                            labelText: '색상 코드 (hex)',
                                            hintText: '#000000',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _textLines[index] = TextLineConfig(
                                                text: line.text,
                                                fontSize: line.fontSize,
                                                color: value.isEmpty ? null : value,
                                                fontWeight: line.fontWeight,
                                                textAlign: line.textAlign,
                                                isDivider: line.isDivider,
                                                dividerWidth: line.dividerWidth,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: line.color != null
                                              ? _parseColor(line.color!)
                                              : Colors.black,
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // 폰트 굵기
                                  Text('폰트 굵기',
                                      style: Theme.of(context).textTheme.titleSmall),
                                  DropdownButtonFormField<String>(
                                    value: line.fontWeight ?? 'bold',
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'normal', child: Text('일반')),
                                      DropdownMenuItem(value: 'w300', child: Text('얇음 (300)')),
                                      DropdownMenuItem(value: 'w400', child: Text('보통 (400)')),
                                      DropdownMenuItem(value: 'w500', child: Text('중간 (500)')),
                                      DropdownMenuItem(value: 'w600', child: Text('두꺼움 (600)')),
                                      DropdownMenuItem(value: 'bold', child: Text('굵게')),
                                      DropdownMenuItem(value: 'w700', child: Text('매우 굵게 (700)')),
                                      DropdownMenuItem(value: 'w800', child: Text('아주 굵게 (800)')),
                                      DropdownMenuItem(value: 'w900', child: Text('최대 굵게 (900)')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _textLines[index] = TextLineConfig(
                                          text: line.text,
                                          fontSize: line.fontSize,
                                          color: line.color,
                                          fontWeight: value,
                                          textAlign: line.textAlign,
                                          isDivider: line.isDivider,
                                          dividerWidth: line.dividerWidth,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // 정렬
                                  Text('정렬',
                                      style: Theme.of(context).textTheme.titleSmall),
                                  DropdownButtonFormField<String>(
                                    value: line.textAlign ?? 'center',
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'left', child: Text('왼쪽')),
                                      DropdownMenuItem(value: 'center', child: Text('가운데')),
                                      DropdownMenuItem(value: 'right', child: Text('오른쪽')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _textLines[index] = TextLineConfig(
                                          text: line.text,
                                          fontSize: line.fontSize,
                                          color: line.color,
                                          fontWeight: line.fontWeight,
                                          textAlign: value,
                                          isDivider: line.isDivider,
                                          dividerWidth: line.dividerWidth,
                                        );
                                      });
                                    },
                                  ),
                                ] else ...[
                                  // 구분선 설정
                                  Text('구분선 색상',
                                      style: Theme.of(context).textTheme.titleSmall),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: line.color ?? '#000000',
                                          decoration: const InputDecoration(
                                            labelText: '색상 코드 (hex)',
                                            hintText: '#000000',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _textLines[index] = TextLineConfig(
                                                text: line.text,
                                                fontSize: line.fontSize,
                                                color: value.isEmpty ? null : value,
                                                fontWeight: line.fontWeight,
                                                textAlign: line.textAlign,
                                                isDivider: true,
                                                dividerWidth: line.dividerWidth,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: line.color != null
                                              ? _parseColor(line.color!)
                                              : Colors.black,
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // 구분선 길이
                                  Text('구분선 길이',
                                      style: Theme.of(context).textTheme.titleSmall),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Slider(
                                          value: (line.dividerWidth ?? 0.5).clamp(0.1, 1.0),
                                          min: 0.1,
                                          max: 1.0,
                                          divisions: 18,
                                          label: '${((line.dividerWidth ?? 0.5) * 100).toInt()}%',
                                          onChanged: (value) {
                                            setState(() {
                                              _textLines[index] = TextLineConfig(
                                                text: line.text,
                                                fontSize: line.fontSize,
                                                color: line.color,
                                                fontWeight: line.fontWeight,
                                                textAlign: line.textAlign,
                                                isDivider: true,
                                                dividerWidth: value,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          '${((line.dividerWidth ?? 0.5) * 100).toInt()}%',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                // 삭제 버튼
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _removeTextLine(index);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  label: const Text('이 줄 삭제',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류: $err')),
      ),
    );
  }
}
