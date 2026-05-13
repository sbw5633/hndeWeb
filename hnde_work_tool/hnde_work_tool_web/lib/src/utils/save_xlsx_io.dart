import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 데스크톱 등 IO 플랫폼에서 [FilePicker.saveFile]로 xlsx를 저장합니다.
Future<bool> saveXlsxWithFilePicker({
  required Uint8List bytes,
  required String suggestedFileName,
  String dialogTitle = '근로내용확인신고 저장',
}) async {
  final String? path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: suggestedFileName,
    type: FileType.custom,
    allowedExtensions: <String>['xlsx'],
  );
  if (path == null || path.isEmpty) {
    return false;
  }
  final String out =
      path.toLowerCase().endsWith('.xlsx') ? path : '$path.xlsx';
  await File(out).writeAsBytes(bytes);
  return true;
}
