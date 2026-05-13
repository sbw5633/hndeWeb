// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async' show StreamSubscription;
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../utils/browser_download.dart';
import '../common/enterprise_scaffold.dart';
import '../common/message_alert.dart';
import '../pdf/pdf_dropzone_pane_stub.dart'
    if (dart.library.html) '../pdf/pdf_dropzone_pane_web.dart';
import 'work_tool_ui.dart';

class _QueuedImage {
  _QueuedImage({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

enum _ScaleMode {
  original,
  percent75,
  percent50,
  maxWidth4096,
  maxWidth2048,
  maxWidth1280,
  maxWidth800,
}

class ImageCompressPage extends StatefulWidget {
  const ImageCompressPage({super.key});

  @override
  State<ImageCompressPage> createState() => _ImageCompressPageState();
}

class _ImageCompressPageState extends State<ImageCompressPage> {
  static const int _kMaxFiles = 80;

  final ScrollController _scroll = ScrollController();
  StreamSubscription<html.Event>? _webDragEnterSub;
  StreamSubscription<html.Event>? _webDragEndSub;
  StreamSubscription<html.Event>? _webDropSub;
  bool _webDropOverlay = false;

  List<_QueuedImage> _items = <_QueuedImage>[];
  double _quality = 82;
  _ScaleMode _scale = _ScaleMode.original;

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
    if (_items.length >= _kMaxFiles) {
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
    _scroll.dispose();
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

  void _onDropped(List<(String, Uint8List)> items) {
    if (items.isEmpty) {
      return;
    }
    setState(() {
      final List<_QueuedImage> next = List<_QueuedImage>.from(_items);
      for (final (String name, Uint8List bytes) in items) {
        if (next.length >= _kMaxFiles) {
          break;
        }
        if (bytes.isEmpty || !_isImageName(name)) {
          continue;
        }
        next.add(_QueuedImage(name: name, bytes: bytes));
      }
      _items = next;
      _webDropOverlay = false;
    });
  }

  Future<void> _pick() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: WorkToolUi.imageExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (r == null || r.files.isEmpty) {
      return;
    }
    final List<_QueuedImage> next = <_QueuedImage>[];
    for (final PlatformFile f in r.files) {
      final Uint8List? b = f.bytes;
      if (b != null && b.isNotEmpty && _isImageName(f.name)) {
        next.add(_QueuedImage(name: f.name, bytes: b));
      }
    }
    if (next.isEmpty) {
      showMessageAlert(context, message: '이미지 파일만 선택할 수 있습니다.');
      return;
    }
    setState(() {
      _items = <_QueuedImage>[..._items, ...next];
      if (_items.length > _kMaxFiles) {
        _items = _items.sublist(0, _kMaxFiles);
      }
    });
  }

  img.Image _applyScale(img.Image src) {
    int w = src.width;
    int h = src.height;
    switch (_scale) {
      case _ScaleMode.original:
        return src;
      case _ScaleMode.percent75:
        w = (w * 0.75).round();
        h = (h * 0.75).round();
        return img.copyResize(src, width: w, height: h);
      case _ScaleMode.percent50:
        w = (w * 0.5).round();
        h = (h * 0.5).round();
        return img.copyResize(src, width: w, height: h);
      case _ScaleMode.maxWidth4096:
        if (w <= 4096) {
          return src;
        }
        return img.copyResize(src, width: 4096);
      case _ScaleMode.maxWidth2048:
        if (w <= 2048) {
          return src;
        }
        return img.copyResize(src, width: 2048);
      case _ScaleMode.maxWidth1280:
        if (w <= 1280) {
          return src;
        }
        return img.copyResize(src, width: 1280);
      case _ScaleMode.maxWidth800:
        if (w <= 800) {
          return src;
        }
        return img.copyResize(src, width: 800);
    }
  }

  String _outFileName(String original) {
    final int dot = original.lastIndexOf('.');
    final String stem =
        dot >= 0 ? original.substring(0, dot) : original;
    return '${stem}_compressed.jpg';
  }

  void _save() {
    if (_items.isEmpty || !kIsWeb) {
      return;
    }
    final int q = _quality.round().clamp(5, 100);
    final List<(String name, Uint8List bytes)> outs =
        <(String, Uint8List)>[];
    for (final _QueuedImage item in _items) {
      final img.Image? decoded = img.decodeImage(item.bytes);
      if (decoded == null) {
        continue;
      }
      final img.Image scaled = _applyScale(decoded);
      final Uint8List jpg =
          Uint8List.fromList(img.encodeJpg(scaled, quality: q));
      outs.add((_outFileName(item.name), jpg));
    }
    if (outs.isEmpty) {
      showMessageAlert(context, message: '이미지를 디코딩할 수 없습니다.');
      return;
    }
    if (outs.length == 1) {
      downloadBytesInBrowser(outs.first.$2, outs.first.$1);
      showMessageAlert(context, message: '저장했습니다.', title: '완료');
      return;
    }
    final Archive archive = Archive();
    for (final (String name, Uint8List data) in outs) {
      archive.addFile(ArchiveFile(name, data.length, data));
    }
    final List<int>? zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      showMessageAlert(context, message: 'ZIP 생성에 실패했습니다.');
      return;
    }
    downloadBytesInBrowser(
      Uint8List.fromList(zipped),
      'compressed_${DateTime.now().millisecondsSinceEpoch}.zip',
    );
    showMessageAlert(context, message: 'ZIP으로 저장했습니다.', title: '완료');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool webOverlay =
        kIsWeb && _webDropOverlay && _items.length < _kMaxFiles;
    return EnterpriseScaffold(
      title: '이미지 압축',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _pick,
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                label: const Text('이미지 선택'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '이미지 파일만 · 드래그로 추가 (웹)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: WorkToolUi.muted,
                  ),
                ),
              ),
              if (_items.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _items = <_QueuedImage>[]),
                  child: const Text('목록 비우기'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<_ScaleMode>(
            value: _scale,
            decoration: WorkToolUi.fieldDecoration('해상도 / 크기'),
            items: const <DropdownMenuItem<_ScaleMode>>[
              DropdownMenuItem(
                value: _ScaleMode.original,
                child: Text('원본 해상도 유지'),
              ),
              DropdownMenuItem(
                value: _ScaleMode.percent75,
                child: Text('비율 75%로 축소'),
              ),
              DropdownMenuItem(
                value: _ScaleMode.percent50,
                child: Text('비율 50%로 축소'),
              ),
              DropdownMenuItem(
                value: _ScaleMode.maxWidth4096,
                child: Text('긴 변 최대 4096px'),
              ),
              DropdownMenuItem(
                value: _ScaleMode.maxWidth2048,
                child: Text('긴 변 최대 2048px'),
              ),
              DropdownMenuItem(
                value: _ScaleMode.maxWidth1280,
                child: Text('긴 변 최대 1280px'),
              ),
              DropdownMenuItem(
                value: _ScaleMode.maxWidth800,
                child: Text('긴 변 최대 800px'),
              ),
            ],
            onChanged: (_ScaleMode? v) {
              if (v != null) {
                setState(() => _scale = v);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'JPEG 품질 ${_quality.round()} (낮을수록 용량↓)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: _quality,
            min: 5,
            max: 100,
            divisions: 19,
            label: '${_quality.round()}',
            onChanged: (double v) => setState(() => _quality = v),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: WorkToolUi.cardDecoration(
                  color: const Color(0xFFF8FAFC),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints bc) {
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (_items.isEmpty)
                          Positioned.fill(
                            child: PdfDropzonePane(
                              maxFiles: _kMaxFiles,
                              allowedExtensions: WorkToolUi.imageExtensions,
                              onPdfDropped: _onDropped,
                            ),
                          ),
                        if (_items.isEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.compress_rounded,
                                      size: 56,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '이미지를 드롭하거나 선택하세요',
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
                        if (_items.isNotEmpty)
                          Positioned.fill(
                            child: Scrollbar(
                              controller: _scroll,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.all(12),
                                itemCount: _items.length,
                                itemBuilder: (BuildContext context, int i) {
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.image_outlined,
                                      color: WorkToolUi.navy,
                                    ),
                                    title: Text(
                                      _items[i].name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${(_items[i].bytes.length / 1024).toStringAsFixed(1)} KB',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (webOverlay && _items.isNotEmpty)
                          Positioned.fill(
                            child: Material(
                              color: const Color(0x331E3A8A),
                              child: PdfDropzonePane(
                                maxFiles: _kMaxFiles,
                                allowedExtensions: WorkToolUi.imageExtensions,
                                scrollController: _scroll,
                                onPdfDropped: (List<(String, Uint8List)> it) {
                                  _onDropped(it);
                                  _clearWebOverlay();
                                },
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _items.isEmpty ? null : _save,
            icon: Icon(
              _items.length <= 1
                  ? Icons.download_rounded
                  : Icons.folder_zip_outlined,
              size: 20,
            ),
            label: Text(
              _items.isEmpty
                  ? 'JPEG로 저장'
                  : _items.length == 1
                      ? 'JPEG로 다운로드'
                      : 'JPEG 일괄 · ZIP 다운로드',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: WorkToolUi.navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
