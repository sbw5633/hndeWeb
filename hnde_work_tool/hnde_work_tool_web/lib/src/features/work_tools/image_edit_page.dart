import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
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

enum _ImageEditTool { crop, rotate }

/// 자르기 · 회전 (좌측 아이콘 선택, 드래그앤드롭 + 미리보기)
class ImageEditPage extends StatefulWidget {
  const ImageEditPage({super.key});

  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  late final CropController _cropController;
  _ImageEditTool _tool = _ImageEditTool.crop;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _cropController = CropController();
  }

  void _setImage(Uint8List b) {
    if (!mounted) {
      return;
    }
    setState(() {
      _bytes = b;
      _cropController.image = b;
    });
  }

  void _onDropped(List<(String, Uint8List)> items) {
    if (items.isEmpty) {
      return;
    }
    final Uint8List data = items.first.$2;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _setImage(data);
    });
  }

  Future<void> _pickImage() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: WorkToolUi.imageExtensions,
      withData: true,
    );
    if (!mounted || r == null || r.files.isEmpty) {
      return;
    }
    final Uint8List? b = r.files.single.bytes;
    if (b == null || b.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _setImage(b);
    });
  }

  void _onCropResult(CropResult result) {
    if (!kIsWeb) {
      return;
    }
    if (result is CropSuccess) {
      downloadBytesInBrowser(
        result.croppedImage,
        'crop_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (mounted) {
        showMessageAlert(context, message: '저장했습니다.', title: '완료');
      }
    } else if (result is CropFailure) {
      showMessageAlert(context, message: '${result.cause}', title: '자르기 실패');
    }
  }

  void _rotate90() {
    if (_bytes == null) {
      return;
    }
    final img.Image? decoded = img.decodeImage(_bytes!);
    if (decoded == null) {
      showMessageAlert(context, message: '이미지를 읽을 수 없습니다.');
      return;
    }
    final img.Image rotated = img.copyRotate(decoded, angle: math.pi / 2);
    setState(() {
      _bytes = Uint8List.fromList(img.encodePng(rotated));
      _cropController.image = _bytes!;
    });
  }

  void _downloadPng() {
    if (_bytes == null || !kIsWeb) {
      return;
    }
    downloadBytesInBrowser(
      _bytes!,
      'image_${DateTime.now().millisecondsSinceEpoch}.png',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return EnterpriseScaffold(
      title: '이미지 편집',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ToolRail(
            tool: _tool,
            onSelect: (_ImageEditTool t) {
              setState(() {
                _tool = t;
                if (_bytes != null) {
                  _cropController.image = _bytes!;
                }
              });
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.folder_open_rounded, size: 20),
                        label: const Text('파일 선택'),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '이미지를 드롭하거나 선택하세요.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: WorkToolUi.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DecoratedBox(
                        decoration: WorkToolUi.cardDecoration(
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            if (_bytes == null) ...<Widget>[
                              Positioned.fill(
                                child: PdfDropzonePane(
                                  maxFiles: 1,
                                  allowedExtensions:
                                      WorkToolUi.imageExtensions,
                                  onPdfDropped: _onDropped,
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 56,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          WorkToolUi.imageExtensions
                                              .map((String e) =>
                                                  e.toUpperCase())
                                              .join(' · '),
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
                            ] else
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ColoredBox(
                                    color: Colors.white,
                                    child: _tool == _ImageEditTool.crop
                                        ? Crop(
                                            image: _bytes!,
                                            controller: _cropController,
                                            onCropped: _onCropResult,
                                            interactive: true,
                                            maskColor:
                                                Colors.black.withOpacity(0.42),
                                            baseColor: Colors.white,
                                            initialRectBuilder:
                                                InitialRectBuilder
                                                    .withSizeAndRatio(
                                              size: 0.88,
                                            ),
                                          )
                                        : Center(
                                            child: InteractiveViewer(
                                              minScale: 0.5,
                                              maxScale: 4,
                                              child: Image.memory(
                                                _bytes!,
                                                fit: BoxFit.contain,
                                              ),
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
                  const SizedBox(height: 12),
                  if (_bytes != null)
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: <Widget>[
                        if (_tool == _ImageEditTool.crop)
                          FilledButton.icon(
                            onPressed: () => _cropController.crop(),
                            icon: const Icon(Icons.crop_rounded, size: 20),
                            label: const Text('자르기 적용 · 저장'),
                          )
                        else ...<Widget>[
                          FilledButton.tonalIcon(
                            onPressed: _rotate90,
                            icon: const Icon(Icons.rotate_right_rounded, size: 20),
                            label: const Text('90° 회전'),
                          ),
                          FilledButton.icon(
                            onPressed: _downloadPng,
                            icon: const Icon(Icons.download_rounded, size: 20),
                            label: const Text('PNG 저장'),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({
    required this.tool,
    required this.onSelect,
  });

  final _ImageEditTool tool;
  final void Function(_ImageEditTool) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: WorkToolUi.cardDecoration(),
        child: Column(
          children: <Widget>[
            Text(
              '도구',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            _RailIcon(
              selected: tool == _ImageEditTool.crop,
              icon: Icons.crop_rounded,
              tooltip: '자르기',
              onTap: () => onSelect(_ImageEditTool.crop),
            ),
            const SizedBox(height: 8),
            _RailIcon(
              selected: tool == _ImageEditTool.rotate,
              icon: Icons.rotate_right_rounded,
              tooltip: '회전',
              onTap: () => onSelect(_ImageEditTool.rotate),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.selected,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected
            ? const Color(0xFFEFF6FF)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              size: 26,
              color: selected ? WorkToolUi.navy : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
