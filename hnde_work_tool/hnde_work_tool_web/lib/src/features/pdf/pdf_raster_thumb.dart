import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// PDF 미리보기 타일이 재생성돼도 동일 (bytes, 페이지, 크기) 썸네일을 다시 그리지 않도록 캐시.
class _PdfRasterPngCache {
  _PdfRasterPngCache._();

  static final Map<String, Uint8List> _map = <String, Uint8List>{};
  static const int _maxEntries = 160;

  static Uint8List? get(String key) => _map[key];

  static void put(String key, Uint8List png) {
    if (_map.length >= _maxEntries && !_map.containsKey(key)) {
      _map.remove(_map.keys.first);
    }
    _map[key] = png;
  }
}

/// 웹·작은 타일에서 SfPdfViewer가 빈 칸으로 나오는 문제를 피하기 위해 PDF.js(pdfx)로 래스터 썸네일 생성.
/// (`pdfrx`는 archive 4가 필요해 `excel`과 충돌하므로 pdfx 사용)
class PdfRasterThumb extends StatefulWidget {
  const PdfRasterThumb({
    super.key,
    required this.bytes,
    required this.pageNumber,
    this.quarterTurns = 0,
    this.width = 100,
    this.height = 100,
  });

  final Uint8List bytes;
  /// 1-based
  final int pageNumber;
  final int quarterTurns;
  final double width;
  final double height;

  @override
  State<PdfRasterThumb> createState() => _PdfRasterThumbState();
}

class _PdfRasterThumbState extends State<PdfRasterThumb> {
  Uint8List? _pngBytes;
  bool _loading = true;
  bool _failed = false;

  String _pngCacheKey() {
    return '${identityHashCode(widget.bytes)}_'
        '${widget.pageNumber}_'
        '${widget.width.round()}_'
        '${widget.height.round()}';
  }

  @override
  void initState() {
    super.initState();
    final Uint8List? cached = _PdfRasterPngCache.get(_pngCacheKey());
    if (cached != null) {
      _pngBytes = cached;
      _loading = false;
      _failed = false;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(PdfRasterThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool bytesChanged = !identical(oldWidget.bytes, widget.bytes);
    final bool pageOrSizeChanged =
        oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height;
    // 회전(quarterTurns)만 바뀌면 재렌더 없이 RotatedBox만 갱신
    if (bytesChanged || pageOrSizeChanged) {
      final Uint8List? cached = _PdfRasterPngCache.get(_pngCacheKey());
      if (cached != null) {
        setState(() {
          _pngBytes = cached;
          _loading = false;
          _failed = false;
        });
      } else {
        _load();
      }
    }
  }

  Future<void> _load() async {
    final String cacheKey = _pngCacheKey();
    final Uint8List? cached = _PdfRasterPngCache.get(cacheKey);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _pngBytes = cached;
          _loading = false;
          _failed = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });
    _pngBytes = null;

    PdfDocument? doc;
    try {
      // 웹: pdfx가 동일 버퍼를 열면 ArrayBuffer detach → 2페이지 이후 썸네일 실패. 매번 독립 복사본으로 연다.
      final Uint8List dataCopy = Uint8List.fromList(widget.bytes);
      doc = await PdfDocument.openData(dataCopy);
      if (!mounted) {
        await doc.close();
        return;
      }
      if (widget.pageNumber < 1 || widget.pageNumber > doc.pagesCount) {
        throw StateError('invalid page ${widget.pageNumber} / ${doc.pagesCount}');
      }
      final PdfPage page = await doc.getPage(widget.pageNumber);
      try {
        final double pw = page.width;
        final double ph = page.height;
        final double boxW = widget.width;
        final double boxH = widget.height;
        late final double rw;
        late final double rh;
        if (pw <= 0 || ph <= 0) {
          rw = boxW;
          rh = boxH;
        } else {
          final double scale = math.min(boxW / pw, boxH / ph);
          rw = pw * scale;
          rh = ph * scale;
        }
        final PdfPageImage? rendered = await page.render(
          width: rw,
          height: rh,
          format: PdfPageImageFormat.png,
        );
        if (rendered?.bytes == null) {
          throw StateError('render null');
        }
        if (!mounted) {
          return;
        }
        final Uint8List png = rendered!.bytes;
        _PdfRasterPngCache.put(cacheKey, png);
        setState(() {
          _pngBytes = png;
          _loading = false;
          _failed = false;
        });
      } finally {
        await page.close();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } finally {
      if (doc != null && !doc.isClosed) {
        await doc.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: Colors.white,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _failed || _pngBytes == null
              ? Center(
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 36,
                    color: Colors.grey.shade400,
                  ),
                )
              : RotatedBox(
                  quarterTurns: widget.quarterTurns % 4,
                  child: Image.memory(
                    _pngBytes!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
        ),
      ),
    );
  }
}
