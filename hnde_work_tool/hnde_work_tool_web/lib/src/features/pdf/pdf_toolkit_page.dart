// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async' show StreamSubscription;
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reorderables/reorderables.dart';

import 'pdf_dropzone_pane_stub.dart'
if (dart.library.html) 'pdf_dropzone_pane_web.dart';

import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import '../common/message_alert.dart';
import 'pdf_raster_thumb.dart';
import 'pdf_syncfusion_helper.dart';
import 'pdf_toolkit_models.dart';

const Color _navy = Color(0xFF1E3A8A);

/// Web/데스크톱에서 [Scrollbar]로 감싼 뒤 내부 [Scrollable]이 또 스크롤바를 그리는 이중 표시 방지.
class _SingleScrollbarBehavior extends MaterialScrollBehavior {
  const _SingleScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// 파일/페이지 썸네일 타일 (고정)
const double _kPdfTileW = 112;
/// 분할 도구: 페이지 타일에 회전·삭제 버튼 포함
const double _kSplitTileH = 188;
const double _kPdfViewerBox = 100;

/// 좌측 세부설정 패널 (펼침 / 접힘 레일)
const double _kSettingsSideOpen = 300;
const double _kSettingsSideClosed = 52;

class _SplitRangeRow {
  _SplitRangeRow({required this.id, this.startPage = 0, this.endPage = 0});
  final int id;
  int startPage;
  int endPage;
}

/// PDF 합치기 또는 분할 단일 도구 (라우트별로 [tool] 고정)
class PdfToolkitPage extends StatefulWidget {
  const PdfToolkitPage({super.key, required this.tool});

  final PdfToolkitTool tool;

  @override
  State<PdfToolkitPage> createState() => _PdfToolkitPageState();
}

class _PdfToolkitPageState extends State<PdfToolkitPage> {
  final ScrollController _scrollFileColumn = ScrollController();
  final ScrollController _scrollSettingsColumn = ScrollController();

  final List<PdfLoadedDoc> _docs = <PdfLoadedDoc>[];
  int _nextRangeId = 1;
  final List<_SplitRangeRow> _splitRanges = <_SplitRangeRow>[];
  /// PDF 합치기: 파일 합칠 순서 (`_docs` 인덱스, 드래그로 변경)
  List<int> _mergeDocOrder = <int>[];
  /// 저장 시 A4 세로/가로 (회전 상태 유지·비율 맞춤)
  PdfPageOrientation _pageOutputOrientation = PdfPageOrientation.portrait;

  /// merge: 펼친 파일의 페이지 스트립 (null이면 닫힘)
  /// 썸네일 탭 시 전체 영역 확대 (doc 인덱스, 문서 내 0-based 페이지)
  int? _pdfZoomDocIndex;
  int? _pdfZoomPageIndex;
  bool _settingsPanelOpen = true;
  bool _loading = false;
  /// 로딩 오버레이에 표시 (예: 저장 중입니다)
  String _loadingMessage = '';
  int _progCur = 0;
  int _progTotal = 0;

  /// 웹: OS에서 PDF 파일을 끌어오는 동안 패널 전체에 드롭 오버레이(iLovePDF 스타일)
  StreamSubscription<html.Event>? _webGlobalDragEnterSub;
  StreamSubscription<html.Event>? _webGlobalDragEndSub;
  StreamSubscription<html.Event>? _webGlobalDropSub;
  bool _webPanelDropOverlay = false;

  @override
  void initState() {
    super.initState();
    _splitRanges.add(
      _SplitRangeRow(id: _nextRangeId++, startPage: 0, endPage: 0),
    );
    if (kIsWeb) {
      _webGlobalDragEnterSub =
          html.document.onDragEnter.listen(_onWebDocumentDragEnter);
      _webGlobalDragEndSub =
          html.document.onDragEnd.listen((html.Event _) {
        _clearWebDropOverlay();
      });
      _webGlobalDropSub = html.document.onDrop.listen((html.Event _) {
        _clearWebDropOverlay();
      });
    }
  }

  bool _webCanAddMorePdfs() {
    return _docs.length < _maxFilesFor(widget.tool);
  }

  void _onWebDocumentDragEnter(html.Event e) {
    if (!_webCanAddMorePdfs()) {
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
    if (!hasFiles) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _webPanelDropOverlay = true);
  }

  void _clearWebDropOverlay() {
    if (!mounted) {
      return;
    }
    setState(() => _webPanelDropOverlay = false);
  }

  @override
  void dispose() {
    _webGlobalDragEnterSub?.cancel();
    _webGlobalDragEndSub?.cancel();
    _webGlobalDropSub?.cancel();
    _scrollFileColumn.dispose();
    _scrollSettingsColumn.dispose();
    super.dispose();
  }

  int _maxFilesFor(PdfToolkitTool t) {
    if (t == PdfToolkitTool.split) {
      return 1;
    }
    return t.maxFiles;
  }

  void _resetWorkspace() {
    setState(() {
      _docs.clear();
      _pdfZoomDocIndex = null;
      _pdfZoomPageIndex = null;
      _mergeDocOrder = <int>[];
      _pageOutputOrientation = PdfPageOrientation.portrait;
      _nextRangeId = 1;
      _splitRanges
        ..clear()
        ..add(_SplitRangeRow(id: _nextRangeId++, startPage: 0, endPage: 0));
    });
  }

  void _applyDocuments(List<PdfLoadedDoc> next, PdfToolkitTool t) {
    if (next.isEmpty) {
      return;
    }
    final int maxF = _maxFilesFor(t);
    setState(() {
      if (t == PdfToolkitTool.split) {
        _docs
          ..clear()
          ..addAll(next.take(1));
      } else {
        _docs.addAll(next);
        if (_docs.length > maxF) {
          _docs.removeRange(maxF, _docs.length);
        }
      }
      if (t == PdfToolkitTool.merge) {
        _syncMergeDocOrderAfterDocsChange();
      }
    });
  }

  List<PdfLoadedDoc> _tryLoadDocsFromBytes(
    List<(String name, Uint8List bytes)> items,
  ) {
    final List<PdfLoadedDoc> next = <PdfLoadedDoc>[];
    for (final (String name, Uint8List b) in items) {
      if (b.isEmpty) {
        continue;
      }
      final PdfLoadedDoc d = PdfLoadedDoc(name: name, bytes: b);
      try {
        d.initPageArrays();
      } catch (_) {
        showMessageAlert(context, message: 'PDF를 열 수 없습니다: $name');
        continue;
      }
      next.add(d);
    }
    return next;
  }

  Future<void> _pickFiles() async {
    final PdfToolkitTool t = widget.tool;
    final int maxF = _maxFilesFor(t);
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      allowMultiple: t != PdfToolkitTool.split,
      withData: kIsWeb,
    );
    if (!mounted) {
      return;
    }
    if (r == null || r.files.isEmpty) {
      return;
    }
    final List<PlatformFile> incoming = r.files;
    final int cap = incoming.length > maxF ? maxF : incoming.length;
    if (incoming.length > maxF) {
      showMessageAlert(
        context,
        message: '최대 $maxF개까지 선택됩니다. 앞의 $maxF개만 반영했습니다.',
      );
    }
    final List<(String, Uint8List)> raw = <(String, Uint8List)>[];
    for (int i = 0; i < cap; i++) {
      final PlatformFile f = incoming[i];
      final Uint8List? b = f.bytes;
      if (b == null || b.isEmpty) {
        continue;
      }
      raw.add((f.name, b));
    }
    final List<PdfLoadedDoc> next = _tryLoadDocsFromBytes(raw);
    _applyDocuments(next, t);
  }

  void _onPdfDroppedFromZone(List<(String, Uint8List)> incoming) {
    final PdfToolkitTool t = widget.tool;
    if (incoming.isEmpty) {
      return;
    }
    final int maxF = _maxFilesFor(t);
    List<(String, Uint8List)> raw = incoming;
    if (raw.length > maxF) {
      showMessageAlert(
        context,
        message: '최대 $maxF개까지 반영됩니다. 앞의 $maxF개만 추가했습니다.',
      );
      raw = raw.sublist(0, maxF);
    }
    final List<PdfLoadedDoc> next = _tryLoadDocsFromBytes(raw);
    _applyDocuments(next, t);
  }

  /// 문서 목록이 바뀌면 기존 순서를 유지하고, 새 파일은 끝에 붙인다.
  void _syncMergeDocOrderAfterDocsChange() {
    final Set<int> used = <int>{};
    final List<int> next = <int>[];
    for (final int di in _mergeDocOrder) {
      if (di >= 0 && di < _docs.length && !used.contains(di)) {
        used.add(di);
        next.add(di);
      }
    }
    for (int d = 0; d < _docs.length; d++) {
      if (!used.contains(d)) {
        next.add(d);
      }
    }
    _mergeDocOrder = next;
  }

  /// [reorderables] `ReorderableWrap`은 "start를 end 앞 슬롯으로" 옮기며,
  /// 맨 끝으로 둘 때 `newIndex == length`(원본 기준)처럼 넘어올 수 있음.
  /// `removeAt` 이후 유효 범위는 `0..length`(끝에 붙이기)이므로 클램프한다.
  void _reorderMergeDocOrder(int oldIndex, int newIndex) {
    setState(() {
      final int item = _mergeDocOrder.removeAt(oldIndex);
      final int len = _mergeDocOrder.length;
      final int insertAt = newIndex.clamp(0, len);
      _mergeDocOrder.insert(insertAt, item);
    });
  }

  void _removeDocFromMerge(int docIndex) {
    if (docIndex < 0 || docIndex >= _docs.length) {
      return;
    }
    setState(() {
      _docs.removeAt(docIndex);
      _mergeDocOrder = _mergeDocOrder
          .where((int di) => di != docIndex)
          .map((int di) => di > docIndex ? di - 1 : di)
          .toList();
      if (_pdfZoomDocIndex != null) {
        final int? z = _pdfZoomDocIndex;
        if (z == docIndex) {
          _pdfZoomDocIndex = null;
          _pdfZoomPageIndex = null;
        } else if (z != null && z > docIndex) {
          _pdfZoomDocIndex = z - 1;
        }
      }
    });
  }

  /// 반투명 로딩 레이어가 한 번 그려진 뒤 무거운 작업을 시작해 UI가 멈춘 것처럼 보이지 않게 함
  Future<void> _waitForLoadingOverlayPaint() async {
    await Future<void>.delayed(Duration.zero);
    if (mounted) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _runWithProgress(
    Future<void> Function() work, {
    required int total,
    String loadingMessage = '저장 중입니다…',
  }) async {
    setState(() {
      _loading = true;
      _loadingMessage = loadingMessage;
      _progCur = 0;
      _progTotal = total;
    });
    await _waitForLoadingOverlayPaint();
    try {
      await work();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMessage = '';
          _progCur = 0;
          _progTotal = 0;
        });
      }
    }
  }

  void _downloadBytes(Uint8List bytes, String fileName) {
    if (!kIsWeb) {
      return;
    }
    final html.Blob blob = html.Blob(<dynamic>[bytes]);
    final String url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _saveMerge() async {
    if (_docs.isEmpty) {
      showMessageAlert(context, message: 'PDF 파일을 추가하세요.');
      return;
    }
    if (_mergeDocOrder.isEmpty) {
      showMessageAlert(context, message: '합칠 파일 순서가 비어 있습니다.');
      return;
    }
    await _runWithProgress(
      () async {
        try {
          final List<Uint8List> inputs =
              _docs.map((PdfLoadedDoc d) => d.bytes).toList();
          final List<String> names =
              _docs.map((PdfLoadedDoc d) => d.name).toList();
          final List<List<int>> rotations = _docs
              .map((PdfLoadedDoc d) => List<int>.from(d.quarterTurns))
              .toList();
          final List<List<bool>> skip = _docs
              .map((PdfLoadedDoc d) => List<bool>.from(d.pageRemoved))
              .toList();
          final Uint8List out = await PdfSyncfusionHelper.mergeAll(
            inputs,
            names,
            order: List<int>.from(_mergeDocOrder),
            rotations: rotations,
            skipPage: skip,
            outputLandscape:
                _pageOutputOrientation == PdfPageOrientation.landscape,
          );
          if (!mounted) {
            return;
          }
          setState(() => _progCur = 1);
          _downloadBytes(
            out,
            'merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
        } catch (e, st) {
          debugPrint('merge save failed: $e\n$st');
          if (mounted) {
            await showMessageAlert(
              context,
              title: '저장 실패',
              message: 'PDF를 만드는 중 오류가 났습니다: $e',
            );
          }
        }
      },
      total: 1,
    );
  }

  Future<void> _saveSplit() async {
    if (_docs.length != 1) {
      showMessageAlert(context, message: '분할은 PDF 1개만 선택하세요.');
      return;
    }
    final PdfLoadedDoc d = _docs.first;
    final List<(int, int)> ranges = <(int, int)>[];
    for (final _SplitRangeRow row in _splitRanges) {
      final int lo = row.startPage < row.endPage ? row.startPage : row.endPage;
      final int hi = row.startPage < row.endPage ? row.endPage : row.startPage;
      final int start = lo.clamp(0, d.pageCount - 1);
      final int end = hi.clamp(0, d.pageCount - 1);
      ranges.add((start, end));
    }
    if (ranges.isEmpty) {
      showMessageAlert(context, message: '구간을 입력하세요.');
      return;
    }
    await _runWithProgress(
      () async {
        final Uint8List zip = await PdfSyncfusionHelper.splitToZip(
          d.bytes,
          ranges: ranges,
          quarterTurns: List<int>.from(d.quarterTurns),
          pageSkip: List<bool>.from(d.pageRemoved),
          outputLandscape:
              _pageOutputOrientation == PdfPageOrientation.landscape,
        );
        if (!mounted) {
          return;
        }
        setState(() => _progCur = 1);
        _downloadBytes(zip, 'split_${DateTime.now().millisecondsSinceEpoch}.zip');
      },
      total: 1,
    );
  }

  Future<void> _primaryAction() async {
    final PdfToolkitTool t = widget.tool;
    switch (t) {
      case PdfToolkitTool.merge:
        await _saveMerge();
        break;
      case PdfToolkitTool.split:
        await _saveSplit();
        break;
    }
  }

  String _primaryButtonLabel(PdfToolkitTool t) {
    switch (t) {
      case PdfToolkitTool.merge:
      case PdfToolkitTool.split:
        return '저장';
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: widget.tool.label,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _buildToolWorkspace(),
          ),
          if (_loading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  /// 좌측 접이식 세부설정 + 우측 파일 영역
  Widget _buildToolWorkspace() {
    final PdfToolkitTool t = widget.tool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildTopToolBar(t),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final bool wide = c.maxWidth >= 900;
                final Widget filePane = _buildFileColumn(t);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeInOut,
                        width: _settingsPanelOpen
                            ? _kSettingsSideOpen
                            : _kSettingsSideClosed,
                        child: _buildSettingsSidebar(t, verticalRail: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: filePane),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOut,
                      height: _settingsPanelOpen ? 240 : _kSettingsSideClosed,
                      child: _buildSettingsSidebar(t, verticalRail: false),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: filePane),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSidebar(PdfToolkitTool t, {required bool verticalRail}) {
    if (!_settingsPanelOpen) {
      return Material(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _settingsPanelOpen = true),
          child: verticalRail
              ? Column(
                  children: <Widget>[
                    const SizedBox(height: 12),
                    IconButton(
                      tooltip: '세부 설정 펼치기',
                      onPressed: () =>
                          setState(() => _settingsPanelOpen = true),
                      icon: const Icon(Icons.tune_rounded, size: 24),
                    ),
                    const SizedBox(height: 8),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        '설정',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    const SizedBox(width: 12),
                    const Icon(Icons.tune_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '세부 설정',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.expand_more_rounded, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                  ],
                ),
        ),
      );
    }
    return _buildSettingsColumn(t);
  }

  Widget _buildLoadingOverlay() {
    final String title =
        _loadingMessage.isNotEmpty ? _loadingMessage : '처리 중입니다…';
    return Positioned.fill(
      child: AbsorbPointer(
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const LoadingWidget(
                    size: 72,
                    duration: Duration(milliseconds: 1000),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (_progTotal > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '$_progCur / $_progTotal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopToolBar(PdfToolkitTool current) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(current.icon, color: _navy, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                current.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                current.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _resetWorkspace,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('초기화'),
        ),
      ],
    );
  }

  Widget _buildFileColumn(PdfToolkitTool t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '파일',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.upload_file_rounded, size: 20),
            label: Text(
              t == PdfToolkitTool.split
                  ? 'PDF 1개 선택'
                  : 'PDF 선택 (최대 ${_maxFilesFor(t)}개)',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildUnifiedDropAndThumbs(t)),
        ],
      ),
    );
  }

  /// 드롭 레이어 전체 + 좌상단부터 Wrap 고정썸네일 (추가 시 뒤에 순서대로)
  Widget _buildUnifiedDropAndThumbs(PdfToolkitTool t) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double h =
            c.maxHeight.isFinite && c.maxHeight > 0 ? c.maxHeight : 280;
        final bool canAddMore = _docs.length < _maxFilesFor(t);
        final bool webDropOverlay =
            kIsWeb && canAddMore && _webPanelDropOverlay;

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_docs.isEmpty)
                Positioned.fill(
                  child: PdfDropzonePane(
                    maxFiles: _maxFilesFor(t),
                    allowedExtensions: null,
                    onPdfDropped: _onPdfDroppedFromZone,
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _docs.isEmpty,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0x0A1E293B),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: const _SingleScrollbarBehavior(),
                          child: Scrollbar(
                            controller: _scrollFileColumn,
                            thumbVisibility: true,
                            child: _docs.isEmpty
                                ? SingleChildScrollView(
                                    controller: _scrollFileColumn,
                                    padding: const EdgeInsets.all(10),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minHeight: h),
                                      child: IgnorePointer(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: h * 0.12,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Icon(
                                                Icons.cloud_upload_outlined,
                                                size: 40,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                '이 영역 전체에 PDF를 드래그하여 놓기\n(웹) 또는 파일 선택',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : t == PdfToolkitTool.merge
                                ? Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: _buildMergeFlatPagesArea(),
                                  )
                                : SingleChildScrollView(
                                    controller: _scrollFileColumn,
                                    padding: const EdgeInsets.all(10),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minHeight: h),
                                      child: _buildSplitPageArea(t),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
              if (webDropOverlay)
                Positioned.fill(
                  child: Material(
                    color: const Color(0x331E3A8A),
                    child: PdfDropzonePane(
                      maxFiles: _maxFilesFor(t),
                      allowedExtensions: null,
                      scrollController: _scrollFileColumn,
                      onPdfDropped: (List<(String, Uint8List)> items) {
                        _onPdfDroppedFromZone(items);
                        _clearWebDropOverlay();
                      },
                    ),
                  ),
                ),
              if (_pdfZoomDocIndex != null &&
                  _pdfZoomPageIndex != null &&
                  _docs.isNotEmpty)
                Positioned.fill(
                  child: _buildPdfZoomOverlay(c),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 썸네일 탭 시 전체 영역 확대 미리보기 (배경 탭 또는 닫기로 종료)
  Widget _buildPdfZoomOverlay(BoxConstraints c) {
    final int? di = _pdfZoomDocIndex;
    final int? pi = _pdfZoomPageIndex;
    if (di == null || pi == null || di < 0 || di >= _docs.length) {
      return const SizedBox.shrink();
    }
    final PdfLoadedDoc d = _docs[di];
    if (pi < 0 || pi >= d.pageCount || d.pageRemoved[pi]) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pdfZoomDocIndex = null;
            _pdfZoomPageIndex = null;
          });
        }
      });
      return const SizedBox.shrink();
    }

    void closeZoom() {
      setState(() {
        _pdfZoomDocIndex = null;
        _pdfZoomPageIndex = null;
      });
    }

    final double maxW = math.max(240.0, c.maxWidth - 24);
    final double maxH = math.max(240.0, c.maxHeight - 24);
    final double boxW = maxW;
    final double boxH = math.min(maxH, boxW * 1.35);

    final String subLine = 'p${pi + 1} · 탭하여 닫기';

    Widget previewBox() {
      return PdfRasterThumb(
        key: ValueKey<String>('zoom_${di}_${pi}_${d.name}'),
        bytes: d.bytes,
        pageNumber: pi + 1,
        quarterTurns: d.quarterTurns[pi],
        width: boxW,
        height: boxH,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: closeZoom,
      child: Material(
        color: Colors.black.withValues(alpha: 0.58),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints inner) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: inner.maxWidth,
                    minHeight: inner.maxHeight,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          d.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subLine,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: boxW,
                          height: boxH,
                          child: previewBox(),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: closeZoom,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            '닫기',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// PDF 합치기: 파일 단위로 나열·드래그 순서 변경 (각 파일 첫 페이지만 미리보기)
  Widget _buildMergeFlatPagesArea() {
    return ReorderableWrap(
      controller: _scrollFileColumn,
      spacing: 10,
      runSpacing: 10,
      padding: EdgeInsets.zero,
      needsLongPressDraggable: false,
      onReorder: _reorderMergeDocOrder,
      children: <Widget>[
        for (int i = 0; i < _mergeDocOrder.length; i++)
          KeyedSubtree(
            key: ValueKey<String>('mg_doc_${_mergeDocOrder[i]}'),
            child: _buildMergeDocTile(_mergeDocOrder[i]),
          ),
      ],
    );
  }

  Widget _buildMergeDocTile(int docIndex) {
    final PdfLoadedDoc d = _docs[docIndex];
    final int previewPage = d.pageCount > 0 ? 1 : 0;
    final int q0 =
        d.pageCount > 0 ? d.quarterTurns[0].clamp(0, 3) : 0;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _kPdfTileW,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.drag_indicator_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 2),
            if (previewPage > 0)
              _TappableThumbOverlay(
                onTapExpand: () {
                  setState(() {
                    _pdfZoomDocIndex = docIndex;
                    _pdfZoomPageIndex = 0;
                  });
                },
                child: PdfRasterThumb(
                  key: ValueKey<String>('mgth_${docIndex}_p1_$q0'),
                  bytes: d.bytes,
                  pageNumber: 1,
                  quarterTurns: q0,
                  width: _kPdfViewerBox,
                  height: _kPdfViewerBox,
                ),
              )
            else
              SizedBox(
                width: _kPdfViewerBox,
                height: _kPdfViewerBox,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Colors.grey.shade500,
                    size: 36,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Tooltip(
              message: d.name,
              waitDuration: const Duration(milliseconds: 400),
              child: Text(
                d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  height: 1.15,
                ),
              ),
            ),
            Text(
              d.pageCount > 0 ? '총 ${d.pageCount}페이지' : '페이지 없음',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade600,
                height: 1.15,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  tooltip: '이 파일 전체 90° 회전',
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
                  onPressed: d.pageCount > 0
                      ? () {
                          setState(() {
                            d.rotateAllPages();
                          });
                        }
                      : null,
                  icon: Icon(
                    Icons.rotate_right_rounded,
                    size: 18,
                    color: d.pageCount > 0
                        ? Colors.grey.shade700
                        : Colors.grey.shade400,
                  ),
                ),
                IconButton(
                  tooltip: '목록에서 제거',
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
                  onPressed: () => _removeDocFromMerge(docIndex),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitPageArea(PdfToolkitTool t) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: _buildSplitPageThumbWidgets(t),
      ),
    );
  }

  List<Widget> _buildSplitPageThumbWidgets(PdfToolkitTool t) {
    final PdfLoadedDoc d = _docs.first;
    final List<Widget> w = <Widget>[];
    for (int pi = 0; pi < d.pageCount; pi++) {
      if (d.pageRemoved[pi]) {
        continue;
      }
      w.add(_buildSplitPageThumbTile(t, pi));
    }
    return w;
  }

  Widget _buildSplitPageThumbTile(PdfToolkitTool t, int pageIndex) {
    final PdfLoadedDoc d = _docs.first;
    return Tooltip(
      message: '${pageIndex + 1}페이지',
      child: Container(
        width: _kPdfTileW,
        height: _kSplitTileH,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${pageIndex + 1}p',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 2),
            _TappableThumbOverlay(
              onTapExpand: () {
                setState(() {
                  _pdfZoomDocIndex = 0;
                  _pdfZoomPageIndex = pageIndex;
                });
              },
              child: PdfRasterThumb(
                key: ValueKey<String>('spt_$pageIndex'),
                bytes: d.bytes,
                pageNumber: pageIndex + 1,
                quarterTurns: d.quarterTurns[pageIndex],
                width: _kPdfViewerBox,
                height: _kPdfViewerBox,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  tooltip: '90° 회전',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    setState(() {
                      d.rotateAt(pageIndex);
                    });
                  },
                  icon: const Icon(Icons.rotate_right_rounded, size: 18),
                ),
                IconButton(
                  tooltip: '페이지 삭제',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () async {
                    final bool? ok = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext ctx) {
                        return AlertDialog(
                          title: const Text('페이지 삭제'),
                          content: Text('${pageIndex + 1}페이지를 삭제할까요?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('취소'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('삭제'),
                            ),
                          ],
                        );
                      },
                    );
                    if (ok == true) {
                      setState(() {
                        d.pageRemoved[pageIndex] = true;
                      });
                    }
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsColumn(PdfToolkitTool t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '세부 설정',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '접기',
                onPressed: () {
                  setState(() => _settingsPanelOpen = false);
                },
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Scrollbar(
              controller: _scrollSettingsColumn,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollSettingsColumn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildToolSettings(t),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _docs.isEmpty ? null : _primaryAction,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: Text(_primaryButtonLabel(t)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGlobalOutputSettingsWidgets() {
    if (_docs.isEmpty) {
      return <Widget>[];
    }
    return <Widget>[
      const Text('출력 용지', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      SegmentedButton<PdfPageOrientation>(
        segments: const <ButtonSegment<PdfPageOrientation>>[
          ButtonSegment<PdfPageOrientation>(
            value: PdfPageOrientation.portrait,
            label: Text('세로'),
            icon: Icon(Icons.crop_portrait_rounded, size: 16),
          ),
          ButtonSegment<PdfPageOrientation>(
            value: PdfPageOrientation.landscape,
            label: Text('가로'),
            icon: Icon(Icons.crop_landscape_rounded, size: 16),
          ),
        ],
        selected: <PdfPageOrientation>{_pageOutputOrientation},
        onSelectionChanged: (Set<PdfPageOrientation> next) {
          setState(() => _pageOutputOrientation = next.single);
        },
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () {
          setState(() {
            for (final PdfLoadedDoc d in _docs) {
              for (int pi = 0; pi < d.pageCount; pi++) {
                if (!d.pageRemoved[pi]) {
                  d.rotateAt(pi);
                }
              }
            }
          });
        },
        icon: const Icon(Icons.rotate_right_rounded, size: 18),
        label: const Text('전체 90° 회전 (모든 페이지)'),
      ),

      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildToolSettings(PdfToolkitTool t) {
    final List<Widget> g = _buildGlobalOutputSettingsWidgets();
    switch (t) {
      case PdfToolkitTool.merge:
        return <Widget>[
          ...g,
          Text(
            '파일마다 첫 페이지만 미리보기로 보입니다. 드래그하여 PDF 통째로 합칠 순서를 바꿉니다. '
            '회전 아이콘은 해당 파일의 모든 페이지에 90°씩 적용됩니다. '
            '저장 시 각 파일의 모든 페이지가 순서대로 이어집니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),
        ];
      case PdfToolkitTool.split:
        return <Widget>[
          ...g,
          const Text(
            '분할 구간 (0부터 시작하는 페이지 번호)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final _SplitRangeRow row in _splitRanges)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SplitRangeRowWidget(
                key: ValueKey<int>(row.id),
                row: row,
                canRemove: _splitRanges.length > 1,
                onRemove: _splitRanges.length > 1
                    ? () {
                        setState(() {
                          _splitRanges.removeWhere(
                            (_SplitRangeRow r) => r.id == row.id,
                          );
                        });
                      }
                    : null,
              ),
            ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _splitRanges.add(
                  _SplitRangeRow(
                    id: _nextRangeId++,
                    startPage: 0,
                    endPage: 0,
                  ),
                );
              });
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('구간 추가'),
          ),
        ];
    }
  }
}

/// 대시보드 [280×100] 스타일 — 좌 아이콘 · 우 텍스트
/// 미리보기: 호버 시 돋보기, 탭 시 전체 영역 확대
class _TappableThumbOverlay extends StatefulWidget {
  const _TappableThumbOverlay({
    required this.child,
    required this.onTapExpand,
  });

  final Widget child;
  final VoidCallback onTapExpand;

  @override
  State<_TappableThumbOverlay> createState() => _TappableThumbOverlayState();
}

class _TappableThumbOverlayState extends State<_TappableThumbOverlay> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTapExpand,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hover ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: SizedBox(
            width: _kPdfViewerBox,
            height: _kPdfViewerBox,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                widget.child,
                if (_hover)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x551E3A8A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white,
                          size: 30,
                          shadows: <Shadow>[
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitRangeRowWidget extends StatefulWidget {
  const _SplitRangeRowWidget({
    super.key,
    required this.row,
    required this.canRemove,
    this.onRemove,
  });

  final _SplitRangeRow row;
  final bool canRemove;
  final VoidCallback? onRemove;

  @override
  State<_SplitRangeRowWidget> createState() => _SplitRangeRowWidgetState();
}

class _SplitRangeRowWidgetState extends State<_SplitRangeRowWidget> {
  late final TextEditingController _startC;
  late final TextEditingController _endC;

  @override
  void initState() {
    super.initState();
    _startC = TextEditingController(text: '${widget.row.startPage}');
    _endC = TextEditingController(text: '${widget.row.endPage}');
  }

  @override
  void dispose() {
    _startC.dispose();
    _endC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text('page'),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: TextField(
            controller: _startC,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (String s) {
              widget.row.startPage = int.tryParse(s) ?? 0;
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('~ page'),
        ),
        SizedBox(
          width: 64,
          child: TextField(
            controller: _endC,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (String s) {
              widget.row.endPage = int.tryParse(s) ?? 0;
            },
          ),
        ),
        if (widget.canRemove && widget.onRemove != null)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: widget.onRemove,
          ),
      ],
    );
  }
}
