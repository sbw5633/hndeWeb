import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// 액자(프레임) 모양 — UI 클립과 내보내기 마스크에 공통 사용
enum CollageFrameKind {
  rectangle,
  circle,
  heart,
  star,
}

/// 하트·별 등 — 정규화 좌표 (0~1) 기준 point-in 테스트
class CollageFrameShapes {
  CollageFrameShapes._();

  static Path buildPath(CollageFrameKind kind, Rect bounds) {
    switch (kind) {
      case CollageFrameKind.rectangle:
        return Path()..addRect(bounds);
      case CollageFrameKind.circle:
        return Path()..addOval(bounds);
      case CollageFrameKind.heart:
        return _heartPath(bounds);
      case CollageFrameKind.star:
        return _starPath(bounds, points: 5);
    }
  }

  static Path _heartPath(Rect r) {
    final double w = r.width;
    final double h = r.height;
    final Path p = Path();
    p.moveTo(0.5 * w + r.left, 0.32 * h + r.top);
    p.cubicTo(
      r.left + 0.5 * w,
      r.top + 0.12 * h,
      r.left + 0.15 * w,
      r.top + 0.08 * h,
      r.left + 0.15 * w,
      r.top + 0.35 * h,
    );
    p.cubicTo(
      r.left + 0.15 * w,
      r.top + 0.58 * h,
      r.left + 0.5 * w,
      r.top + 0.92 * h,
      r.left + 0.5 * w,
      r.top + 0.92 * h,
    );
    p.cubicTo(
      r.left + 0.5 * w,
      r.top + 0.92 * h,
      r.left + 0.85 * w,
      r.top + 0.58 * h,
      r.left + 0.85 * w,
      r.top + 0.35 * h,
    );
    p.cubicTo(
      r.left + 0.85 * w,
      r.top + 0.08 * h,
      r.left + 0.5 * w,
      r.top + 0.12 * h,
      r.left + 0.5 * w,
      r.top + 0.32 * h,
    );
    p.close();
    return p;
  }

  static Path _starPath(Rect r, {required int points}) {
    final double cx = r.center.dx;
    final double cy = r.center.dy;
    final double outer = math.min(r.width, r.height) * 0.48;
    final double inner = outer * 0.42;
    final Path p = Path();
    for (int i = 0; i < points * 2; i++) {
      final double rad = (math.pi / 2) + (i * math.pi / points);
      final double dist = i.isEven ? outer : inner;
      final double x = cx + dist * math.cos(rad);
      final double y = cy - dist * math.sin(rad);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    return p;
  }

  /// (nx,ny) 는 프레임 로컬 0~1
  static bool pointInFrame(CollageFrameKind kind, double nx, double ny) {
    switch (kind) {
      case CollageFrameKind.rectangle:
        return nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1;
      case CollageFrameKind.circle:
        final double dx = nx - 0.5;
        final double dy = ny - 0.5;
        return dx * dx + dy * dy <= 0.25;
      case CollageFrameKind.heart:
        return _pointInHeart(nx, ny);
      case CollageFrameKind.star:
        return _pointInStarPolygon(nx, ny);
    }
  }

  static bool _pointInHeart(double nx, double ny) {
    return _pointInPolygon(_heartPointsNorm(), nx, ny);
  }

  static List<ui.Offset> _heartPointsNorm() {
    const int n = 48;
    final List<ui.Offset> raw = <ui.Offset>[];
    for (int i = 0; i < n; i++) {
      final double t = (i / n) * 2 * math.pi;
      final double x = 16 * math.pow(math.sin(t), 3).toDouble();
      final double y = -(13 * math.cos(t) -
          5 * math.cos(2 * t) -
          2 * math.cos(3 * t) -
          math.cos(4 * t));
      raw.add(ui.Offset(x, y));
    }
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final ui.Offset o in raw) {
      minX = math.min(minX, o.dx);
      minY = math.min(minY, o.dy);
      maxX = math.max(maxX, o.dx);
      maxY = math.max(maxY, o.dy);
    }
    final double bw = maxX - minX;
    final double bh = maxY - minY;
    const double pad = 0.04;
    final List<ui.Offset> pts = <ui.Offset>[];
    for (final ui.Offset o in raw) {
      pts.add(
        ui.Offset(
          pad + (o.dx - minX) / bw * (1 - 2 * pad),
          pad + (o.dy - minY) / bh * (1 - 2 * pad),
        ),
      );
    }
    return pts;
  }

  static List<ui.Offset> _starPointsNorm() {
    const int points = 5;
    final List<ui.Offset> pts = <ui.Offset>[];
    for (int i = 0; i < points * 2; i++) {
      final double rad = (math.pi / 2) + (i * math.pi / points);
      final double dist = i.isEven ? 0.48 : 0.2;
      pts.add(ui.Offset(
        0.5 + dist * math.cos(rad),
        0.5 - dist * math.sin(rad),
      ));
    }
    return pts;
  }

  static bool _pointInStarPolygon(double nx, double ny) {
    return _pointInPolygon(_starPointsNorm(), nx, ny);
  }

  static bool _pointInPolygon(List<ui.Offset> poly, double x, double y) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final double xi = poly[i].dx;
      final double yi = poly[i].dy;
      final double xj = poly[j].dx;
      final double yj = poly[j].dy;
      final bool intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// 내보내기: 액자 안에 사진(확대·이동) 합성
  static img.Image? compositeFramed(
    img.Image src,
    CollageFrameKind kind,
    int rw,
    int rh,
    double panX,
    double panY,
    double zoom,
  ) {
    if (rw < 2 || rh < 2) {
      return null;
    }
    final double z = zoom.clamp(0.4, 4.0);
    final double base = math.max(rw / src.width, rh / src.height);
    final double scale = base * z;
    final double sw = src.width * scale;
    final double sh = src.height * scale;
    final double ox = (rw - sw) / 2 + panX * rw * 0.45;
    final double oy = (rh - sh) / 2 + panY * rh * 0.45;

    final img.Image out = img.Image(width: rw, height: rh, numChannels: 4);
    img.fill(out, color: img.ColorRgba8(0, 0, 0, 0));
    for (int py = 0; py < rh; py++) {
      for (int px = 0; px < rw; px++) {
        final double nx = (px + 0.5) / rw;
        final double ny = (py + 0.5) / rh;
        if (!pointInFrame(kind, nx, ny)) {
          continue;
        }
        final double sx = (px - ox) / scale;
        final double sy = (py - oy) / scale;
        final int ix = sx.floor();
        final int iy = sy.floor();
        if (ix < 0 ||
            iy < 0 ||
            ix >= src.width ||
            iy >= src.height) {
          continue;
        }
        final img.Pixel p = src.getPixel(ix, iy);
        out.setPixel(
          px,
          py,
          img.ColorRgba8(
            p.r.toInt(),
            p.g.toInt(),
            p.b.toInt(),
            255,
          ),
        );
      }
    }
    return out;
  }

  /// 액자 안쪽으로만 테두리(두께 strokePx). 0이면 호출 생략.
  static void drawFrameBorderInset(
    img.Image target,
    CollageFrameKind kind,
    int strokePx,
    img.ColorRgba8 color,
  ) {
    if (strokePx <= 0 || target.width < 2 || target.height < 2) {
      return;
    }
    final int w = target.width;
    final int h = target.height;
    final List<List<bool>> mask = List<List<bool>>.generate(
      w,
      (int x) => List<bool>.generate(
        h,
        (int y) {
          final double nx = (x + 0.5) / w;
          final double ny = (y + 0.5) / h;
          return pointInFrame(kind, nx, ny);
        },
      ),
    );
    List<List<bool>> eroded = mask;
    for (int i = 0; i < strokePx; i++) {
      eroded = _erodeCrossBool(eroded);
    }
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        if (mask[x][y] && !eroded[x][y]) {
          target.setPixel(x, y, color);
        }
      }
    }
  }

  static List<List<bool>> _erodeCrossBool(List<List<bool>> m) {
    final int w = m.length;
    final int h = m[0].length;
    final List<List<bool>> out = List<List<bool>>.generate(
      w,
      (int x) => List<bool>.filled(h, false),
    );
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        if (!m[x][y]) {
          continue;
        }
        final bool left = x > 0 ? m[x - 1][y] : false;
        final bool right = x + 1 < w ? m[x + 1][y] : false;
        final bool up = y > 0 ? m[x][y - 1] : false;
        final bool down = y + 1 < h ? m[x][y + 1] : false;
        out[x][y] = left && right && up && down;
      }
    }
    return out;
  }
}
