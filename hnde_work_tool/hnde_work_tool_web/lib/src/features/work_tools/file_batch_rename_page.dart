// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async' show StreamSubscription;
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/browser_download.dart';
import '../common/enterprise_scaffold.dart';
import '../common/message_alert.dart';
import '../pdf/pdf_dropzone_pane_stub.dart'
    if (dart.library.html) '../pdf/pdf_dropzone_pane_web.dart';
import 'work_tool_ui.dart';

String _sanitizeFileName(String name) {
  return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

List<String> _makeUniqueNames(List<String> names) {
  final List<String> out = <String>[];
  for (final String n in names) {
    if (!out.contains(n)) {
      out.add(n);
      continue;
    }
    final int dot = n.lastIndexOf('.');
    final String stem = dot >= 0 ? n.substring(0, dot) : n;
    final String ext = dot >= 0 ? n.substring(dot) : '';
    int k = 2;
    String candidate;
    do {
      candidate = '${stem}_$k$ext';
      k++;
    } while (out.contains(candidate));
    out.add(candidate);
  }
  return out;
}

String _buildOneNewName({
  required String originalName,
  required int index,
  required String prefix,
  required String suffix,
  required String find,
  required String replace,
  required bool sequential,
  required int start,
  required int digits,
}) {
  final int dot = originalName.lastIndexOf('.');
  final String ext = dot >= 0 ? originalName.substring(dot) : '';
  String stem = dot >= 0 ? originalName.substring(0, dot) : originalName;
  if (find.isNotEmpty) {
    stem = stem.replaceAll(find, replace);
  }
  String body = '$prefix$stem';
  if (sequential) {
    final String n = (start + index).toString().padLeft(digits, '0');
    body = '${body}_$n';
  }
  body = '$body$suffix';
  return _sanitizeFileName('$body$ext');
}

class _PickedFile {
  _PickedFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class FileBatchRenamePage extends StatefulWidget {
  const FileBatchRenamePage({super.key});

  @override
  State<FileBatchRenamePage> createState() => _FileBatchRenamePageState();
}

class _FileBatchRenamePageState extends State<FileBatchRenamePage> {
  static const int _kMaxFiles = 200;

  final ScrollController _scrollLeft = ScrollController();
  StreamSubscription<html.Event>? _webDragEnterSub;
  StreamSubscription<html.Event>? _webDragEndSub;
  StreamSubscription<html.Event>? _webDropSub;
  bool _webDropOverlay = false;

  final TextEditingController _prefix = TextEditingController();
  final TextEditingController _suffix = TextEditingController();
  final TextEditingController _find = TextEditingController();
  final TextEditingController _replace = TextEditingController();
  final TextEditingController _seqStart = TextEditingController(text: '1');
  final TextEditingController _seqDigits = TextEditingController(text: '2');

  bool _sequential = false;
  List<_PickedFile> _files = <_PickedFile>[];

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
    if (_files.length >= _kMaxFiles) {
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
    _scrollLeft.dispose();
    _prefix.dispose();
    _suffix.dispose();
    _find.dispose();
    _replace.dispose();
    _seqStart.dispose();
    _seqDigits.dispose();
    super.dispose();
  }

  List<String> _previewNewNames() {
    final int start = int.tryParse(_seqStart.text) ?? 1;
    final int digits = int.tryParse(_seqDigits.text)?.clamp(1, 8) ?? 2;
    final List<String> raw = <String>[];
    for (int i = 0; i < _files.length; i++) {
      raw.add(
        _buildOneNewName(
          originalName: _files[i].name,
          index: i,
          prefix: _prefix.text,
          suffix: _suffix.text,
          find: _find.text,
          replace: _replace.text,
          sequential: _sequential,
          start: start,
          digits: digits,
        ),
      );
    }
    return _makeUniqueNames(raw);
  }

  void _onDropped(List<(String, Uint8List)> items) {
    if (items.isEmpty) {
      return;
    }
    setState(() {
      final List<_PickedFile> next = List<_PickedFile>.from(_files);
      for (final (String name, Uint8List bytes) in items) {
        if (next.length >= _kMaxFiles) {
          break;
        }
        if (bytes.isEmpty) {
          continue;
        }
        next.add(_PickedFile(name: name, bytes: bytes));
      }
      _files = next;
      _webDropOverlay = false;
    });
  }

  Future<void> _pickFiles() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (r == null || r.files.isEmpty) {
      return;
    }
    final List<_PickedFile> next = <_PickedFile>[];
    for (final PlatformFile f in r.files) {
      final Uint8List? b = f.bytes;
      if (b == null || b.isEmpty) {
        continue;
      }
      next.add(_PickedFile(name: f.name, bytes: b));
    }
    setState(() => _files = next);
  }

  void _downloadResult() {
    if (_files.isEmpty) {
      showMessageAlert(context, message: '파일을 먼저 선택하세요.');
      return;
    }
    if (!kIsWeb) {
      showMessageAlert(context, message: '웹에서만 다운로드를 지원합니다.');
      return;
    }
    final List<String> names = _previewNewNames();
    if (_files.length == 1) {
      downloadBytesInBrowser(_files[0].bytes, names[0]);
      showMessageAlert(context, message: '저장했습니다.', title: '완료');
      return;
    }
    final Archive archive = Archive();
    for (int i = 0; i < _files.length; i++) {
      final Uint8List data = _files[i].bytes;
      archive.addFile(ArchiveFile(names[i], data.length, data));
    }
    final List<int>? zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      showMessageAlert(context, message: 'ZIP 생성에 실패했습니다.');
      return;
    }
    downloadBytesInBrowser(
      Uint8List.fromList(zipped),
      'renamed_${DateTime.now().millisecondsSinceEpoch}.zip',
    );
    showMessageAlert(context, message: 'ZIP으로 저장했습니다.', title: '완료');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> preview = _previewNewNames();
    return EnterpriseScaffold(
      title: '파일명 일괄 수정',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints bc) {
          final bool wide = bc.maxWidth >= 960;
          final Widget body = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 5, child: _buildLeftPane(theme, preview)),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildRightPane(theme)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 6, child: _buildLeftPane(theme, preview)),
                    const SizedBox(height: 16),
                    Expanded(flex: 5, child: _buildRightPane(theme)),
                  ],
                );
          return body;
        },
      ),
    );
  }

  Widget _buildLeftPane(ThemeData theme, List<String> preview) {
    final bool webOverlay =
        kIsWeb && _webDropOverlay && _files.length < _kMaxFiles;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WorkToolUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '파일',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '모든 형식 · 이 영역으로 드래그하여 추가 (웹)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: WorkToolUi.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.folder_open_rounded, size: 22),
            label: Text(
              _files.isEmpty
                  ? '파일 선택'
                  : '${_files.length}개 선택됨 · 다시 선택',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '편집 예시',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: WorkToolUi.muted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WorkToolUi.border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                    height: 1.4,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: _prefix.text.isEmpty ? '(접두)' : _prefix.text,
                      style: TextStyle(
                        color: _prefix.text.isEmpty
                            ? WorkToolUi.muted
                            : WorkToolUi.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: '('),
                    TextSpan(
                      text: '파일명',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const TextSpan(text: ')'),
                    TextSpan(
                      text: _suffix.text.isEmpty ? '(접미)' : _suffix.text,
                      style: TextStyle(
                        color: _suffix.text.isEmpty
                            ? WorkToolUi.muted
                            : WorkToolUi.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '.확장자',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_sequential) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '※ 순번 사용 시: 접두·접미·치환 뒤 `_01` 형태로 붙습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: WorkToolUi.muted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '변경 결과',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: WorkToolUi.muted,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints bc) {
                final double h = bc.maxHeight > 80 ? bc.maxHeight : 280;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (_files.isEmpty)
                        Positioned.fill(
                          child: PdfDropzonePane(
                            acceptAllFiles: true,
                            maxFiles: _kMaxFiles,
                            onPdfDropped: _onDropped,
                          ),
                        ),
                      if (_files.isEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: h),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      '파일을 선택하거나\n이 영역으로 드래그하세요.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: WorkToolUi.muted,
                                        fontWeight: FontWeight.w600,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_files.isNotEmpty)
                        Positioned.fill(
                          child: Scrollbar(
                            controller: _scrollLeft,
                            thumbVisibility: true,
                            child: ListView.separated(
                              controller: _scrollLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              itemCount: _files.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (BuildContext context, int i) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              _files[i].name,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: WorkToolUi.muted,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: <Widget>[
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 16,
                                                  color: WorkToolUi.navy
                                                      .withOpacity(0.7),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    preview[i],
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: WorkToolUi.navy,
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: '목록에서 제거',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setState(() {
                                            _files.removeAt(i);
                                          });
                                        },
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      if (webOverlay && _files.isNotEmpty)
                        Positioned.fill(
                          child: Material(
                            color: const Color(0x331E3A8A),
                            child: PdfDropzonePane(
                              acceptAllFiles: true,
                              maxFiles: _kMaxFiles,
                              scrollController: _scrollLeft,
                              onPdfDropped: (List<(String, Uint8List)> items) {
                                _onDropped(items);
                                _clearWebOverlay();
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WorkToolUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '편집 규칙',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _prefix,
            decoration: WorkToolUi.fieldDecoration('접두'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _suffix,
            decoration: WorkToolUi.fieldDecoration('접미 (확장자 직전)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _find,
                  decoration: WorkToolUi.fieldDecoration('찾을 문자열'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _replace,
                  decoration: WorkToolUi.fieldDecoration('바꿀 문자열'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('순번 붙이기'),
            subtitle: const Text('예: 이름_01, 이름_02'),
            value: _sequential,
            onChanged: (bool v) => setState(() => _sequential = v),
          ),
          if (_sequential)
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _seqStart,
                    decoration: WorkToolUi.fieldDecoration('시작 번호'),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _seqDigits,
                    decoration: WorkToolUi.fieldDecoration('자릿수'),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _files.isEmpty ? null : _downloadResult,
            icon: Icon(
              _files.length <= 1
                  ? Icons.download_rounded
                  : Icons.folder_zip_outlined,
              size: 22,
            ),
            label: Text(
              _files.length <= 1 ? '다운로드' : 'ZIP으로 다운로드',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: WorkToolUi.navy,
            ),
          ),
        ],
      ),
    );
  }
}
