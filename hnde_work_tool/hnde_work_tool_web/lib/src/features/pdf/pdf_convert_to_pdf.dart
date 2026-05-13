// [보류] PDF 변환(타 포맷→PDF) 기능 — 앱에서는 비활성. 합치기·분할만 유지.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:xml/xml.dart';

import 'pdf_syncfusion_helper.dart';

/// 워드·엑셀·PPT·한글·DXF·TXT 등 → PDF (클라이언트 전용)
class PdfConvertToPdf {
  PdfConvertToPdf._();

  static String _stripXml(String xml) {
    return xml
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<Uint8List> fromTxt(Uint8List bytes) async {
    final String t = utf8.decode(bytes, allowMalformed: true);
    return PdfSyncfusionHelper.textToPdf(t.isEmpty ? '(내용 없음)' : t);
  }

  static Future<Uint8List> fromDocx(Uint8List bytes) async {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? docXml;
    for (final ArchiveFile f in archive.files) {
      if (f.name == 'word/document.xml') {
        docXml = f;
        break;
      }
    }
    if (docXml == null) {
      throw StateError('DOCX에서 word/document.xml을 찾을 수 없습니다.');
    }
    final String xml = utf8.decode(docXml.content as List<int>);
    final String text = _stripXml(xml);
    return PdfSyncfusionHelper.textToPdf(text.isEmpty ? '(내용 없음)' : text);
  }

  /// 1) [spreadsheet_decoder] (`verify: false`) — 스타일 시트 검증을 피해 대부분의 xlsx 처리
  /// 2) 실패 시 OOXML(XML) 직접 파싱 (`r` 생략 셀 보정 포함)
  static Future<Uint8List> fromXlsx(Uint8List bytes) async {
    try {
      final SpreadsheetDecoder decoder = SpreadsheetDecoder.decodeBytes(
        bytes,
        verify: false,
      );
      final StringBuffer sb = StringBuffer();
      for (final String name in decoder.tables.keys) {
        sb.writeln('=== $name ===');
        final SpreadsheetTable table = decoder.tables[name]!;
        for (final dynamic row in table.rows) {
          if (row is! List) {
            continue;
          }
          sb.writeln(
            row.map(_xlsxCellToString).join('\t'),
          );
        }
        sb.writeln();
      }
      final String t = sb.toString();
      if (t.trim().isNotEmpty) {
        return PdfSyncfusionHelper.textToPdf(t);
      }
    } catch (_) {}
    final String fallback = _xlsxBytesToPlainText(bytes);
    return PdfSyncfusionHelper.textToPdf(
      fallback.trim().isEmpty ? '(내용 없음)' : fallback,
    );
  }

  static String _xlsxCellToString(dynamic cell) {
    if (cell == null) {
      return '';
    }
    if (cell is DateTime) {
      return cell.toIso8601String();
    }
    return cell.toString();
  }

  static List<String> _readSharedStrings(Archive arch) {
    final ArchiveFile? f = _findArchiveFileCi(arch, 'xl/sharedStrings.xml');
    if (f == null) {
      return <String>[];
    }
    final XmlDocument doc =
        XmlDocument.parse(utf8.decode(f.content as List<int>));
    XmlElement? sst;
    for (final XmlElement e in doc.descendants.whereType<XmlElement>()) {
      if (e.name.local == 'sst') {
        sst = e;
        break;
      }
    }
    if (sst == null) {
      return <String>[];
    }
    final List<String> out = <String>[];
    for (final XmlElement si in sst.childElements) {
      if (si.name.local == 'si') {
        out.add(_sharedStringFromSi(si));
      }
    }
    return out;
  }

  static String _sharedStringFromSi(XmlElement si) {
    final StringBuffer sb = StringBuffer();
    for (final XmlElement el in si.descendants.whereType<XmlElement>()) {
      if (el.name.local == 't') {
        sb.write(el.innerText);
      }
    }
    if (sb.isEmpty) {
      return si.innerText.trim();
    }
    return sb.toString();
  }

  static ArchiveFile? _findArchiveFileCi(Archive arch, String path) {
    final String want = path.replaceAll('\\', '/').toLowerCase();
    for (final ArchiveFile f in arch.files) {
      if (f.name.replaceAll('\\', '/').toLowerCase() == want) {
        return f;
      }
    }
    return arch.findFile(path);
  }

  static Map<String, String> _readWorkbookRels(Archive arch) {
    final ArchiveFile? f = _findArchiveFileCi(arch, 'xl/_rels/workbook.xml.rels');
    if (f == null) {
      return <String, String>{};
    }
    final XmlDocument doc =
        XmlDocument.parse(utf8.decode(f.content as List<int>));
    final Map<String, String> idToTarget = <String, String>{};
    for (final XmlElement rel in doc.descendants.whereType<XmlElement>()) {
      if (rel.name.local != 'Relationship') {
        continue;
      }
      final String? id = rel.getAttribute('Id');
      final String? target = rel.getAttribute('Target');
      if (id != null && target != null && target.isNotEmpty) {
        idToTarget[id] = target;
      }
    }
    return idToTarget;
  }

  static List<({String name, String path})> _readSheetPaths(Archive arch) {
    final ArchiveFile? wb = _findArchiveFileCi(arch, 'xl/workbook.xml');
    if (wb == null) {
      return <({String name, String path})>[];
    }
    final Map<String, String> rels = _readWorkbookRels(arch);
    final XmlDocument doc =
        XmlDocument.parse(utf8.decode(wb.content as List<int>));
    final List<({String name, String path})> sheets =
        <({String name, String path})>[];
    for (final XmlElement sheet
        in doc.descendants.whereType<XmlElement>()) {
      if (sheet.name.local != 'sheet') {
        continue;
      }
      final String? name = sheet.getAttribute('name');
      String? rid;
      for (final XmlAttribute a in sheet.attributes) {
        if (a.localName == 'id' &&
            a.namespaceUri != null &&
            a.namespaceUri!.contains('relationships')) {
          rid = a.value;
          break;
        }
      }
      rid ??= sheet.getAttribute('r:id');
      if (rid == null) {
        for (final XmlAttribute a in sheet.attributes) {
          if (a.name.prefix == 'r' && a.name.local == 'id') {
            rid = a.value;
            break;
          }
        }
      }
      if (name == null || rid == null) {
        continue;
      }
      final String? relTarget = rels[rid];
      if (relTarget == null) {
        continue;
      }
      final String path =
          relTarget.startsWith('/') ? relTarget.substring(1) : relTarget;
      final String full = path.startsWith('xl/') ? path : 'xl/$path';
      sheets.add((name: name, path: full));
    }
    return sheets;
  }

  static int _colLettersToIndex(String letters) {
    int n = 0;
    for (int i = 0; i < letters.length; i++) {
      final int c = letters.codeUnitAt(i);
      if (c < 0x41 || c > 0x5A) {
        break;
      }
      n = n * 26 + (c - 0x40);
    }
    return n - 1;
  }

  static ({int col, int row})? _parseCellRef(String ref) {
    final RegExpMatch? m =
        RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(ref.trim());
    if (m == null) {
      return null;
    }
    final String colL = m.group(1)!.toUpperCase();
    final int row = int.tryParse(m.group(2)!) ?? 0;
    return (col: _colLettersToIndex(colL), row: row);
  }

  static String _cellDisplayText(
    XmlElement c,
    List<String> sharedStrings,
  ) {
    final String? t = c.getAttribute('t');
    final XmlElement? vEl = _firstChildLocal(c, 'v');
    final XmlElement? isEl = _firstChildLocal(c, 'is');
    if (t == 'inlineStr' && isEl != null) {
      final StringBuffer sb = StringBuffer();
      for (final XmlElement te in isEl.findAllElements('t')) {
        sb.write(te.innerText);
      }
      return sb.toString();
    }
    if (vEl == null) {
      return '';
    }
    final String raw = vEl.innerText;
    if (t == 's') {
      final int? i = int.tryParse(raw);
      if (i != null && i >= 0 && i < sharedStrings.length) {
        return sharedStrings[i];
      }
      return '';
    }
    if (t == 'b') {
      return raw == '1' ? 'TRUE' : 'FALSE';
    }
    if (t == 'str') {
      return raw;
    }
    return raw;
  }

  static XmlElement? _firstChildLocal(XmlElement parent, String local) {
    for (final XmlNode n in parent.children) {
      if (n is XmlElement && n.name.local == local) {
        return n;
      }
    }
    return null;
  }

  static String _readSheetPlainText(
    Archive arch,
    String sheetPath,
    List<String> sharedStrings,
  ) {
    final ArchiveFile? f = _findArchiveFileCi(arch, sheetPath);
    if (f == null) {
      return '';
    }
    final XmlDocument doc =
        XmlDocument.parse(utf8.decode(f.content as List<int>));
    XmlElement? sheetData;
    for (final XmlElement e in doc.descendants.whereType<XmlElement>()) {
      if (e.name.local == 'sheetData') {
        sheetData = e;
        break;
      }
    }
    if (sheetData == null) {
      return '';
    }
    final Map<int, Map<int, String>> rowMap = <int, Map<int, String>>{};
    for (final XmlElement rowEl in sheetData.childElements) {
      if (rowEl.name.local != 'row') {
        continue;
      }
      final int? rowR = int.tryParse(rowEl.getAttribute('r') ?? '');
      if (rowR == null || rowR <= 0) {
        continue;
      }
      int nextCol = 0;
      for (final XmlElement c in rowEl.childElements) {
        if (c.name.local != 'c') {
          continue;
        }
        final String? ref = c.getAttribute('r');
        late final int col;
        late final int rowNum;
        if (ref != null && ref.isNotEmpty) {
          final ({int col, int row})? p = _parseCellRef(ref);
          if (p == null) {
            continue;
          }
          col = p.col;
          rowNum = p.row;
          nextCol = col + 1;
        } else {
          col = nextCol;
          nextCol++;
          rowNum = rowR;
        }
        rowMap
            .putIfAbsent(rowNum, () => <int, String>{})[col] =
            _cellDisplayText(c, sharedStrings);
      }
    }
    final List<int> rowNums = rowMap.keys.toList()..sort();
    final StringBuffer sb = StringBuffer();
    for (final int rn in rowNums) {
      final Map<int, String>? cells = rowMap[rn];
      if (cells == null || cells.isEmpty) {
        sb.writeln();
        continue;
      }
      final List<int> cols = cells.keys.toList()..sort();
      final int maxCol = cols.last;
      for (int col = 0; col <= maxCol; col++) {
        if (col > 0) {
          sb.write('\t');
        }
        sb.write(cells[col] ?? '');
      }
      sb.writeln();
    }
    return sb.toString();
  }

  static String _xlsxBytesToPlainText(Uint8List bytes) {
    final Archive arch = ZipDecoder().decodeBytes(bytes);
    final List<String> sharedStrings = _readSharedStrings(arch);
    final List<({String name, String path})> sheets = _readSheetPaths(arch);
    if (sheets.isEmpty) {
      return '';
    }
    final StringBuffer out = StringBuffer();
    for (final ({String name, String path}) s in sheets) {
      out.writeln('=== ${s.name} ===');
      out.writeln(_readSheetPlainText(arch, s.path, sharedStrings));
      out.writeln();
    }
    return out.toString();
  }

  static Future<Uint8List> fromPptx(Uint8List bytes) async {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final List<String> slidePaths = <String>[];
    for (final ArchiveFile f in archive.files) {
      final String n = f.name;
      if (n.startsWith('ppt/slides/slide') && n.endsWith('.xml')) {
        slidePaths.add(n);
      }
    }
    slidePaths.sort();
    final StringBuffer sb = StringBuffer();
    for (final String path in slidePaths) {
      final ArchiveFile? f = archive.findFile(path);
      if (f == null) {
        continue;
      }
      final String xml = utf8.decode(f.content as List<int>);
      sb.writeln('--- $path ---');
      sb.writeln(_stripXml(xml));
      sb.writeln();
    }
    final String t = sb.toString();
    return PdfSyncfusionHelper.textToPdf(t.trim().isEmpty ? '(내용 없음)' : t);
  }

  static Future<Uint8List> fromDxf(Uint8List bytes) async {
    final String s = utf8.decode(bytes, allowMalformed: true);
    final StringBuffer sb = StringBuffer();
    final List<String> lines = s.split(RegExp(r'\r?\n'));
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim() == '1' && i + 1 < lines.length) {
        sb.writeln(lines[i + 1]);
      }
    }
    final String t = sb.toString();
    return PdfSyncfusionHelper.textToPdf(t.trim().isEmpty ? '(DXF 텍스트 없음)' : t);
  }

  /// HWPX(OOXML ZIP). 웹만으로는 한글「PDF로 저장」과 동일한 조판·글꼴은 불가하며, 본문 텍스트를 PDF로 옮깁니다.
  static Future<Uint8List> fromHwpx(Uint8List bytes) async {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final StringBuffer sb = StringBuffer();
    final List<String> paths = <String>[];
    for (final ArchiveFile f in archive.files) {
      if (f.isFile && f.name.contains('Contents/') && f.name.endsWith('.xml')) {
        paths.add(f.name);
      }
    }
    paths.sort();
    for (final String path in paths) {
      final ArchiveFile? f = archive.findFile(path);
      if (f == null) {
        continue;
      }
      try {
        final String raw = utf8.decode(f.content as List<int>);
        final XmlDocument doc = XmlDocument.parse(raw);
        final StringBuffer chunk = StringBuffer();
        for (final XmlElement el in doc.descendants.whereType<XmlElement>()) {
          if (el.name.local != 't') {
            continue;
          }
          final String ns = el.name.namespaceUri ?? '';
          if (ns.contains('hancom') ||
              ns.contains('hwp') ||
              ns.contains('Hwp')) {
            final String txt = el.innerText.trim();
            if (txt.isNotEmpty) {
              chunk.writeln(txt);
            }
          }
        }
        if (chunk.toString().trim().isEmpty) {
          for (final XmlElement el in doc.descendants.whereType<XmlElement>()) {
            if (el.name.local == 't') {
              final String txt = el.innerText.trim();
              if (txt.isNotEmpty) {
                chunk.writeln(txt);
              }
            }
          }
        }
        sb.write(chunk);
      } catch (_) {}
    }
    if (sb.toString().trim().isEmpty) {
      for (final ArchiveFile f in archive.files) {
        if (!f.isFile || !f.name.toLowerCase().endsWith('.xml')) {
          continue;
        }
        try {
          final String raw = utf8.decode(f.content as List<int>);
          final XmlDocument doc = XmlDocument.parse(raw);
          final String plain = _stripXml(doc.toXmlString()).trim();
          if (plain.isNotEmpty) {
            sb.writeln(plain);
          }
        } catch (_) {}
      }
    }
    final String t = sb.toString().trim();
    if (t.isEmpty) {
      throw StateError(
        'HWPX에서 본문을 읽지 못했습니다. 파일이 손상되었거나 암호화되어 있을 수 있습니다.',
      );
    }
    return PdfSyncfusionHelper.textToPdf(t);
  }

  /// OLE Compound .hwp — 브라우저만으로는 한글과 동일한 PDF를 만들 수 없습니다.
  /// (온라인 변환기는 서버에서 처리합니다. `CONVERT_HWP_ENDPOINT` 설정 시 자체 API 호출 가능.)
  static Never oleHwpNotSupported() {
    throw StateError(
      'OLE 형식 .hwp는 이 브라우저에서 직접 PDF로 만들 수 없습니다. '
      '한글에서 HWPX로 저장하거나 PDF로 저장한 뒤 사용하거나, '
      '변환 서버를 두고 CONVERT_HWP_ENDPOINT를 빌드에 정의하세요.',
    );
  }
}
