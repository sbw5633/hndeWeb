import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:image_picker/image_picker.dart';

class S3Service {
  // Vercel에 배포된 백엔드 URL
  static const String _baseUrl = 'https://hnde-backend.vercel.app/api';
  
  // S3 버킷 정보
  static const String _bucketName = 'hnde-web-files';
  static const String _region = 'ap-northeast-2';
  
  /// 백엔드를 통해 Pre-signed URL을 받아와서 S3에 업로드
  static Future<Map<String, String>?> uploadFile(dynamic file) async {
    try {
      debugPrint('파일 업로드 시작: ${file.runtimeType}');
      Uint8List bytes;
      String originalFileName;
      
      // 파일 읽기 (기존 코드와 동일)
      if (file is html.File) {
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();
        
        reader.onError.listen((error) {
          debugPrint('FileReader 오류: $error');
          completer.completeError('파일 읽기 실패: $error');
        });
        
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((event) {
          if (reader.result != null) {
            final bytes = reader.result as Uint8List;
            debugPrint('파일 읽기 완료: ${bytes.length} bytes');
            completer.complete(bytes);
          } else {
            completer.completeError('파일 읽기 실패');
          }
        });
        
        bytes = await completer.future;
        originalFileName = file.name;
        debugPrint('파일명: $originalFileName, 크기: ${bytes.length} bytes');
      } else if (file is XFile) {
        bytes = await file.readAsBytes();
        originalFileName = file.name;
        debugPrint('XFile 읽기 완료: $originalFileName, 크기: ${bytes.length} bytes');
      } else {
        throw Exception('지원하지 않는 파일 타입: ${file.runtimeType}');
      }

      // 파일 크기 제한 확인 (10MB) - 기존과 동일
      const maxFileSize = 10 * 1024 * 1024;
      if (bytes.length > maxFileSize) {
        throw Exception('파일 크기가 너무 큽니다. 최대 10MB까지 업로드 가능합니다.');
      }

      // 🎯 중요: 백엔드에서 Pre-signed URL 요청
      final presignedUrl = await _getPresignedUrl(originalFileName, _getContentType(originalFileName));
      if (presignedUrl == null) {
        throw Exception('Pre-signed URL을 받을 수 없습니다.');
      }

      // Pre-signed URL로 S3에 업로드
      final contentType = _getContentType(originalFileName);
      debugPrint('Pre-signed URL로 업로드 시작: $presignedUrl');

      final encodedFileName = Uri.encodeComponent(originalFileName);
      
      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {
          'content-type': contentType,
          'content-disposition': 'attachment; filename="$encodedFileName"',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 30));

      debugPrint('S3 업로드 응답: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // �� 중요: Pre-signed URL에서 파일명 추출
        final key = _extractKeyFromPresignedUrl(presignedUrl);
        final imageUrl = 'https://$_bucketName.s3.$_region.amazonaws.com/$key';
        
        debugPrint('S3 업로드 성공: $imageUrl');
        debugPrint('원본 파일명: $originalFileName');
        debugPrint('S3 키: $key');
        
        return {
          'url': imageUrl,           // 기존과 동일한 키
          'originalName': originalFileName,  // 기존과 동일한 키
          's3Key': key,              // Pre-signed URL에서 추출한 키
        };
      } else {
        debugPrint('S3 업로드 실패: ${response.statusCode} - ${response.body}');
        throw Exception('파일 업로드에 실패했습니다.');
      }
      
    } catch (e) {
      debugPrint('파일 업로드 오류: $e');
      rethrow;
    }
  }

  /// �� 중요: Pre-signed URL에서 S3 키 추출
  static String _extractKeyFromPresignedUrl(String presignedUrl) {
    try {
      final uri = Uri.parse(presignedUrl);
      final path = uri.path;
      
      // URL에서 /uploads/ 이후 부분 추출
      if (path.contains('/uploads/')) {
        final key = path.split('/uploads/').last.split('?').first;
        debugPrint('Pre-signed URL에서 추출한 키: $key');
        return 'uploads/$key';
      }
      
      // 기본값: timestamp_random.extension
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (DateTime.now().microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      final extension = 'png'; // 기본값
      final defaultKey = 'uploads/${timestamp}_$random.$extension';
      debugPrint('기본 키 생성: $defaultKey');
      return defaultKey;
    } catch (e) {
      debugPrint('키 추출 실패: $e');
      // 기본값 반환
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (DateTime.now().microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'uploads/${timestamp}_$random.png';
    }
  }

/// 🎯 중요: 백엔드에서 Pre-signed URL 요청 시 Content-Disposition 포함
static Future<String?> _getPresignedUrl(String fileName, String fileType) async {
  try {
    debugPrint('Vercel 백엔드에서 Pre-signed URL 요청: $_baseUrl/get-upload-url');
    debugPrint('요청 파일명: $fileName, 파일타입: $fileType');
    
    // 🎯 중요: Content-Disposition 헤더 정보도 함께 전송
    final encodedFileName = Uri.encodeComponent(fileName);
    final contentDisposition = 'attachment; filename="$encodedFileName"';
    
    final response = await http.get(
      Uri.parse('$_baseUrl/get-upload-url?fileName=$fileName&fileType=$fileType&contentDisposition=$contentDisposition'),
    ).timeout(const Duration(seconds: 10));

    debugPrint('Vercel 백엔드 응답: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final uploadUrl = data['uploadUrl'];
      debugPrint('Pre-signed URL 받음: $uploadUrl');
      return uploadUrl;
    } else {
      debugPrint('Pre-signed URL 요청 실패: ${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    debugPrint('Pre-signed URL 요청 오류: $e');
    return null;
  }
}

  /// 파일 타입에 따른 Content-Type 반환 (기존과 동일)
  static String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Vercel 백엔드 서버 상태 확인
  static Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Vercel 백엔드 상태 확인 실패: $e');
      return false;
    }
  }

  /// 환경 정보 출력
  static void printEnvironmentInfo() {
    debugPrint('=== S3Service 환경 정보 ===');
    debugPrint('Vercel 백엔드 URL: $_baseUrl');
    debugPrint('S3 버킷: $_bucketName');
    debugPrint('S3 리전: $_region');
    debugPrint('개발/운영 환경 모두 동일한 백엔드 사용');
    debugPrint('========================');
  }
}