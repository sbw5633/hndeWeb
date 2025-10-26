import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

/// 파일 처리 관련 공통 기능을 제공하는 위젯
class FileHandlerWidget {
  /// 파일 선택 (단일)
  static Future<Uint8List?> selectFile({
    required List<String> acceptedTypes,
    required String acceptDescription,
  }) async {
    final completer = Completer<Uint8List?>();
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement()
      ..accept = acceptedTypes.join(',');
    
    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        
        reader.onLoadEnd.listen((e) {
          completer.complete(Uint8List.fromList(reader.result as List<int>));
        });
        
        reader.onError.listen((e) {
          completer.completeError(e);
        });
        
        reader.readAsArrayBuffer(file);
      } else {
        completer.complete(null);
      }
    });
    
    uploadInput.click();
    return completer.future;
  }

  /// 파일 선택 (다중)
  static Future<List<FileData>> selectFiles({
    required List<String> acceptedTypes,
    required String acceptDescription,
    int? maxFiles,
  }) async {
    final completer = Completer<List<FileData>>();
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement()
      ..accept = acceptedTypes.join(',')
      ..multiple = true;
    
    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final fileDataList = <FileData>[];
        int processedCount = 0;
        
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final reader = html.FileReader();
          final fileCompleter = Completer<void>();
          
          reader.onLoadEnd.listen((e) {
            fileCompleter.complete();
          });
          
          reader.readAsArrayBuffer(file);
          await fileCompleter.future;
          
          fileDataList.add(FileData(
            data: Uint8List.fromList(reader.result as List<int>),
            fileName: file.name,
          ));
          
          processedCount++;
        }
        
        completer.complete(fileDataList);
      } else {
        completer.complete([]);
      }
    });
    
    uploadInput.click();
    return completer.future;
  }

  /// 파일 다운로드
  static void downloadFile({
    required Uint8List data,
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob([data], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// PDF 다운로드
  static void downloadPDF(Uint8List data, String fileName) {
    downloadFile(
      data: data,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }

  /// 이미지 다운로드
  static void downloadImage(Uint8List data, String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
    };
    
    downloadFile(
      data: data,
      fileName: fileName,
      mimeType: mimeTypes[ext] ?? 'image/png',
    );
  }
}

/// 파일 데이터를 담는 클래스
class FileData {
  final Uint8List data;
  final String fileName;

  FileData({
    required this.data,
    required this.fileName,
  });
}

