import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Syncfusion PDF — 병합·분할·회전 반영
class PdfSyncfusionHelper {
  PdfSyncfusionHelper._();

  /// 웹 메인 isolate에서 PDF 처리 시 UI가 멈춘 것처럼 보이지 않도록 이벤트 루프에 양보.
  static Future<void> _yieldUi() async {
    await Future<void>.delayed(Duration.zero);
  }

  static int pageCount(Uint8List bytes, {String? password}) {
    final PdfDocument doc = _open(bytes, password: password);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  /// 웹에서 pdfx 등이 같은 버퍼를 연 뒤 ArrayBuffer를 detach하면 Syncfusion이 실패할 수 있음.
  static Uint8List _copyBytes(Uint8List bytes) => Uint8List.fromList(bytes);

  /// PDF `/Rotate` (0·90·180·270°)를 0~3 분기(90° 단위, 시계 방향)로.
  /// [PdfPageRotateAngle] 순서가 0,1,2,3과 대응한다.
  static int _intrinsicQuarterTurns(PdfPage page) =>
      page.rotation.index.clamp(0, 3);

  /// 파일에 기록된 회전 + 사용자(미리보기) 회전을 합친 최종 분기.
  static int _combinedQuarterTurns(PdfPage srcPage, int userQuarterTurns) =>
      (_intrinsicQuarterTurns(srcPage) + userQuarterTurns) % 4;

  static PdfDocument _open(Uint8List bytes, {String? password}) {
    final Uint8List safe = _copyBytes(bytes);
    return password != null && password.isNotEmpty
        ? PdfDocument(inputBytes: safe, password: password)
        : PdfDocument(inputBytes: safe);
  }

  /// ISO A4 (포인트, 1/72인치). Syncfusion [PdfPageSize.a4] 순서에 의존하지 않도록 고정.
  static const double _a4Narrow = 595.276;
  static const double _a4Wide = 841.89;

  /// [landscape]==true → 가로(너비=841.89, 높이=595.28), false → 세로(595.28×841.89).
  static Size a4TargetSize({required bool landscape}) {
    if (landscape) {
      return Size(_a4Wide, _a4Narrow);
    }
    return Size(_a4Narrow, _a4Wide);
  }

  /// 출력 페이지 MediaBox를 원본과 맞춤. 기본 A4보다 큰 원본은 A4에 그리면 잘림.
  /// 90°/270°는 뷰어에서 세로·가로가 바뀌므로 박스 가로·세로를 맞바꿈.
  static Size _outputPageSizeForCopy(Size srcSize, int quarterTurns) {
    final double w = srcSize.width;
    final double h = srcSize.height;
    if (w <= 0 || h <= 0) {
      return PdfPageSize.a4;
    }
    final int q = quarterTurns % 4;
    if (q == 1 || q == 3) {
      return Size(h, w);
    }
    return Size(w, h);
  }

  /// 빈 [PdfDocument]에 A4 + 세로/가로를 한 번에 지정한다.
  /// orientation·size를 따로 넣으면 Syncfusion이 세로(595×842)로 덮어쓰는 경우가 있어
  /// [PdfPageSettings] 생성자를 사용한다. 호출부는 **첫 [pages.add] 전에** 한 번만.
  static void _setEmptyDocOutputPaper(PdfDocument doc, bool outputLandscape) {
    doc.pageSettings = PdfPageSettings(
      Size(_a4Narrow, _a4Wide),
      outputLandscape
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait,
    );
    doc.pageSettings.margins.all = 0;
  }

  /// [quarterTurns]: UI·RotatedBox와 동일, 0~3 = 0°/90°/180°/270° 시계 방향.
  /// [outputLandscape]: true면 A4 가로 박스에 비율 유지하며 맞춤.
  /// 페이지 /Rotate 대신 graphics에 회전을 굽는다(뷰어·병합본에서 회전이 빠지는 문제 방지).
  /// 출력 용지는 호출 전 [_setEmptyDocOutputPaper]로 이미 맞춰 두어야 한다.
  static void _copyPage(
    PdfDocument dest,
    PdfPage srcPage, {
    int quarterTurns = 0,
    bool outputLandscape = false,
  }) {
    final PdfTemplate template = srcPage.createTemplate();
    final Size srcSize = srcPage.size;
    final double w = srcSize.width;
    final double h = srcSize.height;
    final int q = quarterTurns % 4;
    final Size naturalOut = _outputPageSizeForCopy(srcSize, q);
    final Size target = a4TargetSize(landscape: outputLandscape);
    final double sx = target.width / naturalOut.width;
    final double sy = target.height / naturalOut.height;
    // 용지에 맞춤(축소·여백), 단 100% 초과 확대는 하지 않음
    double s = math.min(sx, sy);
    if (s > 1.0) {
      s = 1.0;
    }
    final double ox = (target.width - naturalOut.width * s) / 2;
    final double oy = (target.height - naturalOut.height * s) / 2;
    final PdfPage newPage = dest.pages.add();
    final PdfGraphics g = newPage.graphics;
    g.translateTransform(ox, oy);
    final double sw = w * s;
    final double sh = h * s;
    final double nw = naturalOut.width * s;
    final double nh = naturalOut.height * s;
    if (q == 0) {
      g.drawPdfTemplate(template, Offset.zero, Size(sw, sh));
      return;
    }
    final PdfGraphicsState state = g.save();
    final double cx = nw / 2;
    final double cy = nh / 2;
    g.translateTransform(cx, cy);
    g.rotateTransform(q * 90.0);
    g.translateTransform(-sw / 2, -sh / 2);
    g.drawPdfTemplate(template, Offset.zero, Size(sw, sh));
    g.restore(state);
  }

  /// 전체 순서대로 병합. [order]가 null이면 파일 순서 그대로.
  /// [rotations]: 파일 인덱스별, 페이지 인덱스별 0~3 (90° 단위)
  /// [skipPage]: true면 해당 페이지는 제외 (원본 문서 인덱스 기준)
  static Future<Uint8List> mergeAll(
    List<Uint8List> inputs,
    List<String> names, {
    List<int>? order,
    List<List<int>>? rotations,
    List<List<bool>>? skipPage,
    bool outputLandscape = false,
  }) async {
    final PdfDocument out = PdfDocument();
    _setEmptyDocOutputPaper(out, outputLandscape);
    final List<int> seq = order ?? List<int>.generate(inputs.length, (i) => i);
    for (final int fi in seq) {
      if (fi < 0 || fi >= inputs.length) {
        continue;
      }
      final PdfDocument src = PdfDocument(inputBytes: _copyBytes(inputs[fi]));
      try {
        final List<int>? rotFile =
            rotations != null && fi < rotations.length ? rotations[fi] : null;
        final List<bool>? skipF =
            skipPage != null && fi < skipPage.length ? skipPage[fi] : null;
        for (int pi = 0; pi < src.pages.count; pi++) {
          if (skipF != null && pi < skipF.length && skipF[pi]) {
            continue;
          }
          final int userQ = rotFile != null && pi < rotFile.length
              ? rotFile[pi].clamp(0, 3)
              : 0;
          final int q = _combinedQuarterTurns(src.pages[pi], userQ);
          _copyPage(
            out,
            src.pages[pi],
            quarterTurns: q,
            outputLandscape: outputLandscape,
          );
        }
      } finally {
        src.dispose();
      }
    }
    final List<int> bytes = await out.save();
    out.dispose();
    return Uint8List.fromList(bytes);
  }

  /// 파일·페이지 단위 순서로 병합. [pageOrder]: (파일 인덱스, 해당 파일 내 0-based 페이지 인덱스) 목록.
  /// 소스 파일은 한 번만 열어 순서대로 페이지를 복사합니다.
  static Future<Uint8List> mergePagesInOrder(
    List<Uint8List> inputs,
    List<String> names, {
    required List<(int docIndex, int pageIndex)> pageOrder,
    List<List<int>>? rotations,
    List<List<bool>>? skipPage,
    bool outputLandscape = false,
  }) async {
    final PdfDocument out = PdfDocument();
    _setEmptyDocOutputPaper(out, outputLandscape);
    final List<PdfDocument?> opened = List<PdfDocument?>.filled(inputs.length, null);
    try {
      for (final (int fi, int pi) in pageOrder) {
        if (fi < 0 || fi >= inputs.length) {
          continue;
        }
        opened[fi] ??= PdfDocument(inputBytes: _copyBytes(inputs[fi]));
        final PdfDocument src = opened[fi]!;
        if (pi < 0 || pi >= src.pages.count) {
          continue;
        }
        final List<bool>? skipF =
            skipPage != null && fi < skipPage.length ? skipPage[fi] : null;
        if (skipF != null && pi < skipF.length && skipF[pi]) {
          continue;
        }
        final List<int>? rotFile =
            rotations != null && fi < rotations.length ? rotations[fi] : null;
        final int userQ = rotFile != null && pi < rotFile.length
            ? rotFile[pi].clamp(0, 3)
            : 0;
        final int q = _combinedQuarterTurns(src.pages[pi], userQ);
        _copyPage(
          out,
          src.pages[pi],
          quarterTurns: q,
          outputLandscape: outputLandscape,
        );
        await _yieldUi();
      }
    } finally {
      for (final PdfDocument? d in opened) {
        d?.dispose();
      }
    }
    await _yieldUi();
    final List<int> bytes = await out.save();
    out.dispose();
    return Uint8List.fromList(bytes);
  }

  /// 구간별로 별도 PDF 생성 후 ZIP. [ranges]: (0-based 시작, 끝 포함)
  /// [quarterTurns]: 문서 전체 페이지 인덱스별 0~3
  /// [pageSkip]: 문서 전체 페이지 인덱스별 삭제(제외)
  static Future<Uint8List> splitToZip(
    Uint8List input, {
    required List<(int start, int end)> ranges,
    List<int>? quarterTurns,
    List<bool>? pageSkip,
    bool outputLandscape = false,
  }) async {
    final PdfDocument src = PdfDocument(inputBytes: _copyBytes(input));
    try {
      final Archive arch = Archive();
      for (int ri = 0; ri < ranges.length; ri++) {
        final (int a, int rangeEnd) = ranges[ri];
        final int start = a.clamp(0, src.pages.count - 1);
        final int end = rangeEnd.clamp(start, src.pages.count - 1);
        final PdfDocument part = PdfDocument();
        _setEmptyDocOutputPaper(part, outputLandscape);
        for (int pi = start; pi <= end; pi++) {
          if (pageSkip != null && pi < pageSkip.length && pageSkip[pi]) {
            continue;
          }
          final int userQ = quarterTurns != null && pi < quarterTurns.length
              ? quarterTurns[pi].clamp(0, 3)
              : 0;
          final int q = _combinedQuarterTurns(src.pages[pi], userQ);
          _copyPage(
            part,
            src.pages[pi],
            quarterTurns: q,
            outputLandscape: outputLandscape,
          );
        }
        final List<int> partBytes = await part.save();
        part.dispose();
        arch.addFile(
          ArchiveFile(
            'split_${ri + 1}.pdf',
            partBytes.length,
            Uint8List.fromList(partBytes),
          ),
        );
      }
      final List<int>? z = ZipEncoder().encode(arch);
      if (z == null) {
        throw StateError('ZIP 인코딩 실패');
      }
      return Uint8List.fromList(z);
    } finally {
      src.dispose();
    }
  }

  static Future<Uint8List> zipFiles(List<String> names, List<Uint8List> files) async {
    final Archive arch = Archive();
    for (int i = 0; i < files.length; i++) {
      final String n = names.length > i ? names[i] : 'file_$i.pdf';
      arch.addFile(ArchiveFile(n, files[i].length, files[i]));
    }
    final List<int>? zipped = ZipEncoder().encode(arch);
    if (zipped == null) {
      throw StateError('ZIP 인코딩 실패');
    }
    return Uint8List.fromList(zipped);
  }

  /// 텍스트 추출 (간단 변환)
  static Future<String> extractText(Uint8List input) async {
    final PdfDocument doc = PdfDocument(inputBytes: _copyBytes(input));
    try {
      final StringBuffer sb = StringBuffer();
      final PdfTextExtractor ex = PdfTextExtractor(doc);
      for (int i = 0; i < doc.pages.count; i++) {
        sb.writeln('--- page ${i + 1} ---');
        sb.writeln(ex.extractText(startPageIndex: i, endPageIndex: i));
      }
      return sb.toString();
    } finally {
      doc.dispose();
    }
  }

  /// 페이지별 텍스트 (엑셀 등 내보내기용)
  static Future<List<String>> extractTextPerPage(Uint8List input) async {
    final PdfDocument doc = PdfDocument(inputBytes: _copyBytes(input));
    try {
      final PdfTextExtractor ex = PdfTextExtractor(doc);
      final List<String> out = <String>[];
      for (int i = 0; i < doc.pages.count; i++) {
        out.add(ex.extractText(startPageIndex: i, endPageIndex: i));
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  /// 이미지 바이트 목록(순서대로)을 한 PDF로 합침
  static Future<Uint8List> imagesToPdf(
    List<Uint8List> images, {
    bool outputLandscape = false,
  }) async {
    if (images.isEmpty) {
      throw ArgumentError('이미지가 비어 있습니다.');
    }
    final PdfDocument doc = PdfDocument();
    _setEmptyDocOutputPaper(doc, outputLandscape);
    try {
      final Size target = a4TargetSize(landscape: outputLandscape);
      for (final Uint8List raw in images) {
        final PdfBitmap bmp = PdfBitmap(_copyBytes(raw));
        final double iw = bmp.width.toDouble();
        final double ih = bmp.height.toDouble();
        if (iw <= 0 || ih <= 0) {
          continue;
        }
        final PdfPage page = doc.pages.add();
        final double sx = target.width / iw;
        final double sy = target.height / ih;
        double s = math.min(sx, sy);
        if (s > 1.0) {
          s = 1.0;
        }
        final double dw = iw * s;
        final double dh = ih * s;
        final double ox = (target.width - dw) / 2;
        final double oy = (target.height - dh) / 2;
        page.graphics.drawImage(
          bmp,
          Rect.fromLTWH(ox, oy, dw, dh),
        );
        await _yieldUi();
      }
      final List<int> b = await doc.save();
      return Uint8List.fromList(b);
    } finally {
      doc.dispose();
    }
  }

  /// UTF-8 텍스트를 여러 페이지 PDF로 (줄 단위)
  static Future<Uint8List> textToPdf(String text) async {
    final PdfDocument doc = PdfDocument();
    doc.pageSettings.margins.all = 36;
    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 11);
    const double lineHeight = 14;
    const double margin = 40;
    final List<String> lines = text.split('\n');
    PdfPage page = doc.pages.add();
    double y = margin;
    for (final String line in lines) {
      final double pageH = page.size.height;
      final double pageW = page.size.width;
      final double bottom = pageH - margin;
      if (y + lineHeight > bottom) {
        page = doc.pages.add();
        y = margin;
      }
      page.graphics.drawString(
        line,
        font,
        bounds: Rect.fromLTWH(margin, y, pageW - 2 * margin, lineHeight),
      );
      y += lineHeight;
    }
    final List<int> b = await doc.save();
    doc.dispose();
    return Uint8List.fromList(b);
  }

  /// 여러 UTF-8 텍스트 파일을 한 PDF에 순서대로 이어붙임 (파일 구분 제목 포함)
  static Future<Uint8List> textFilesToPdf(
    List<(String name, String text)> files,
  ) async {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < files.length; i++) {
      if (i > 0) {
        sb.writeln();
        sb.writeln();
      }
      sb.writeln('===== ${files[i].$1} =====');
      sb.writeln(files[i].$2);
    }
    return textToPdf(sb.toString());
  }

  static String decodeUtf8Text(Uint8List bytes) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}
