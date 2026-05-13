// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async' show StreamSubscription;
import 'dart:html' as html;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/browser_download.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import '../common/message_alert.dart';
import '../pdf/pdf_dropzone_pane_stub.dart'
    if (dart.library.html) '../pdf/pdf_dropzone_pane_web.dart';
import 'collage_export.dart';
import 'collage_frame_shapes.dart';
import 'work_tool_ui.dart';

/// 액자 상단 이동 바 높이 — UI와 PNG 내보내기 동일 기준
const double _kCollageFrameBarH = 26;

class _CollageLayer {
  _CollageLayer({
    required this.bytes,
    required this.l,
    required this.t,
    required this.w,
    required this.h,
    required this.frame,
  });

  final Uint8List bytes;
  double l;
  double t;
  double w;
  double h;
  CollageFrameKind frame;
  double panX = 0;
  double panY = 0;
  double zoom = 1.0;
  /// 미리보기·내보내기 공통: 캔버스 너비 기준 px에 가깝게 스케일 (0 = 테두리 없음)
  double borderWidth = 0;
  /// 액자 전체(이동 바 포함) 회전 — 라디안
  double rotation = 0;
}

class _FrameClipper extends CustomClipper<Path> {
  _FrameClipper(this.kind);

  final CollageFrameKind kind;

  @override
  Path getClip(Size size) {
    return CollageFrameShapes.buildPath(
      kind,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
  }

  @override
  bool shouldReclip(covariant _FrameClipper old) => old.kind != kind;
}

class ImageCollagePage extends StatefulWidget {
  const ImageCollagePage({super.key});

  @override
  State<ImageCollagePage> createState() => _ImageCollagePageState();
}

class _ImageCollagePageState extends State<ImageCollagePage> {
  static const int _kMaxLayers = 10;
  static const int _kMaxDrop = 10;

  final ScrollController _scrollThumb = ScrollController();
  StreamSubscription<html.Event>? _webDragEnterSub;
  StreamSubscription<html.Event>? _webDragEndSub;
  StreamSubscription<html.Event>? _webDropSub;
  bool _webDropOverlay = false;

  final List<_CollageLayer> _layers = <_CollageLayer>[];
  int? _selected;
  /// 드롭·일괄 추가 시 사용할 액자 모양 (좌측 아이콘으로 변경)
  CollageFrameKind _dropFrameKind = CollageFrameKind.rectangle;
  /// PNG 내보내기 시 캔버스 픽셀 크기
  double _lastCanvasPixelW = 400;
  /// 내보내기 시 상단 액자 바(26px) 환산용
  double _lastCanvasPixelH = 400;

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webDragEnterSub =
          html.document.onDragEnter.listen(_onWebDocumentDragEnter);
      _webDragEndSub =
          html.document.onDragEnd.listen((html.Event _) => _clearWebOverlay());
      _webDropSub =
          html.document.onDrop.listen((html.Event _) => _clearWebOverlay());
    }
  }

  void _onWebDocumentDragEnter(html.Event e) {
    if (_layers.length >= _kMaxLayers) {
      return;
    }
    final html.DataTransfer? dt =
        (e as dynamic).dataTransfer as html.DataTransfer?;
    if (dt == null) {
      return;
    }
    bool hasFiles = false;
    final Object? rawTypes = dt.types;
    if (rawTypes is Iterable<Object?>) {
      for (final Object? x in rawTypes) {
        if (x == 'Files') {
          hasFiles = true;
          break;
        }
      }
    }
    if (!hasFiles || !mounted) {
      return;
    }
    setState(() => _webDropOverlay = true);
  }

  void _clearWebOverlay() {
    if (!mounted) {
      return;
    }
    setState(() => _webDropOverlay = false);
  }

  @override
  void dispose() {
    _webDragEnterSub?.cancel();
    _webDragEndSub?.cancel();
    _webDropSub?.cancel();
    _scrollThumb.dispose();
    super.dispose();
  }

  bool _isImageName(String name) {
    final String lower = name.toLowerCase();
    for (final String e in WorkToolUi.imageExtensions) {
      if (lower.endsWith('.$e')) {
        return true;
      }
    }
    return false;
  }

  void _clampFrame(_CollageLayer L) {
    const double minS = 0.08;
    L.w = L.w.clamp(minS, 1.0);
    L.h = L.h.clamp(minS, 1.0);
    L.l = L.l.clamp(0.0, 1.0 - L.w);
    L.t = L.t.clamp(0.0, 1.0 - L.h);
    L.panX = L.panX.clamp(-1.0, 1.0);
    L.panY = L.panY.clamp(-1.0, 1.0);
    L.zoom = L.zoom.clamp(0.5, 3.0);
    L.borderWidth = L.borderWidth.clamp(0.0, 16.0);
    L.rotation = L.rotation.clamp(-math.pi, math.pi);
  }

  void _addBytes(List<Uint8List> bytesList) {
    if (bytesList.isEmpty) {
      return;
    }
    setState(() {
      int k = 0;
      for (final Uint8List b in bytesList) {
        if (_layers.length >= _kMaxLayers) {
          break;
        }
        if (b.isEmpty) {
          continue;
        }
        const double w = 0.38;
        const double h = 0.38;
        final double o = 0.04 * k++;
        final double baseL = (1.0 - w) / 2;
        final double baseT = (1.0 - h) / 2;
        _layers.add(
          _CollageLayer(
            bytes: b,
            l: (baseL + o).clamp(0.0, 1.0 - w),
            t: (baseT + o).clamp(0.0, 1.0 - h),
            w: w,
            h: h,
            frame: _dropFrameKind,
          ),
        );
        _clampFrame(_layers.last);
      }
      _selected = _layers.isEmpty ? null : _layers.length - 1;
      _webDropOverlay = false;
    });
  }

  void _addSingleCentered(Uint8List b, CollageFrameKind kind) {
    if (b.isEmpty || _layers.length >= _kMaxLayers) {
      return;
    }
    setState(() {
      const double w = 0.38;
      const double h = 0.38;
      final double l = (1.0 - w) / 2;
      final double t = (1.0 - h) / 2;
      _layers.add(
        _CollageLayer(
          bytes: b,
          l: l,
          t: t,
          w: w,
          h: h,
          frame: kind,
        ),
      );
      _clampFrame(_layers.last);
      _selected = _layers.length - 1;
      _webDropOverlay = false;
    });
  }

  Future<void> _pickOneWithFrame(CollageFrameKind kind) async {
    if (_layers.length >= _kMaxLayers) {
      showMessageAlert(context, message: '이미지는 최대 $_kMaxLayers장까지입니다.');
      return;
    }
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: WorkToolUi.imageExtensions,
      withData: true,
    );
    if (!mounted || r == null || r.files.isEmpty) {
      return;
    }
    final PlatformFile f = r.files.single;
    final Uint8List? b = f.bytes;
    if (b == null || b.isEmpty || !_isImageName(f.name)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _addSingleCentered(b, kind);
    });
  }

  void _onDropped(List<(String, Uint8List)> items) {
    final List<Uint8List> ok = <Uint8List>[];
    for (final (String name, Uint8List b) in items) {
      if (ok.length >= _kMaxDrop) {
        break;
      }
      if (b.isNotEmpty && _isImageName(name)) {
        ok.add(b);
      }
    }
    if (ok.isEmpty) {
      return;
    }
    _addBytes(ok);
  }

  Future<void> _pickMany() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: WorkToolUi.imageExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (r == null || r.files.isEmpty) {
      return;
    }
    final List<Uint8List> next = <Uint8List>[];
    for (final PlatformFile f in r.files) {
      final Uint8List? b = f.bytes;
      if (b != null && b.isNotEmpty && _isImageName(f.name)) {
        next.add(b);
      }
    }
    if (next.isEmpty) {
      return;
    }
    _addBytes(next);
  }

  void _deleteSelected() {
    final int? i = _selected;
    if (i == null || i < 0 || i >= _layers.length) {
      return;
    }
    setState(() {
      _layers.removeAt(i);
      _selected = null;
    });
  }

  void _bringForward() {
    final int? i = _selected;
    if (i == null || i >= _layers.length - 1) {
      return;
    }
    setState(() {
      final _CollageLayer x = _layers.removeAt(i);
      _layers.insert(i + 1, x);
      _selected = i + 1;
    });
  }

  void _sendBackward() {
    final int? i = _selected;
    if (i == null || i <= 0) {
      return;
    }
    setState(() {
      final _CollageLayer x = _layers.removeAt(i);
      _layers.insert(i - 1, x);
      _selected = i - 1;
    });
  }

  Future<void> _export() async {
    if (_layers.isEmpty || !kIsWeb) {
      showMessageAlert(context, message: '이미지를 추가하세요.');
      return;
    }
    if (_exporting) {
      return;
    }
    final double cw = _lastCanvasPixelW;
    final double ch = _lastCanvasPixelH;
    if (cw <= 8 || ch <= 8) {
      showMessageAlert(context, message: '캔버스 영역을 확인한 뒤 다시 시도하세요.');
      return;
    }
    setState(() => _exporting = true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    for (int i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    try {
      final CollageExportRequest req = CollageExportRequest(
        cw: cw,
        ch: ch,
        layers: _layers
            .map(
              (_CollageLayer L) => CollageExportLayer(
                bytes: L.bytes,
                l: L.l,
                t: L.t,
                w: L.w,
                h: L.h,
                rotation: L.rotation,
                panX: L.panX,
                panY: L.panY,
                zoom: L.zoom,
                borderWidth: L.borderWidth,
                frameKindIndex: L.frame.index,
              ),
            )
            .toList(),
      );
      late final Uint8List out;
      if (kIsWeb) {
        try {
          out = await Isolate.run(() => buildCollagePngBytes(req));
        } on Object {
          out = await buildCollagePngBytesYielding(req);
        }
      } else {
        out = await Isolate.run(() => buildCollagePngBytes(req));
      }
      downloadBytesInBrowser(
        out,
        'collage_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (mounted) {
        showMessageAlert(context, message: '콜라주를 저장했습니다.', title: '완료');
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  String _frameLabel(CollageFrameKind k) {
    switch (k) {
      case CollageFrameKind.rectangle:
        return '사각 액자';
      case CollageFrameKind.circle:
        return '원형 액자';
      case CollageFrameKind.heart:
        return '하트 액자';
      case CollageFrameKind.star:
        return '별 액자';
    }
  }

  Widget _frameKindIcon(CollageFrameKind k) {
    const double s = 22;
    switch (k) {
      case CollageFrameKind.rectangle:
        return const Icon(Icons.crop_square_rounded, size: s);
      case CollageFrameKind.circle:
        return const Icon(Icons.circle_outlined, size: s);
      case CollageFrameKind.heart:
        return const Icon(Icons.favorite_border_rounded, size: s);
      case CollageFrameKind.star:
        return const Icon(Icons.star_border_rounded, size: s);
    }
  }

  Widget _buildFrameRail(ThemeData theme) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: WorkToolUi.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '액자',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: WorkToolUi.muted,
              ),
            ),
            const SizedBox(height: 10),
            for (final CollageFrameKind k in CollageFrameKind.values) ...<Widget>[
              Tooltip(
                message: '${_frameLabel(k)} 추가',
                child: Material(
                  color: _dropFrameKind == k
                      ? const Color(0xFFEFF6FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      setState(() => _dropFrameKind = k);
                      _pickOneWithFrame(k);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconTheme(
                            data: IconThemeData(
                              color: _dropFrameKind == k
                                  ? WorkToolUi.navy
                                  : Colors.grey.shade600,
                              size: 24,
                            ),
                            child: _frameKindIcon(k),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            k == CollageFrameKind.rectangle
                                ? '사각'
                                : k == CollageFrameKind.circle
                                    ? '원'
                                    : k == CollageFrameKind.heart
                                        ? '하트'
                                        : '별',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _dropFrameKind == k
                                  ? WorkToolUi.navy
                                  : WorkToolUi.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            const Spacer(),
            Text(
              '탭: 해당 액자로\n이미지 추가',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: WorkToolUi.muted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool webOverlay =
        kIsWeb && _webDropOverlay && _layers.length < _kMaxLayers;
    final _CollageLayer? sel =
        _selected != null &&
                _selected! >= 0 &&
                _selected! < _layers.length
            ? _layers[_selected!]
            : null;

    return EnterpriseScaffold(
      title: '이미지 콜라주',
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _pickMany,
                icon: const Icon(Icons.collections_rounded, size: 20),
                label: const Text('이미지 추가'),
              ),
              if (sel != null)
                DropdownButton<CollageFrameKind>(
                  value: sel.frame,
                  items: CollageFrameKind.values
                      .map(
                        (CollageFrameKind k) => DropdownMenuItem(
                          value: k,
                          child: Text(_frameLabel(k)),
                        ),
                      )
                      .toList(),
                  onChanged: (CollageFrameKind? v) {
                    if (v != null && _selected != null) {
                      setState(() => _layers[_selected!].frame = v);
                    }
                  },
                ),
              IconButton.filledTonal(
                tooltip: '앞으로',
                onPressed: _selected != null ? _bringForward : null,
                icon: const Icon(Icons.flip_to_front_rounded),
              ),
              IconButton.filledTonal(
                tooltip: '뒤로',
                onPressed: _selected != null ? _sendBackward : null,
                icon: const Icon(Icons.flip_to_back_rounded),
              ),
              IconButton.filledTonal(
                tooltip: '삭제',
                onPressed: _selected != null ? _deleteSelected : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              FilledButton.icon(
                onPressed:
                    _layers.isNotEmpty && !_exporting ? _export : null,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('PNG 저장'),
                style: FilledButton.styleFrom(backgroundColor: WorkToolUi.navy),
              ),
            ],
          ),
          if (sel != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '선택 액자 안 사진: 확대 ${sel.zoom.toStringAsFixed(2)} · '
                    '이동은 액자 안을 드래그',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WorkToolUi.muted,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: sel.zoom,
              min: 0.5,
              max: 3.0,
              divisions: 25,
              label: sel.zoom.toStringAsFixed(2),
              onChanged: (double v) {
                setState(() {
                  _layers[_selected!].zoom = v;
                  _clampFrame(_layers[_selected!]);
                });
              },
            ),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 96,
                  child: Text(
                    '테두리 두께',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WorkToolUi.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: sel.borderWidth,
                    min: 0,
                    max: 16,
                    divisions: 16,
                    label: sel.borderWidth.round().toString(),
                    onChanged: (double v) {
                      setState(() {
                        _layers[_selected!].borderWidth = v;
                        _clampFrame(_layers[_selected!]);
                      });
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 96,
                  child: Text(
                    '회전',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WorkToolUi.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: sel.rotation * 180 / math.pi,
                    min: -180,
                    max: 180,
                    divisions: 120,
                    label:
                        '${(sel.rotation * 180 / math.pi).round()}°',
                    onChanged: (double v) {
                      setState(() {
                        _layers[_selected!].rotation = v * math.pi / 180;
                        _clampFrame(_layers[_selected!]);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '좌측 액자를 누르면 해당 모양으로 이미지를 추가합니다(최대 $_kMaxLayers장). '
            '드롭 시 선택된 액자 모양이 적용됩니다. 액자를 드래그해 옮기고 우하단으로 크기 조절, '
            '액자 안을 드래그하면 사진 위치를 조절합니다. 선택 후 회전·테두리를 조절할 수 있습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: WorkToolUi.muted,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildFrameRail(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints bc) {
                      return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: WorkToolUi.cardDecoration(
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (_layers.isEmpty)
                          Positioned.fill(
                            child: PdfDropzonePane(
                              maxFiles: _kMaxDrop,
                              allowedExtensions: WorkToolUi.imageExtensions,
                              onPdfDropped: _onDropped,
                            ),
                          ),
                        if (_layers.isEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.filter_frames_rounded,
                                      size: 56,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '이미지를 드롭하여 액자에 넣기',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_layers.isNotEmpty)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints c) {
                                final double cw = c.maxWidth;
                                final double ch = c.maxHeight;
                                _lastCanvasPixelW = cw;
                                _lastCanvasPixelH = ch;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selected = null),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: <Widget>[
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _CollageCheckerPainter(),
                                        ),
                                      ),
                                      Container(
                                    width: cw,
                                    height: ch,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: WorkToolUi.border,
                                      ),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: Stack(
                                      children: <Widget>[
                                        for (int i = 0;
                                            i < _layers.length;
                                            i++)
                                          _FramedLayerView(
                                            key: ValueKey<int>(i),
                                            layer: _layers[i],
                                            selected: _selected == i,
                                            canvasW: cw,
                                            canvasH: ch,
                                            onSelect: () =>
                                                setState(() => _selected = i),
                                            onFrameChanged: () {
                                              _clampFrame(_layers[i]);
                                              setState(() {});
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        if (webOverlay && _layers.isNotEmpty)
                          Positioned.fill(
                            child: Material(
                              color: const Color(0x331E3A8A),
                              child: PdfDropzonePane(
                                maxFiles: _kMaxDrop,
                                allowedExtensions: WorkToolUi.imageExtensions,
                                scrollController: _scrollThumb,
                                onPdfDropped: (List<(String, Uint8List)> it) {
                                  _onDropped(it);
                                  _clearWebOverlay();
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
          if (_exporting)
            Positioned.fill(
              child: AbsorbPointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.22),
                  ),
                  child: Center(
                    child: LoadingWidget(
                      size: 88,
                      duration: const Duration(seconds: 3),
                      text: 'PNG 저장 중…',
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FramedLayerView extends StatefulWidget {
  const _FramedLayerView({
    super.key,
    required this.layer,
    required this.selected,
    required this.canvasW,
    required this.canvasH,
    required this.onSelect,
    required this.onFrameChanged,
  });

  final _CollageLayer layer;
  final bool selected;
  final double canvasW;
  final double canvasH;
  final VoidCallback onSelect;
  final VoidCallback onFrameChanged;

  @override
  State<_FramedLayerView> createState() => _FramedLayerViewState();
}

class _FramedLayerViewState extends State<_FramedLayerView> {
  bool _dragResize = false;

  @override
  Widget build(BuildContext context) {
    final _CollageLayer L = widget.layer;
    final double fw = L.w * widget.canvasW;
    final double fh = L.h * widget.canvasH;
    final double innerH = math.max(fh - _kCollageFrameBarH, 8);
    return Positioned(
      left: L.l * widget.canvasW,
      top: L.t * widget.canvasH,
      width: fw,
      height: fh,
      child: Transform.rotate(
        angle: L.rotation,
        alignment: Alignment.center,
        child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSelect,
                onPanUpdate: (DragUpdateDetails d) {
                  if (_dragResize) {
                    return;
                  }
                  widget.onSelect();
                  L.l += d.delta.dx / widget.canvasW;
                  L.t += d.delta.dy / widget.canvasH;
                  widget.onFrameChanged();
                },
                child: Material(
                  color: widget.selected
                      ? const Color(0xFFE0E7FF)
                      : const Color(0xFFF1F5F9),
                  child: SizedBox(
                    height: _kCollageFrameBarH,
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '액자 이동',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ClipPath(
                  clipper: _FrameClipper(L.frame),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSelect,
                    onPanUpdate: (DragUpdateDetails d) {
                      L.panX += d.delta.dx / math.max(fw, 1) * 2.2;
                      L.panY += d.delta.dy / math.max(innerH, 1) * 2.2;
                      L.panX = L.panX.clamp(-1.0, 1.0);
                      L.panY = L.panY.clamp(-1.0, 1.0);
                      widget.onFrameChanged();
                    },
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment(L.panX, L.panY),
                      child: Transform.scale(
                        scale: L.zoom,
                        alignment: Alignment.center,
                        child: Image.memory(L.bytes),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (L.borderWidth > 0 || widget.selected)
            Positioned(
              top: _kCollageFrameBarH,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FrameBorderPainter(
                    L.frame,
                    L.borderWidth > 0
                        ? L.borderWidth
                        : (widget.selected ? 1.0 : 0.0),
                  ),
                ),
              ),
            ),
          if (widget.selected)
            Positioned(
              right: 2,
              bottom: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  widget.onSelect();
                  setState(() => _dragResize = true);
                },
                onPanUpdate: (DragUpdateDetails d) {
                  L.w += d.delta.dx / widget.canvasW;
                  L.h += d.delta.dy / widget.canvasH;
                  widget.onFrameChanged();
                },
                onPanEnd: (_) => setState(() => _dragResize = false),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: WorkToolUi.navy, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.open_in_full_rounded, size: 12),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// 액자 외곽선 (클립은 ClipPath가 담당)
class _FrameBorderPainter extends CustomPainter {
  _FrameBorderPainter(this.kind, this.strokeWidth);

  final CollageFrameKind kind;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) {
      return;
    }
    final Path p = CollageFrameShapes.buildPath(
      kind,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    final Paint paint = Paint()
      ..color = WorkToolUi.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _FrameBorderPainter old) =>
      old.kind != kind || old.strokeWidth != strokeWidth;
}

/// 캔버스 투명 영역 미리보기
class _CollageCheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double tile = 10;
    final Paint light = Paint()..color = const Color(0xFFE0E0E0);
    final Paint dark = Paint()..color = const Color(0xFFCFCFCF);
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        final bool isLight =
            ((x ~/ tile) + (y ~/ tile)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tile, tile),
          isLight ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CollageCheckerPainter old) => false;
}
