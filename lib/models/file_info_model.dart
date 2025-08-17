import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'dart:async'; // Added missing import for Completer
import '../services/file_upload_service.dart';

class FileInfo {
  final String fileName;
  final String? fileExtension;
  final Uint8List bytes;
  final bool isImage;
  final dynamic originalFile; // XFile 또는 html.File
  String? uploadedUrl; // 업로드 후 URL 저장
  String? originalFileName; // 원본 파일명 (한글 등)

  FileInfo({
    required this.fileName,
    this.fileExtension,
    required this.bytes,
    required this.isImage,
    required this.originalFile,
    this.uploadedUrl,
    this.originalFileName,
  });

  String get displayName {
    // 원본 파일명이 있으면 그것을 사용, 없으면 기존 로직
    if (originalFileName != null) {
      return originalFileName!;
    }
    if (fileExtension != null) {
      return fileName.endsWith(fileExtension!) ? fileName : '$fileName.$fileExtension';
    }
    return fileName;
  }

  /// 파일 업로드
  Future<bool> upload() async {
    try {
      final result = await FileUploadService.uploadFile(originalFile);
      if (result != null) {
        uploadedUrl = result['url'];
        originalFileName = result['originalName'];
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('파일 업로드 실패: $e');
      rethrow; // 오류를 다시 던져서 호출자가 처리할 수 있도록 함
    }
  }

  /// 업로드된 파일 정보를 Map으로 변환
  Map<String, String> toMap() {
    return {
      'url': uploadedUrl ?? '',
      'name': originalFileName ?? displayName, // 원본 파일명 우선 사용
    };
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
      debugPrint('XFile to FileInfo 변환 실패: $e');
      return null;
    }
  }

  static Future<FileInfo?> fromHtmlFile(html.File file) async {
    try {
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();

      reader.onError.listen((event) {
        completer.completeError('파일 읽기 실패: $event');
      });

      reader.onLoadEnd.listen((event) {
        if (reader.result != null) {
          completer.complete(reader.result as Uint8List);
        } else {
          completer.completeError('파일 읽기 실패');
        }
      });

      reader.readAsArrayBuffer(file);
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
      debugPrint('html.File to FileInfo 변환 실패: $e');
      return null;
    }
  }
} 