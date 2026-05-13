import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'pdf_syncfusion_helper.dart';

/// PDF 저장 시 용지 방향 (회전 상태는 유지한 채 A4에 맞춤)
enum PdfPageOrientation {
  portrait,
  landscape,
}

enum PdfToolkitTool {
  merge,
  split,
}

extension PdfToolkitToolX on PdfToolkitTool {
  String get label {
    switch (this) {
      case PdfToolkitTool.merge:
        return 'PDF 합치기';
      case PdfToolkitTool.split:
        return 'PDF 분할';
    }
  }

  String get subtitle {
    switch (this) {
      case PdfToolkitTool.merge:
        return '여러 문서를 하나로 통합';
      case PdfToolkitTool.split:
        return '한 문서를 구간별로 분리';
    }
  }

  int get maxFiles {
    switch (this) {
      case PdfToolkitTool.merge:
        return 50;
      case PdfToolkitTool.split:
        return 10;
    }
  }

  IconData get icon {
    switch (this) {
      case PdfToolkitTool.merge:
        return Icons.merge_type_rounded;
      case PdfToolkitTool.split:
        return Icons.call_split_rounded;
    }
  }
}

/// 업로드된 PDF 한 개 + 페이지별 편집 상태
class PdfLoadedDoc {
  PdfLoadedDoc({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
  int pageCount = 0;
  /// 페이지별 90° 단위 회전 (0~3)
  List<int> quarterTurns = <int>[];
  List<bool> pageRemoved = <bool>[];

  void initPageArrays() {
    pageCount = PdfSyncfusionHelper.pageCount(bytes);
    quarterTurns = List<int>.filled(pageCount, 0);
    pageRemoved = List<bool>.filled(pageCount, false);
  }

  void rotateAt(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pageCount) {
      return;
    }
    quarterTurns[pageIndex] = (quarterTurns[pageIndex] + 1) % 4;
  }

  /// 합치기: 파일 단위로 모든 페이지에 동일하게 90° 회전
  void rotateAllPages() {
    for (int i = 0; i < pageCount; i++) {
      if (!pageRemoved[i]) {
        rotateAt(i);
      }
    }
  }

  List<List<int>> rotationsForMergeFile() {
    return <List<int>>[List<int>.from(quarterTurns)];
  }
}
