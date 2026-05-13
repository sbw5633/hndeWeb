import 'dart:typed_data';

import 'save_xlsx_stub.dart'
    if (dart.library.io) 'save_xlsx_io.dart' as save_xlsx_impl;

Future<bool> saveXlsxWithFilePicker({
  required Uint8List bytes,
  required String suggestedFileName,
  String dialogTitle = '근로내용확인신고 저장',
}) =>
    save_xlsx_impl.saveXlsxWithFilePicker(
      bytes: bytes,
      suggestedFileName: suggestedFileName,
      dialogTitle: dialogTitle,
    );
