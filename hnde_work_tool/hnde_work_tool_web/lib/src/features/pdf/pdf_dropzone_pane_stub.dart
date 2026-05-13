import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 네이티브: HTML 드롭 없음 — 동일 레이아웃용 배경만
class PdfDropzonePane extends StatelessWidget {
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
  final ScrollController? scrollController;
  final List<String>? allowedExtensions;
  final List<String>? mimeTypes;
  /// true면 확장자 검사 없이 모든 파일 수락 (웹 전용 동작; 스텁은 무시)
  final bool acceptAllFiles;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '웹(Chrome)에서는 이 영역에 PDF를 드래그할 수 있습니다.\n'
              '이 환경에서는「PDF 선택」버튼을 사용하세요. (최대 $maxFiles개)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
