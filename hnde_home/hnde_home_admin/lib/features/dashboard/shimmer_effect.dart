import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// 빛이 지나가는 효과를 그리는 커스텀 페인터
class ShimmerPainter extends CustomPainter {
  final double progress;
  final double width;
  final double opacity;

  ShimmerPainter({
    required this.progress,
    this.width = 0.3,
    this.opacity = 0.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 대각선으로 지나가는 효과 (왼쪽 위에서 오른쪽 아래로)
    final startX = (progress - width) * size.width;
    final endX = progress * size.width;

    // 대각선 각도 계산 (약 30도)
    final angle = 0.5; // 탄젠트 값으로 각도 조절
    final startY = startX * angle;
    final endY = endX * angle;

    // 더 부드러운 그라데이션을 위한 여러 색상 스톱
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(startX, startY),
        Offset(endX, endY),
        [
          Colors.transparent,
          Colors.white.withOpacity(opacity * 0.3),
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(opacity * 0.95),
          Colors.white.withOpacity(opacity * 0.8),
          Colors.white.withOpacity(opacity * 0.3),
          Colors.transparent,
        ],
        [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
      )
      ..blendMode = BlendMode.plus; // 더 밝게 보이도록

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.width != width ||
        oldDelegate.opacity != opacity;
  }
}

/// 빛이 지나가는 애니메이션 효과 위젯
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double width;
  final double opacity;
  final bool enabled;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 3),
    this.width = 0.3,
    this.opacity = 0.8,
    this.enabled = true,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              painter: ShimmerPainter(
                progress: _animation.value,
                width: widget.width,
                opacity: widget.opacity,
              ),
              child: SizedBox.expand(),
            );
          },
        ),
      ],
    );
  }
}
