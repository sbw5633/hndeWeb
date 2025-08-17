import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'dart:async';
import 'aws/s3_service.dart';
import '../models/file_info_model.dart';

class FileUploadService {
  /// 파일을 AWS S3에 업로드
  static Future<Map<String, String>?> uploadFile(dynamic file) async {
    try {
      return await S3Service.uploadFile(file);
    } catch (e) {
      debugPrint('파일 업로드 실패: $e');
      return null;
    }
  }

  /// 파일 정보를 FileInfo로 변환
  static Future<FileInfo?> createFileInfo(dynamic file) async {
    try {
      if (file is XFile) {
        return await FileInfo.fromXFile(file);
      } else if (file is html.File) {
        return await FileInfo.fromHtmlFile(file);
      } else {
        throw Exception('지원하지 않는 파일 타입: ${file.runtimeType}');
      }
    } catch (e) {
      debugPrint('FileInfo 생성 실패: $e');
      return null;
    }
  }
} 