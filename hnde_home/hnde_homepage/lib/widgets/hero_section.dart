import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/data_service.dart';
import '../models/home_page_config.dart';
import 'shimmer_effect.dart';

class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  final DataService _dataService = DataService();
  HomePageConfig? _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      print('🖼️ HeroSection: 설정 로딩 시작');
      setState(() {
        _isLoading = true;
      });
      
      final config = await _dataService.getHomePageConfig();
      print('🖼️ HeroSection: 받은 설정 = $config');
      print('🖼️ HeroSection: topLogoUrl = ${config?.topLogoUrl}');
      print('🖼️ HeroSection: mainHero = ${config?.mainHero}');
      print('🖼️ HeroSection: mainHero.imageUrl = ${config?.mainHero?.imageUrl}');
      
      if (mounted) {
        setState(() {
          _config = config;
          _isLoading = false;
        });
        print('🖼️ HeroSection: 상태 업데이트 완료');
      }
    } catch (e, stackTrace) {
      print('❌ HeroSection: 설정 로딩 오류: $e');
      print('스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildImagePreview(
      String? imageUrl, ImageEffect effect, double value) {
    if (imageUrl == null || imageUrl.isEmpty) {
      print('⚠️ HeroSection: 이미지 URL이 없음');
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!,
              Colors.blue[700]!,
            ],
          ),
        ),
      );
    }

    print('🖼️ HeroSection: 이미지 빌드 시작: $imageUrl');
    Widget image = Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          print('✅ HeroSection: 이미지 로드 완료');
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
        print('❌ HeroSection: 이미지 로드 실패: $error');
        print('이미지 URL: $imageUrl');
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue[900]!,
                Colors.blue[700]!,
              ],
            ),
          ),
          child: const Center(
            child: Icon(Icons.error, color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    if (_isLoading) {
      return Container(
        height: isMobile ? 500 : 600,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!,
              Colors.blue[700]!,
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    final hero = _config?.mainHero;

    // 메인 이미지가 있는 경우
    if (hero != null && hero.imageUrls.isNotEmpty) {
      print('🖼️ HeroSection: 메인 이미지 표시: ${hero.imageUrls.length}개');
      return Container(
        height: isMobile ? 500 : 600,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 슬라이드쇼 배경 이미지
            Positioned.fill(
              child: _SlideShowWidget(
                imageUrls: hero.imageUrls,
                imageEffect: hero.imageEffect,
                effectValue: hero.effectValue,
                slideTransition: hero.slideTransition,
                transitionDuration: hero.transitionDuration,
              ),
            ),
            // 텍스트 오버레이
            if (hero.textLines.isNotEmpty)
              Positioned.fill(
                child: Align(
                  alignment: _getTextAlignment(hero.textPosition),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: hero.textBackgroundColor != null && hero.textBackgroundOpacity > 0
                          ? _parseColor(hero.textBackgroundColor!).withOpacity(hero.textBackgroundOpacity)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: hero.textLines.map((line) {
                        if (line.isDivider) {
                          // 구분선 표시
                          final screenWidth = MediaQuery.of(context).size.width;
                          final dividerWidth = (line.dividerWidth ?? 0.5) * screenWidth * 0.8;
                          return Container(
                            width: dividerWidth.clamp(50.0, screenWidth * 0.8),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              thickness: 2,
                              color: line.color != null
                                  ? _parseColor(line.color!)
                                  : Colors.white,
                            ),
                          );
                        } else if (line.text.isNotEmpty) {
                          // 텍스트 표시
                          return Text(
                            line.text,
                            style: GoogleFonts.notoSans(
                              fontSize: line.fontSize ?? (isMobile ? 24 : 32),
                              fontWeight: _getFontWeight(line.fontWeight ?? 'bold'),
                              color: line.color != null
                                  ? _parseColor(line.color!)
                                  : Colors.white,
                            ),
                            textAlign: _getTextAlign(line.textAlign ?? 'center'),
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
      );
    }

    // 기본 그라데이션 배경
    return Container(
      height: isMobile ? 500 : 600,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[900]!,
            Colors.blue[700]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'H&DE',
              style: GoogleFonts.roboto(
                fontSize: isMobile ? 48 : 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '혁신적인 디자인으로 공간의 가치를 창조합니다',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                fontSize: isMobile ? 18 : 24,
                color: Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[900],
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                '프로젝트 보기',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
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

  const _SlideShowWidget({
    required this.imageUrls,
    required this.imageEffect,
    required this.effectValue,
    required this.slideTransition,
    required this.transitionDuration,
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue[900]!,
                Colors.blue[700]!,
              ],
            ),
          ),
          child: const Center(
            child: Icon(Icons.error, color: Colors.white),
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
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!,
              Colors.blue[700]!,
            ],
          ),
        ),
      );
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
