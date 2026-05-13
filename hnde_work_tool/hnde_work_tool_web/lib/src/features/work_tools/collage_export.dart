import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'collage_frame_shapes.dart';

/// [image_collage_page.dart]와 동일 — 내보내기 전용
const double kCollageExportFrameBarH = 26;

/// Isolate로 전달 가능한 레이어 스냅샷
class CollageExportLayer {
  const CollageExportLayer({
    required this.bytes,
    required this.l,
    required this.t,
    required this.w,
    required this.h,
    required this.rotation,
    required this.panX,
    required this.panY,
    required this.zoom,
    required this.borderWidth,
    required this.frameKindIndex,
  });

  final Uint8List bytes;
  final double l;
  final double t;
  final double w;
  final double h;
  final double rotation;
  final double panX;
  final double panY;
  final double zoom;
  final double borderWidth;
  final int frameKindIndex;
}

class CollageExportRequest {
  const CollageExportRequest({
    required this.cw,
    required this.ch,
    required this.layers,
  });

  final double cw;
  final double ch;
  final List<CollageExportLayer> layers;
}

({
  double minX,
  double minY,
  double maxX,
  double maxY,
}) _rotatedRectAabb(
  double left,
  double top,
  double w,
  double h,
  double radians,
) {
  final double cx = left + w / 2;
  final double cy = top + h / 2;
  final double c = math.cos(radians);
  final double s = math.sin(radians);
  double rx(double px, double py) =>
      cx + (px - cx) * c - (py - cy) * s;
  double ry(double px, double py) =>
      cy + (px - cx) * s + (py - cy) * c;
  final List<double> xs = <double>[
    rx(left, top),
    rx(left + w, top),
    rx(left + w, top + h),
    rx(left, top + h),
  ];
  final List<double> ys = <double>[
    ry(left, top),
    ry(left + w, top),
    ry(left + w, top + h),
    ry(left, top + h),
  ];
  return (
    minX: xs.reduce(math.min),
    maxX: xs.reduce(math.max),
    minY: ys.reduce(math.min),
    maxY: ys.reduce(math.max),
  );
}

void _rotatePointAround(
  double px,
  double py,
  double cx,
  double cy,
  double radians,
  List<double> out,
) {
  final double dx = px - cx;
  final double dy = py - cy;
  final double c = math.cos(radians);
  final double s = math.sin(radians);
  out[0] = cx + dx * c - dy * s;
  out[1] = cy + dx * s + dy * c;
}

/// 콜라주 PNG 바이트 생성(동기, Isolate에서 호출 가능)
Uint8List buildCollagePngBytes(CollageExportRequest req) {
  const double padScr = 32;
  final double cw = req.cw;
  final double ch = req.ch;
  double unionMinX = double.infinity;
  double unionMinY = double.infinity;
  double unionMaxX = -double.infinity;
  double unionMaxY = -double.infinity;
  for (final CollageExportLayer L in req.layers) {
    final double x = L.l * cw;
    final double y = L.t * ch;
    final double w = L.w * cw;
    final double h = L.h * ch;
    final ({
      double minX,
      double minY,
      double maxX,
      double maxY,
    }) b = _rotatedRectAabb(x, y, w, h, L.rotation);
    unionMinX = math.min(unionMinX, b.minX);
    unionMinY = math.min(unionMinY, b.minY);
    unionMaxX = math.max(unionMaxX, b.maxX);
    unionMaxY = math.max(unionMaxY, b.maxY);
  }
  unionMinX -= padScr;
  unionMinY -= padScr;
  unionMaxX += padScr;
  unionMaxY += padScr;
  if (!unionMinX.isFinite) {
    unionMinX = 0;
    unionMinY = 0;
    unionMaxX = cw;
    unionMaxY = ch;
  }
  final double unionW = math.max(1.0, unionMaxX - unionMinX);
  final double unionH = math.max(1.0, unionMaxY - unionMinY);

  const int outW = 2400;
  final int outH = (outW / unionW * unionH).round();
  final double scale = outW / unionW;

  final img.Image canvas =
      img.Image(width: outW, height: outH, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  final img.ColorRgba8 borderColor =
      img.ColorRgba8(0x1E, 0x3A, 0x8A, 255);

  final List<double> tmp = List<double>.filled(2, 0);

  for (final CollageExportLayer L in req.layers) {
    final img.Image? dec = img.decodeImage(L.bytes);
    if (dec == null) {
      continue;
    }
    final CollageFrameKind kind =
        CollageFrameKind.values[L.frameKindIndex.clamp(0, 3)];
    final double sx = L.l * cw;
    final double sy = L.t * ch;
    final double srw = L.w * cw;
    final double srh = L.h * ch;

    final int dxExp = ((sx - unionMinX) * scale).round();
    final int dyExp = ((sy - unionMinY) * scale).round();
    final int rw = (srw * scale).round().clamp(1, outW);
    final int rh = (srh * scale).round().clamp(1, outH);
    final int barPx = (kCollageExportFrameBarH * scale).round();
    final int innerH = rh - barPx;
    if (rw < 4 || innerH < 4) {
      continue;
    }
    final img.Image? piece = CollageFrameShapes.compositeFramed(
      dec,
      kind,
      rw,
      innerH,
      L.panX,
      L.panY,
      L.zoom,
    );
    if (piece == null) {
      continue;
    }
    final int strokePx = (L.borderWidth * outW / cw)
        .round()
        .clamp(0, math.min(rw, innerH) ~/ 2);
    if (strokePx > 0) {
      CollageFrameShapes.drawFrameBorderInset(
        piece,
        kind,
        strokePx,
        borderColor,
      );
    }

    final double fcx = dxExp + rw / 2;
    final double fcy = dyExp + rh / 2;
    final double icx = dxExp + rw / 2;
    final double icy = dyExp + barPx + innerH / 2;
    _rotatePointAround(icx, icy, fcx, fcy, L.rotation, tmp);

    img.Image pr = piece;
    if (L.rotation.abs() > 1e-6) {
      final double angleDeg = L.rotation * 180 / math.pi;
      pr = img.copyRotate(piece, angle: angleDeg);
    }

    final int dstX = (tmp[0] - pr.width / 2).round();
    final int dstY = (tmp[1] - pr.height / 2).round();

    img.compositeImage(
      canvas,
      pr,
      dstX: dstX,
      dstY: dstY,
      blend: img.BlendMode.alpha,
    );
  }
  return Uint8List.fromList(img.encodePng(canvas));
}

/// 메인 isolate에서 레이어 사이에 이벤트 루프 양보(웹 폴백)
Future<Uint8List> buildCollagePngBytesYielding(CollageExportRequest req) async {
  const double padScr = 32;
  final double cw = req.cw;
  final double ch = req.ch;
  double unionMinX = double.infinity;
  double unionMinY = double.infinity;
  double unionMaxX = -double.infinity;
  double unionMaxY = -double.infinity;
  for (final CollageExportLayer L in req.layers) {
    final double x = L.l * cw;
    final double y = L.t * ch;
    final double w = L.w * cw;
    final double h = L.h * ch;
    final ({
      double minX,
      double minY,
      double maxX,
      double maxY,
    }) b = _rotatedRectAabb(x, y, w, h, L.rotation);
    unionMinX = math.min(unionMinX, b.minX);
    unionMinY = math.min(unionMinY, b.minY);
    unionMaxX = math.max(unionMaxX, b.maxX);
    unionMaxY = math.max(unionMaxY, b.maxY);
  }
  unionMinX -= padScr;
  unionMinY -= padScr;
  unionMaxX += padScr;
  unionMaxY += padScr;
  if (!unionMinX.isFinite) {
    unionMinX = 0;
    unionMinY = 0;
    unionMaxX = cw;
    unionMaxY = ch;
  }
  final double unionW = math.max(1.0, unionMaxX - unionMinX);
  final double unionH = math.max(1.0, unionMaxY - unionMinY);

  const int outW = 2400;
  final int outH = (outW / unionW * unionH).round();
  final double scale = outW / unionW;

  final img.Image canvas =
      img.Image(width: outW, height: outH, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  final img.ColorRgba8 borderColor =
      img.ColorRgba8(0x1E, 0x3A, 0x8A, 255);

  final List<double> tmp = List<double>.filled(2, 0);
  int i = 0;
  for (final CollageExportLayer L in req.layers) {
    if (i++ > 0) {
      await Future<void>.delayed(Duration.zero);
    }
    final img.Image? dec = img.decodeImage(L.bytes);
    if (dec == null) {
      continue;
    }
    final CollageFrameKind kind =
        CollageFrameKind.values[L.frameKindIndex.clamp(0, 3)];
    final double sx = L.l * cw;
    final double sy = L.t * ch;
    final double srw = L.w * cw;
    final double srh = L.h * ch;

    final int dxExp = ((sx - unionMinX) * scale).round();
    final int dyExp = ((sy - unionMinY) * scale).round();
    final int rw = (srw * scale).round().clamp(1, outW);
    final int rh = (srh * scale).round().clamp(1, outH);
    final int barPx = (kCollageExportFrameBarH * scale).round();
    final int innerH = rh - barPx;
    if (rw < 4 || innerH < 4) {
      continue;
    }
    final img.Image? piece = CollageFrameShapes.compositeFramed(
      dec,
      kind,
      rw,
      innerH,
      L.panX,
      L.panY,
      L.zoom,
    );
    if (piece == null) {
      continue;
    }
    final int strokePx = (L.borderWidth * outW / cw)
        .round()
        .clamp(0, math.min(rw, innerH) ~/ 2);
    if (strokePx > 0) {
      CollageFrameShapes.drawFrameBorderInset(
        piece,
        kind,
        strokePx,
        borderColor,
      );
    }

    final double fcx = dxExp + rw / 2;
    final double fcy = dyExp + rh / 2;
    final double icx = dxExp + rw / 2;
    final double icy = dyExp + barPx + innerH / 2;
    _rotatePointAround(icx, icy, fcx, fcy, L.rotation, tmp);

    img.Image pr = piece;
    if (L.rotation.abs() > 1e-6) {
      final double angleDeg = L.rotation * 180 / math.pi;
      pr = img.copyRotate(piece, angle: angleDeg);
    }

    final int dstX = (tmp[0] - pr.width / 2).round();
    final int dstY = (tmp[1] - pr.height / 2).round();

    img.compositeImage(
      canvas,
      pr,
      dstX: dstX,
      dstY: dstY,
      blend: img.BlendMode.alpha,
    );
  }
  for (int k = 0; k < 20; k++) {
    await Future<void>.delayed(Duration.zero);
  }
  return Uint8List.fromList(img.encodePng(canvas));
}
