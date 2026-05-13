// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 브라우저: [HtmlElementView] + HTML5 drag/drop (MIME/플랫폼뷰 이슈 회피)
class PdfDropzonePane extends StatefulWidget {
  const PdfDropzonePane({
    super.key,
    required this.maxFiles,
    required this.onPdfDropped,
    this.scrollController,
    this.allowedExtensions,
    this.mimeTypes,
    this.acceptAllFiles = false,
  });

  final int maxFiles;
  final void Function(List<(String, Uint8List)> items) onPdfDropped;
  final List<String>? allowedExtensions;
  final List<String>? mimeTypes;
  final bool acceptAllFiles;
  final ScrollController? scrollController;

  @override
  State<PdfDropzonePane> createState() => _PdfDropzonePaneState();
}

class _PdfDropzonePaneState extends State<PdfDropzonePane> {
  late final String _viewTypeId;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewTypeId =
        'hnde-file-drop-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _acceptName(String name) {
    if (widget.acceptAllFiles) {
      return true;
    }
    final List<String> exts =
        widget.allowedExtensions ?? const <String>['pdf'];
    final String lower = name.toLowerCase();
    for (final String e in exts) {
      final String dot = e.startsWith('.') ? e.toLowerCase() : '.${e.toLowerCase()}';
      if (lower.endsWith(dot)) {
        return true;
      }
    }
    return false;
  }

  static Future<Uint8List> _readFileBytes(html.File file) {
    final Completer<Uint8List> done = Completer<Uint8List>();
    final html.FileReader reader = html.FileReader();
    reader.onLoadEnd.listen((html.Event _) {
      final Object? result = reader.result;
      if (result is ByteBuffer) {
        done.complete(Uint8List.view(result));
      } else if (result is Uint8List) {
        done.complete(result);
      } else {
        done.completeError(StateError('FileReader result'));
      }
    });
    reader.onError.listen((html.Event _) {
      if (!done.isCompleted) {
        done.completeError(StateError('FileReader error'));
      }
    });
    reader.readAsArrayBuffer(file);
    return done.future;
  }

  static List<html.File> _filesFromDataTransfer(html.DataTransfer dt) {
    final List<html.File> out = <html.File>[];
    final dynamic raw = dt.files;
    if (raw == null) {
      return out;
    }
    if (raw is html.FileList) {
      for (int i = 0; i < raw.length; i++) {
        final html.File? f = raw[i];
        if (f != null) {
          out.add(f);
        }
      }
    } else if (raw is List) {
      for (final Object? o in raw) {
        if (o is html.File) {
          out.add(o);
        }
      }
    }
    return out;
  }

  html.HtmlElement _createDropElement() {
    final html.DivElement root = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.boxSizing = 'border-box'
      ..style.pointerEvents = 'auto'
      ..style.touchAction = 'none';

    root.onDragEnter.listen((html.Event e) {
      e.preventDefault();
    });
    root.onDragOver.listen((html.Event e) {
      e.preventDefault();
      if (e is html.MouseEvent) {
        e.dataTransfer.dropEffect = 'copy';
      }
    });
    root.onDrop.listen((html.Event e) async {
      e.preventDefault();
      e.stopPropagation();
      if (e is! html.MouseEvent) {
        return;
      }
      final html.DataTransfer? dt = e.dataTransfer;
      if (dt == null) {
        return;
      }
      final List<html.File> fileList = _filesFromDataTransfer(dt);
      if (fileList.isEmpty) {
        return;
      }
      final List<(String, Uint8List)> raw = <(String, Uint8List)>[];
      for (final html.File f in fileList) {
        if (raw.length >= widget.maxFiles) {
          break;
        }
        final String name = f.name;
        if (!_acceptName(name)) {
          continue;
        }
        try {
          final Uint8List bytes = await _readFileBytes(f);
          if (bytes.isNotEmpty) {
            raw.add((name, bytes));
          }
        } catch (_) {
          continue;
        }
      }
      if (raw.isEmpty) {
        return;
      }
      final List<(String, Uint8List)> batch =
          List<(String, Uint8List)>.from(raw);
      Future<void>.microtask(() {
        if (!mounted) {
          return;
        }
        widget.onPdfDropped(batch);
      });
    });

    return root;
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      _registered = true;
      ui_web.platformViewRegistry.registerViewFactory(_viewTypeId, (int _) {
        return _createDropElement();
      });
    }

    Widget child = SizedBox.expand(
      child: HtmlElementView(viewType: _viewTypeId),
    );
    final ScrollController? sc = widget.scrollController;
    if (sc != null) {
      child = Listener(
        onPointerSignal: (PointerSignalEvent e) {
          if (e is! PointerScrollEvent) {
            return;
          }
          if (!sc.hasClients) {
            return;
          }
          final ScrollPosition pos = sc.position;
          final double next = (pos.pixels + e.scrollDelta.dy).clamp(
            pos.minScrollExtent,
            pos.maxScrollExtent,
          );
          sc.jumpTo(next);
        },
        child: child,
      );
    }
    return child;
  }
}
