import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'dart:async'; // Added missing import for Completer

class FileInfo {
  final String fileName;
  final String? fileExtension;
  final Uint8List bytes;
  final bool isImage;
  final dynamic originalFile; // XFile 또는 html.File

  FileInfo({
    required this.fileName,
    this.fileExtension,
    required this.bytes,
    required this.isImage,
    required this.originalFile,
  });

  String get displayName {
    if (fileExtension != null) {
      return fileName.endsWith(fileExtension!) ? fileName : '$fileName.$fileExtension';
    }
    return fileName;
  }

  static Future<FileInfo?> fromXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final fullFileName = file.name;
      
      // 확장자 추출 (마지막 점 이후)
      String? extension;
      String fileNameWithoutExt;
      
      if (fullFileName.contains('.')) {
        final lastDotIndex = fullFileName.lastIndexOf('.');
        extension = fullFileName.substring(lastDotIndex + 1);
        fileNameWithoutExt = fullFileName.substring(0, lastDotIndex);
      } else {
        extension = null;
        fileNameWithoutExt = fullFileName;
      }
      
      return FileInfo(
        fileName: fileNameWithoutExt,
        fileExtension: extension,
        bytes: bytes,
        isImage: true,
        originalFile: file,
      );
    } catch (e) {
      print('XFile to FileInfo 변환 실패: $e');
      return null;
    }
  }

  static Future<FileInfo?> fromHtmlFile(html.File file) async {
    try {
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      
      reader.onError.listen((error) {
        completer.completeError('파일 읽기 실패: $error');
      });
      
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((event) {
        if (reader.result != null) {
          completer.complete(reader.result as Uint8List);
        } else {
          completer.completeError('파일 읽기 실패');
        }
      });
      
      final bytes = await completer.future;
      final fullFileName = file.name;
      
      // 확장자 추출 (마지막 점 이후)
      String? extension;
      String fileNameWithoutExt;
      
      if (fullFileName.contains('.')) {
        final lastDotIndex = fullFileName.lastIndexOf('.');
        extension = fullFileName.substring(lastDotIndex + 1);
        fileNameWithoutExt = fullFileName.substring(0, lastDotIndex);
      } else {
        extension = null;
        fileNameWithoutExt = fullFileName;
      }
      
      return FileInfo(
        fileName: fileNameWithoutExt,
        fileExtension: extension,
        bytes: bytes,
        isImage: false,
        originalFile: file,
      );
    } catch (e) {
      print('html.File to FileInfo 변환 실패: $e');
      return null;
    }
  }
} 