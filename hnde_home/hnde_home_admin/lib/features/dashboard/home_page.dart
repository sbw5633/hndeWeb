import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/home_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/file_upload_service.dart';
import '../../models/home_page_config.dart';
import 'dart:ui';
import 'shimmer_effect.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _topLogoUrl;
  List<String> _mainImageUrls = [];
  List<TextLineConfig> _textLines = [];
  final Map<int, TextEditingController> _textLineControllers = {};
  TextPosition _textPosition = TextPosition.center;
  ImageEffect _imageEffect = ImageEffect.none;
  double _effectValue = 0.0;
  ImageSlideTransition _slideTransition = ImageSlideTransition.fade;
  int _transitionDuration = 3;
  bool _isLoading = false;
  int _currentImageIndex = 0;
  // 텍스트 배경 스타일 (전체 공통)
  String? _textBackgroundColor;
  double _textBackgroundOpacity = 0.0;

  TextEditingController _getTextLineController(int index) {
    if (!_textLineControllers.containsKey(index)) {
      final text = index < _textLines.length ? _textLines[index].text : '';
      _textLineControllers[index] = TextEditingController(text: text);
    }
    // controller는 재사용되므로 커서 위치가 유지됨
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
    // Controller dispose
    _textLineControllers[index]?.dispose();
    _textLineControllers.remove(index);

    // 인덱스 재조정
    final keysToUpdate =
        _textLineControllers.keys.where((k) => k > index).toList()..sort();
    final tempControllers = <int, TextEditingController>{};
    for (var oldKey in keysToUpdate) {
      final controller = _textLineControllers[oldKey]!;
      tempControllers[oldKey - 1] = controller;
    }
    for (var oldKey in keysToUpdate) {
      _textLineControllers.remove(oldKey);
    }
    _textLineControllers.addAll(tempControllers);

    // 텍스트 라인 제거
    _textLines.removeAt(index);
  }

  void _addTextLine() {
    final newIndex = _textLines.length;
    _textLines.add(TextLineConfig(text: ''));
    _textLineControllers[newIndex] = TextEditingController(text: '');
  }

  @override
  void dispose() {
    // 모든 TextEditingController dispose
    for (var controller in _textLineControllers.values) {
      controller.dispose();
    }
    _textLineControllers.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    final asyncValue = ref.read(homePageConfigProvider);
    asyncValue.whenData((config) {
      if (config != null) {
        _topLogoUrl = config.topLogoUrl;
        if (config.mainHero != null) {
          _mainImageUrls = List<String>.from(config.mainHero!.imageUrls);
          _textLines = List<TextLineConfig>.from(config.mainHero!.textLines);
          if (_textLines.isEmpty &&
              config.mainHero!.text != null &&
              config.mainHero!.text!.isNotEmpty) {
            // 호환성: 기존 단일 텍스트를 첫 번째 라인으로 변환
            _textLines = [TextLineConfig(text: config.mainHero!.text!)];
          }
          // 기존 controller들 dispose
          for (var controller in _textLineControllers.values) {
            controller.dispose();
          }
          _textLineControllers.clear();
          // 새로운 controller들 생성
          for (int i = 0; i < _textLines.length; i++) {
            _textLineControllers[i] =
                TextEditingController(text: _textLines[i].text);
          }
          _textPosition = config.mainHero!.textPosition;
          _imageEffect = config.mainHero!.imageEffect;
          _effectValue = config.mainHero!.effectValue;
          _slideTransition = config.mainHero!.slideTransition;
          _transitionDuration = config.mainHero!.transitionDuration;
          _currentImageIndex = 0;
          _textBackgroundColor = config.mainHero!.textBackgroundColor;
          _textBackgroundOpacity = config.mainHero!.textBackgroundOpacity;
        }
        setState(() {});
      }
    });
  }

  Future<void> _pickTopLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _topLogoUrl = uploadService.getViewUrl(result['view_url']);
        });
        // 저장 버튼을 누를 때만 저장
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

  Future<void> _pickMainImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _mainImageUrls.add(uploadService.getViewUrl(result['view_url']));
        });
        // 저장 버튼을 누를 때만 저장
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

  void _removeMainImage(int index) {
    setState(() {
      _mainImageUrls.removeAt(index);
      if (_currentImageIndex >= _mainImageUrls.length) {
        _currentImageIndex =
            _mainImageUrls.isEmpty ? 0 : _mainImageUrls.length - 1;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final config = HomePageConfig(
        id: 'main',
        topLogoUrl: _topLogoUrl,
        mainHero: MainHeroConfig(
          imageUrls: _mainImageUrls,
          textLines: _textLines.where((line) => line.text.isNotEmpty).toList(),
          textPosition: _textPosition,
          imageEffect: _imageEffect,
          effectValue: _effectValue,
          slideTransition: _slideTransition,
          transitionDuration: _transitionDuration,
          textBackgroundColor: _textBackgroundColor,
          textBackgroundOpacity: _textBackgroundOpacity,
        ),
      );
      await ref.read(homePageConfigControllerProvider).save(config);
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

  Widget _buildImagePreview(
      String? imageUrl, ImageEffect effect, double value) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget image = Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.error, color: Colors.red),
          ),
        );
      },
    );

    // 동적 이펙트 적용
    switch (effect) {
      case ImageEffect.shimmer:
        // 빛이 지나가는 효과
        final duration = Duration(
            milliseconds: 2000 + ((1.0 - value) * 3000).round()); // 2~5초
        final width = 0.2 + (value * 0.3); // 0.2~0.5
        final opacity = 0.5 + (value * 0.5); // 0.5~1.0
        return ShimmerEffect(
          enabled: true,
          duration: duration,
          width: width,
          opacity: opacity,
          child: image,
        );
      case ImageEffect.fade:
        // 페이드 인/아웃 효과
        return _FadeEffect(
          duration: Duration(
              milliseconds: 1000 + ((1.0 - value) * 2000).round()), // 1~3초
          child: image,
        );
      case ImageEffect.pulse:
        // 맥박 효과
        return _PulseEffect(
          duration: Duration(
              milliseconds: 800 + ((1.0 - value) * 1200).round()), // 0.8~2초
          child: image,
        );
      case ImageEffect.slide:
        // 슬라이드 효과
        return _SlideEffect(
          duration: Duration(
              milliseconds: 2000 + ((1.0 - value) * 3000).round()), // 2~5초
          child: image,
        );
      case ImageEffect.zoom:
        // 줌 인/아웃 효과
        return _ZoomEffect(
          duration: Duration(
              milliseconds: 1500 + ((1.0 - value) * 2500).round()), // 1.5~4초
          child: image,
        );
      case ImageEffect.none:
        return image;
    }
  }

  Alignment _getTextAlignment(TextPosition position) {
    switch (position) {
      case TextPosition.topLeft:
        return Alignment.topLeft;
      case TextPosition.topCenter:
        return Alignment.topCenter;
      case TextPosition.topRight:
        return Alignment.topRight;
      case TextPosition.centerLeft:
        return Alignment.centerLeft;
      case TextPosition.center:
        return Alignment.center;
      case TextPosition.centerRight:
        return Alignment.centerRight;
      case TextPosition.bottomLeft:
        return Alignment.bottomLeft;
      case TextPosition.bottomCenter:
        return Alignment.bottomCenter;
      case TextPosition.bottomRight:
        return Alignment.bottomRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncConfig = ref.watch(homePageConfigProvider);
    final userInfo = ref.watch(currentUserInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('홈화면 관리')),
      body: userInfo.when(
        data: (user) {
          final isAdmin = user?.isAdmin ?? false;
          
          return asyncConfig.when(
            data: (config) {
              if (config != null && _topLogoUrl == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
              }
              
              // 휴게소 관리자인 경우: 읽기 전용 미리보기만 표시
              if (!isAdmin) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 상단 로고 미리보기
                      if (config?.topLogoUrl != null && config!.topLogoUrl!.isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '상단 로고',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    config.topLogoUrl!,
                                    width: double.infinity,
                                    height: 100,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (config?.topLogoUrl != null && config!.topLogoUrl!.isNotEmpty)
                        const SizedBox(height: 24),
                      // 메인 히어로 섹션 미리보기
                      if (config != null && config.mainHero != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '메인 이미지',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                if (config.mainHero!.imageUrls.isNotEmpty)
                                  SizedBox(
                                    height: 300,
                                    child: _SlideShowWidget(
                                      imageUrls: config.mainHero!.imageUrls,
                                      imageEffect: config.mainHero!.imageEffect,
                                      effectValue: config.mainHero!.effectValue,
                                      slideTransition: config.mainHero!.slideTransition,
                                      transitionDuration: config.mainHero!.transitionDuration,
                                      onImageChanged: (_) {},
                                    ),
                                  ),
                                if (config.mainHero!.textLines.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    '텍스트',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: config.mainHero!.textLines
                                          .map((line) => Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Text(
                                                  line.text,
                                                  style: TextStyle(
                                                    fontSize: line.fontSize ?? 16,
                                                    color: line.color != null
                                                        ? Color(int.parse(
                                                            line.color!.replaceFirst('#', '0xFF')))
                                                        : Colors.black,
                                                    fontWeight: _getFontWeight(line.fontWeight),
                                                  ),
                                                  textAlign: _getTextAlign(
                                                      line.textAlign ?? 'center'),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
              
              // 관리자인 경우: 편집 UI 표시
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                // 상단 로고 섹션
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '상단 로고',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        AbsorbPointer(
                          absorbing: !isAdmin,
                          child: GestureDetector(
                            onTap: isAdmin ? _pickTopLogo : null,
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: _topLogoUrl != null
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            _topLogoUrl!,
                                            width: double.infinity,
                                            height: 100,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.error),
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: IconButton(
                                            icon: const Icon(Icons.close,
                                                color: Colors.white, size: 20),
                                            onPressed: () {
                                              setState(() => _topLogoUrl = null);
                                              // 저장 버튼을 누를 때만 저장
                                            },
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate,
                                              size: 32),
                                          SizedBox(height: 4),
                                          Text('로고 이미지 선택'),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 메인 이미지 섹션
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '메인 이미지',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        // 이미지 리스트
                        if (_mainImageUrls.isNotEmpty) ...[
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _mainImageUrls.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _currentImageIndex == index
                                                ? Colors.blue
                                                : Colors.grey[300]!,
                                            width: _currentImageIndex == index
                                                ? 3
                                                : 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          child: Image.network(
                                            _mainImageUrls[index],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.error),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removeMainImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // 이미지 추가 버튼
                        OutlinedButton.icon(
                          onPressed: _pickMainImage,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('이미지 추가'),
                        ),
                        const SizedBox(height: 16),
                        // 슬라이드쇼 미리보기
                        if (_mainImageUrls.isNotEmpty)
                          Container(
                            height: 400,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 400,
                                    child: _buildSlideShowPreview(),
                                  ),
                                  if (_textLines.isNotEmpty)
                                    Positioned.fill(
                                      child: Align(
                                        alignment:
                                            _getTextAlignment(_textPosition),
                                        child: Container(
                                          padding: const EdgeInsets.all(32),
                                          decoration: BoxDecoration(
                                            color: _textBackgroundColor !=
                                                        null &&
                                                    _textBackgroundOpacity > 0
                                                ? _parseColor(
                                                        _textBackgroundColor!)
                                                    .withOpacity(
                                                        _textBackgroundOpacity)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: _textLines.map((line) {
                                              if (line.isDivider) {
                                                // 구분선 표시
                                                return Container(
                                                  width: (line.dividerWidth ??
                                                          0.5) *
                                                      300,
                                                  margin: const EdgeInsets
                                                      .symmetric(vertical: 8),
                                                  child: Divider(
                                                    thickness: 2,
                                                    color: line.color != null
                                                        ? _parseColor(
                                                            line.color!)
                                                        : Colors.white,
                                                  ),
                                                );
                                              } else if (line.text.isNotEmpty) {
                                                // 텍스트 표시
                                                return Text(
                                                  line.text,
                                                  style: GoogleFonts.notoSans(
                                                    color: line.color != null
                                                        ? _parseColor(
                                                            line.color!)
                                                        : Colors.white,
                                                    fontSize:
                                                        line.fontSize ?? 24,
                                                    fontWeight: _getFontWeight(
                                                        line.fontWeight ??
                                                            'bold'),
                                                  ),
                                                  textAlign: _getTextAlign(
                                                      line.textAlign ??
                                                          'center'),
                                                );
                                              } else {
                                                return const SizedBox.shrink();
                                              }
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (_mainImageUrls.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          // 텍스트 줄 관리
                          Text('텍스트 줄 (최대 5줄)',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...List.generate(
                            _textLines.length > 5
                                ? 5
                                : (_textLines.length + 1).clamp(1, 6),
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
                              final lineController =
                                  _getTextLineController(index);

                              return Card(
                                key: ValueKey('text_line_$index'),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ExpansionTile(
                                  title: Text(line.isDivider
                                      ? '줄 ${index + 1}: 구분선'
                                      : '줄 ${index + 1}: ${line.text.isEmpty ? "(비어있음)" : line.text}'),
                                  subtitle: Text(
                                    line.isDivider
                                        ? '길이: ${((line.dividerWidth ?? 0.5) * 100).toInt()}%, 색상: ${line.color ?? "기본"}'
                                        : '크기: ${line.fontSize?.toInt() ?? 24}px, 색상: ${line.color ?? "기본"}, 굵기: ${line.fontWeight ?? "bold"}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // 텍스트/구분선 선택
                                          Text('타입',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall),
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
                                                icon:
                                                    Icon(Icons.horizontal_rule),
                                              ),
                                            ],
                                            selected: {line.isDivider},
                                            onSelectionChanged:
                                                (Set<bool> newSelection) {
                                              final isDivider =
                                                  newSelection.first;
                                              setState(() {
                                                _textLines[index] =
                                                    TextLineConfig(
                                                  text: line.text,
                                                  fontSize: line.fontSize,
                                                  color: line.color,
                                                  fontWeight: line.fontWeight,
                                                  textAlign: line.textAlign,
                                                  isDivider: isDivider,
                                                  dividerWidth: isDivider
                                                      ? (line.dividerWidth ??
                                                          0.5)
                                                      : null,
                                                );
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          // 텍스트 입력 또는 구분선 설정
                                          if (!line.isDivider) ...[
                                            TextFormField(
                                              key:
                                                  ValueKey('text_field_$index'),
                                              controller: lineController,
                                              decoration: InputDecoration(
                                                labelText: '줄 ${index + 1} 텍스트',
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                              onChanged: (value) {
                                                _updateTextLine(index, value);
                                                setState(() {});
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            // 폰트 크기
                                            Text('폰트 크기',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Slider(
                                                    value: (line.fontSize ?? 24)
                                                        .toDouble(),
                                                    min: 12.0,
                                                    max: 72.0,
                                                    divisions: 30,
                                                    label:
                                                        '${(line.fontSize ?? 24).toInt()}px',
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _textLines[index] =
                                                            TextLineConfig(
                                                          text: line.text,
                                                          fontSize: value,
                                                          color: line.color,
                                                          fontWeight:
                                                              line.fontWeight,
                                                          textAlign:
                                                              line.textAlign,
                                                          isDivider:
                                                              line.isDivider,
                                                          dividerWidth:
                                                              line.dividerWidth,
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
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue:
                                                        line.color ?? '#FFFFFF',
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText: '색상 코드 (hex)',
                                                      hintText: '#FFFFFF',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _textLines[index] =
                                                            TextLineConfig(
                                                          text: line.text,
                                                          fontSize:
                                                              line.fontSize,
                                                          color: value.isEmpty
                                                              ? null
                                                              : value,
                                                          fontWeight:
                                                              line.fontWeight,
                                                          textAlign:
                                                              line.textAlign,
                                                          isDivider:
                                                              line.isDivider,
                                                          dividerWidth:
                                                              line.dividerWidth,
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
                                                        ? _parseColor(
                                                            line.color!)
                                                        : Colors.white,
                                                    border: Border.all(
                                                        color: Colors.grey),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            // 폰트 굵기
                                            Text('폰트 굵기',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall),
                                            DropdownButtonFormField<String>(
                                              value: line.fontWeight ?? 'bold',
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                    value: 'normal',
                                                    child: Text('일반')),
                                                DropdownMenuItem(
                                                    value: 'w300',
                                                    child: Text('얇음 (300)')),
                                                DropdownMenuItem(
                                                    value: 'w400',
                                                    child: Text('보통 (400)')),
                                                DropdownMenuItem(
                                                    value: 'w500',
                                                    child: Text('중간 (500)')),
                                                DropdownMenuItem(
                                                    value: 'w600',
                                                    child: Text('두꺼움 (600)')),
                                                DropdownMenuItem(
                                                    value: 'bold',
                                                    child: Text('굵게')),
                                                DropdownMenuItem(
                                                    value: 'w700',
                                                    child: Text('매우 굵게 (700)')),
                                                DropdownMenuItem(
                                                    value: 'w800',
                                                    child: Text('아주 굵게 (800)')),
                                                DropdownMenuItem(
                                                    value: 'w900',
                                                    child: Text('최대 굵게 (900)')),
                                              ],
                                              onChanged: (value) {
                                                setState(() {
                                                  _textLines[index] =
                                                      TextLineConfig(
                                                    text: line.text,
                                                    fontSize: line.fontSize,
                                                    color: line.color,
                                                    fontWeight: value,
                                                    textAlign: line.textAlign,
                                                    isDivider: line.isDivider,
                                                    dividerWidth:
                                                        line.dividerWidth,
                                                  );
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            // 정렬
                                            Text('정렬',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall),
                                            DropdownButtonFormField<String>(
                                              value: line.textAlign ?? 'center',
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                    value: 'left',
                                                    child: Text('왼쪽')),
                                                DropdownMenuItem(
                                                    value: 'center',
                                                    child: Text('가운데')),
                                                DropdownMenuItem(
                                                    value: 'right',
                                                    child: Text('오른쪽')),
                                              ],
                                              onChanged: (value) {
                                                setState(() {
                                                  _textLines[index] =
                                                      TextLineConfig(
                                                    text: line.text,
                                                    fontSize: line.fontSize,
                                                    color: line.color,
                                                    fontWeight: line.fontWeight,
                                                    textAlign: value,
                                                    isDivider: line.isDivider,
                                                    dividerWidth:
                                                        line.dividerWidth,
                                                  );
                                                });
                                              },
                                            ),
                                          ] else ...[
                                            // 구분선 설정
                                            Text('구분선 색상',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue:
                                                        line.color ?? '#FFFFFF',
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText: '색상 코드 (hex)',
                                                      hintText: '#FFFFFF',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _textLines[index] =
                                                            TextLineConfig(
                                                          text: line.text,
                                                          fontSize:
                                                              line.fontSize,
                                                          color: value.isEmpty
                                                              ? null
                                                              : value,
                                                          fontWeight:
                                                              line.fontWeight,
                                                          textAlign:
                                                              line.textAlign,
                                                          isDivider: true,
                                                          dividerWidth:
                                                              line.dividerWidth,
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
                                                        ? _parseColor(
                                                            line.color!)
                                                        : Colors.white,
                                                    border: Border.all(
                                                        color: Colors.grey),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            // 구분선 길이
                                            Text('구분선 길이',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Slider(
                                                    value: (line.dividerWidth ??
                                                            0.5)
                                                        .clamp(0.1, 1.0),
                                                    min: 0.1,
                                                    max: 1.0,
                                                    divisions: 18,
                                                    label:
                                                        '${((line.dividerWidth ?? 0.5) * 100).toInt()}%',
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _textLines[index] =
                                                            TextLineConfig(
                                                          text: line.text,
                                                          fontSize:
                                                              line.fontSize,
                                                          color: line.color,
                                                          fontWeight:
                                                              line.fontWeight,
                                                          textAlign:
                                                              line.textAlign,
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
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            label: const Text('이 줄 삭제',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // 배경 스타일 설정 (전체 공통)
                          ExpansionTile(
                            title: const Text('배경 스타일 설정 (전체 공통)'),
                            initiallyExpanded: false,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 배경 색상
                                    Text('배경 색상',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue:
                                                _textBackgroundColor ??
                                                    '#000000',
                                            decoration: const InputDecoration(
                                              labelText: '배경 색상 코드 (hex)',
                                              hintText: '#000000',
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                _textBackgroundColor =
                                                    value.isEmpty
                                                        ? null
                                                        : value;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: _textBackgroundColor != null
                                                ? _parseColor(
                                                    _textBackgroundColor!)
                                                : Colors.black,
                                            border:
                                                Border.all(color: Colors.grey),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // 배경 불투명도
                                    Text('배경 불투명도',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Slider(
                                            value: _textBackgroundOpacity,
                                            min: 0.0,
                                            max: 1.0,
                                            divisions: 20,
                                            label:
                                                '${(_textBackgroundOpacity * 100).toInt()}%',
                                            onChanged: (value) {
                                              setState(() {
                                                _textBackgroundOpacity = value;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            '${(_textBackgroundOpacity * 100).toInt()}%',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // 텍스트 위치 선택
                          Text('텍스트 위치',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: TextPosition.values.map((position) {
                              final isSelected = _textPosition == position;
                              return ChoiceChip(
                                label: Text(_getPositionLabel(position)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _textPosition = position);
                                    // 저장 버튼을 누를 때만 저장
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          // 이미지 이펙트 선택
                          Text('이미지 이펙트',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ImageEffect>(
                            value: _imageEffect,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: ImageEffect.values.map((effect) {
                              return DropdownMenuItem(
                                value: effect,
                                child: Text(_getEffectLabel(effect)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _imageEffect = value);
                                // 저장 버튼을 누를 때만 저장
                              }
                            },
                          ),
                          if (_imageEffect != ImageEffect.none) ...[
                            const SizedBox(height: 16),
                            Text(
                                '이펙트 속도/강도: ${_effectValue.toStringAsFixed(1)}'),
                            Slider(
                              value: _effectValue,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              label: _effectValue.toStringAsFixed(1),
                              onChanged: (value) {
                                setState(() => _effectValue = value);
                                // 저장 버튼을 누를 때만 저장
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          // 변환 효과 선택
                          Text('변환 효과',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ImageSlideTransition>(
                            value: _slideTransition,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items:
                                ImageSlideTransition.values.map((transition) {
                              return DropdownMenuItem(
                                value: transition,
                                child: Text(_getTransitionLabel(transition)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _slideTransition = value);
                                // 저장 버튼을 누를 때만 저장
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          // 변환 시간 설정
                          Text('변환 시간 (초)',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _transitionDuration.toDouble(),
                                  min: 1.0,
                                  max: 10.0,
                                  divisions: 9,
                                  label: '$_transitionDuration초',
                                  onChanged: (value) {
                                    setState(() {
                                      _transitionDuration = value.round();
                                    });
                                    // 저장 버튼을 누를 때만 저장
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '$_transitionDuration초',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (isAdmin)
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
      ),
    );
  }

  String _getPositionLabel(TextPosition position) {
    switch (position) {
      case TextPosition.topLeft:
        return '상단 왼쪽';
      case TextPosition.topCenter:
        return '상단 중앙';
      case TextPosition.topRight:
        return '상단 오른쪽';
      case TextPosition.centerLeft:
        return '중앙 왼쪽';
      case TextPosition.center:
        return '중앙';
      case TextPosition.centerRight:
        return '중앙 오른쪽';
      case TextPosition.bottomLeft:
        return '하단 왼쪽';
      case TextPosition.bottomCenter:
        return '하단 중앙';
      case TextPosition.bottomRight:
        return '하단 오른쪽';
    }
  }

  String _getEffectLabel(ImageEffect effect) {
    switch (effect) {
      case ImageEffect.none:
        return '없음';
      case ImageEffect.shimmer:
        return '빛 지나가는 효과';
      case ImageEffect.fade:
        return '페이드 인/아웃';
      case ImageEffect.pulse:
        return '맥박 효과';
      case ImageEffect.slide:
        return '슬라이드 효과';
      case ImageEffect.zoom:
        return '줌 인/아웃';
    }
  }

  String _getTransitionLabel(ImageSlideTransition transition) {
    switch (transition) {
      case ImageSlideTransition.none:
        return '없음';
      case ImageSlideTransition.fade:
        return '페이드';
      case ImageSlideTransition.slideLeft:
        return '왼쪽으로 슬라이드';
      case ImageSlideTransition.slideRight:
        return '오른쪽으로 슬라이드';
      case ImageSlideTransition.slideUp:
        return '위로 슬라이드';
      case ImageSlideTransition.slideDown:
        return '아래로 슬라이드';
      case ImageSlideTransition.zoom:
        return '줌';
    }
  }

  Color _parseColor(String hexColor) {
    try {
      String hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      print('색상 파싱 오류: $e');
    }
    return Colors.white;
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

  TextAlign _getTextAlign(String align) {
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

  Widget _buildSlideShowPreview() {
    if (_mainImageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SlideShowWidget(
      imageUrls: _mainImageUrls,
      imageEffect: _imageEffect,
      effectValue: _effectValue,
      slideTransition: _slideTransition,
      transitionDuration: _transitionDuration,
      onImageChanged: (index) {
        setState(() {
          _currentImageIndex = index;
        });
      },
    );
  }
}

// 페이드 인/아웃 효과 위젯
class _FadeEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _FadeEffect({required this.child, required this.duration});

  @override
  State<_FadeEffect> createState() => _FadeEffectState();
}

class _FadeEffectState extends State<_FadeEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

// 맥박 효과 위젯
class _PulseEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _PulseEffect({required this.child, required this.duration});

  @override
  State<_PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<_PulseEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

// 슬라이드 효과 위젯
class _SlideEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _SlideEffect({required this.child, required this.duration});

  @override
  State<_SlideEffect> createState() => _SlideEffectState();
}

class _SlideEffectState extends State<_SlideEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<Offset>(begin: Offset(-0.05, 0), end: Offset(0.05, 0))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: widget.child,
    );
  }
}

// 줌 인/아웃 효과 위젯
class _ZoomEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _ZoomEffect({required this.child, required this.duration});

  @override
  State<_ZoomEffect> createState() => _ZoomEffectState();
}

class _ZoomEffectState extends State<_ZoomEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

// 슬라이드쇼 위젯
class _SlideShowWidget extends StatefulWidget {
  final List<String> imageUrls;
  final ImageEffect imageEffect;
  final double effectValue;
  final ImageSlideTransition slideTransition;
  final int transitionDuration;
  final ValueChanged<int>? onImageChanged;

  const _SlideShowWidget({
    required this.imageUrls,
    required this.imageEffect,
    required this.effectValue,
    required this.slideTransition,
    required this.transitionDuration,
    this.onImageChanged,
  });

  @override
  State<_SlideShowWidget> createState() => _SlideShowWidgetState();
}

class _SlideShowWidgetState extends State<_SlideShowWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: widget.transitionDuration),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.imageUrls.length;
        });
        widget.onImageChanged?.call(_currentIndex);
        _controller.reset();
        _controller.forward();
      }
    });
    _controller.forward();
  }

  @override
  void didUpdateWidget(_SlideShowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionDuration != widget.transitionDuration ||
        oldWidget.imageUrls.length != widget.imageUrls.length) {
      _controller.duration = Duration(seconds: widget.transitionDuration);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildImageWithEffect(String imageUrl) {
    Widget image = Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.error, color: Colors.red),
          ),
        );
      },
    );

    // 개별 이미지에 지속 이펙트 적용
    switch (widget.imageEffect) {
      case ImageEffect.shimmer:
        final duration = Duration(
            milliseconds: 2000 + ((1.0 - widget.effectValue) * 3000).round());
        final width = 0.2 + (widget.effectValue * 0.3);
        final opacity = 0.5 + (widget.effectValue * 0.5);
        return ShimmerEffect(
          enabled: true,
          duration: duration,
          width: width,
          opacity: opacity,
          child: image,
        );
      case ImageEffect.fade:
        return _FadeEffect(
          duration: Duration(
              milliseconds: 1000 + ((1.0 - widget.effectValue) * 2000).round()),
          child: image,
        );
      case ImageEffect.pulse:
        return _PulseEffect(
          duration: Duration(
              milliseconds: 800 + ((1.0 - widget.effectValue) * 1200).round()),
          child: image,
        );
      case ImageEffect.slide:
        return _SlideEffect(
          duration: Duration(
              milliseconds: 2000 + ((1.0 - widget.effectValue) * 3000).round()),
          child: image,
        );
      case ImageEffect.zoom:
        return _ZoomEffect(
          duration: Duration(
              milliseconds: 1500 + ((1.0 - widget.effectValue) * 2500).round()),
          child: image,
        );
      case ImageEffect.none:
        return image;
    }
  }

  Widget _buildTransition(Widget child) {
    switch (widget.slideTransition) {
      case ImageSlideTransition.fade:
        return FadeTransition(
          opacity: _animation,
          child: child,
        );
      case ImageSlideTransition.slideLeft:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(_animation),
          child: child,
        );
      case ImageSlideTransition.slideRight:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(_animation),
          child: child,
        );
      case ImageSlideTransition.slideUp:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(_animation),
          child: child,
        );
      case ImageSlideTransition.slideDown:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -1.0),
            end: Offset.zero,
          ).animate(_animation),
          child: child,
        );
      case ImageSlideTransition.zoom:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(_animation),
          child: child,
        );
      case ImageSlideTransition.none:
        return child;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentImage = widget.imageUrls[_currentIndex];
    final nextIndex = (_currentIndex + 1) % widget.imageUrls.length;
    final nextImage = widget.imageUrls[nextIndex];

    return Stack(
      children: [
        // 현재 이미지
        _buildImageWithEffect(currentImage),
        // 다음 이미지 (변환 중에만 표시)
        if (widget.slideTransition != ImageSlideTransition.none)
          _buildTransition(
            _buildImageWithEffect(nextImage),
          ),
      ],
    );
  }
}
