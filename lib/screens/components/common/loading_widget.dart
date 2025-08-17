import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class LoadingWidget extends StatefulWidget {
  final double size;
  final Duration duration;
  final String? text;
  final TextStyle? textStyle;
  final double? progress; // 외부에서 진행도 받기

  const LoadingWidget({
    super.key,
    this.size = 100.0,
    this.duration = const Duration(seconds: 2),
    this.text,
    this.textStyle,
    this.progress,
  });

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  ui.Image? _logoImage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // 외부 진행도가 없으면 자동 애니메이션
    if (widget.progress == null) {
      _controller.forward();
    }
    
    // 로고 이미지 로드
    _loadLogoImage();
  }

  Future<void> _loadLogoImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.horizontal.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo fi = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _logoImage = fi.image;
        });
      }
    } catch (e) {
      debugPrint('로고 이미지 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: LogoLoadingPainter(
                  progress: widget.progress ?? _progressAnimation.value,
                  logoImage: _logoImage,
                ),
              ),
            );
          },
        ),
        if (widget.text != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.text!,
            style: widget.textStyle ?? const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class LogoLoadingPainter extends CustomPainter {
  final double progress;
  final ui.Image? logoImage;

  LogoLoadingPainter({required this.progress, this.logoImage});

  @override
  void paint(Canvas canvas, Size size) {
    if (logoImage == null) return;

    final center = Offset(size.width / 2, size.height / 2);
    
    // 로고 크기 계산 (원본 비율 유지)
    final imageAspectRatio = logoImage!.width / logoImage!.height;
    final containerAspectRatio = size.width / size.height;
    
    double logoWidth, logoHeight;
    if (imageAspectRatio > containerAspectRatio) {
      logoWidth = size.width * 0.8;
      logoHeight = logoWidth / imageAspectRatio;
    } else {
      logoHeight = size.height * 0.8;
      logoWidth = logoHeight * imageAspectRatio;
    }
    
    final logoRect = Rect.fromCenter(
      center: center,
      width: logoWidth,
      height: logoHeight,
    );

    // 흑백 로고 그리기 (배경)
    final greyPaint = Paint()
      ..colorFilter = ColorFilter.mode(Colors.grey.shade400, BlendMode.srcIn);
    
    canvas.drawImageRect(
      logoImage!,
      Rect.fromLTWH(0, 0, logoImage!.width.toDouble(), logoImage!.height.toDouble()),
      logoRect,
      greyPaint,
    );

    // 진행도에 따른 컬러 로고 (좌에서 우로)
    if (progress > 0) {
      final colorPaint = Paint(); // 원본 색상 유지

      // 진행도에 따라 로고의 왼쪽부터 일부만 그리기
      final clipRect = Rect.fromLTWH(
        logoRect.left,
        logoRect.top,
        logoRect.width * progress,
        logoRect.height,
      );
      
      canvas.save();
      canvas.clipRect(clipRect);
      canvas.drawImageRect(
        logoImage!,
        Rect.fromLTWH(0, 0, logoImage!.width.toDouble(), logoImage!.height.toDouble()),
        logoRect,
        colorPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 전체 화면 로딩 오버레이
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingText;
  final Color? backgroundColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingText,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: backgroundColor ?? Colors.black.withOpacity(0.5),
            child: Center(
              child: LoadingWidget(
                size: 120,
                text: loadingText ?? '처리 중...',
                textStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// 버튼 로딩 상태
class LoadingButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget child;
  final String? loadingText;
  final ButtonStyle? style;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.child,
    this.loadingText,
    this.style,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: widget.style,
      child: widget.isLoading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: LoadingWidget(
                    size: 16,
                    duration: const Duration(milliseconds: 1000),
                  ),
                ),
                const SizedBox(width: 8),
                Text(widget.loadingText ?? '처리 중...'),
              ],
            )
          : widget.child,
    );
  }
} 