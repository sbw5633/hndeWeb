import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';

class S3Service {
  // AWS S3 설정 정보
  static const String _accessKeyId = 'AKIAZQSDA7F3LDKMFCG7';
  static const String _secretAccessKey = '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';
  static const String _region = 'ap-northeast-2';
  static const String _bucketName = 'hnde-web-files';
  
  // S3 엔드포인트
  static String get _endpoint => 'https://$_bucketName.s3.$_region.amazonaws.com';

  /// CORS 설정 확인 및 가이드
  static void _checkCorsSettings() {
    debugPrint('=== S3 CORS 설정 확인 ===');
    debugPrint('버킷: $_bucketName');
    debugPrint('리전: $_region');
    debugPrint('');
    debugPrint('AWS 콘솔에서 다음 CORS 설정을 적용하세요:');
    debugPrint('''
[
  {
    "AllowedHeaders": [
      "*"
    ],
    "AllowedMethods": [
      "GET",
      "PUT",
      "POST",
      "DELETE",
      "HEAD"
    ],
    "AllowedOrigins": [
      "*"
    ],
    "ExposeHeaders": [
      "ETag"
    ]
  }
]
    ''');
    debugPrint('설정 방법:');
    debugPrint('1. AWS S3 콘솔 접속');
    debugPrint('2. 버킷 $_bucketName 선택');
    debugPrint('3. 권한 탭 클릭');
    debugPrint('4. CORS 섹션에서 위 설정 적용');
    debugPrint('========================');
  }

  /// AWS Signature V4를 사용하여 S3에 직접 업로드
  static Future<Map<String, String>?> uploadFile(dynamic file) async {
    try {
      debugPrint('파일 업로드 시작: ${file.runtimeType}');
      Uint8List bytes;
      String originalFileName;
      
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

      // 파일 크기 제한 확인 (10MB)
      const maxFileSize = 10 * 1024 * 1024; // 10MB
      if (bytes.length > maxFileSize) {
        throw Exception('파일 크기가 너무 큽니다. 최대 10MB까지 업로드 가능합니다.');
      }

      // 이미지 파일인지 확인
      final isImage = _isImageFile(originalFileName);
      debugPrint('이미지 파일 여부: $isImage');

      // S3 업로드 재시도 로직
      const maxRetries = 3;
      Map<String, String>? uploadResult;
      
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          debugPrint('S3 업로드 시도 $attempt/$maxRetries');
          
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final random = (DateTime.now().microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
          
          // 확장자 추출
          final extension = originalFileName.split('.').last.toLowerCase();
          final s3FileName = '${timestamp}_$random.$extension';
          final key = 'uploads/$s3FileName';
          
          debugPrint('S3 업로드 시작: $key (원본: $originalFileName)');
          
          final uploadUrl = await _uploadToS3(key, bytes, originalFileName);
          
          if (uploadUrl != null) {
            debugPrint('S3 업로드 성공: $uploadUrl');
            return {
              'url': uploadUrl,
              'originalName': originalFileName,
              's3Key': key,
            };
          } else {
            debugPrint('S3 업로드 실패 (시도 $attempt/$maxRetries)');
            if (attempt < maxRetries) {
              await Future.delayed(Duration(seconds: attempt * 2));
            }
          }
        } catch (e) {
          debugPrint('S3 업로드 오류 (시도 $attempt/$maxRetries): $e');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        }
      }
      
      debugPrint('S3 업로드 최종 실패: $maxRetries회 시도 후 실패');
      throw Exception('파일 업로드에 실패했습니다. 네트워크 연결을 확인하고 다시 시도해주세요.');
      
    } catch (e) {
      debugPrint('파일 업로드 오류: $e');
      rethrow;
    }
  }

  /// 파일 타입에 따른 Content-Type 반환
  static String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    // 이미지 파일 타입
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
      case 'svg':
        return 'image/svg+xml';
      case 'bmp':
        return 'image/bmp';
      case 'ico':
        return 'image/x-icon';
      // 문서 파일 타입
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      // 텍스트 파일 타입
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'html':
      case 'htm':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      // 압축 파일 타입
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      case 'tar':
        return 'application/x-tar';
      case 'gz':
        return 'application/gzip';
      default:
        return 'application/octet-stream';
    }
  }

  /// AWS Signature V4를 사용하여 S3에 직접 업로드
  static Future<String?> _uploadToS3(String key, Uint8List data, String fileName) async {
    try {
      final now = DateTime.now().toUtc();
      final date = now.toIso8601String().substring(0, 10).replaceAll('-', '');
      final datetime = now.toIso8601String().replaceAll('-', '').replaceAll(':', '').substring(0, 15) + 'Z';
      
      final contentType = _getContentType(fileName);
      final contentLength = data.length.toString();
      final payloadHash = sha256.convert(data).toString();
      
      // URL 인코딩된 키 생성 (경로 구분자는 인코딩하지 않음)
      final pathParts = key.split('/');
      final encodedPathParts = pathParts.map((part) => Uri.encodeComponent(part)).toList();
      final encodedKey = encodedPathParts.join('/');
      
      debugPrint('S3 업로드 준비:');
      debugPrint('- 원본 키: $key');
      debugPrint('- 인코딩된 키: $encodedKey');
      debugPrint('- 경로 파트: $pathParts');
      debugPrint('- 인코딩된 경로 파트: $encodedPathParts');
      debugPrint('- 파일명: $fileName');
      debugPrint('- 크기: $contentLength bytes');
      debugPrint('- 타입: $contentType');
      debugPrint('- 버킷: $_bucketName');
      debugPrint('- 리전: $_region');
      debugPrint('- 날짜: $date');
      debugPrint('- 시간: $datetime');
      debugPrint('- 페이로드 해시: $payloadHash');
      
      // 헤더 정렬을 위한 맵 (소문자로 정렬)
      final headers = <String, String>{
        'host': '$_bucketName.s3.$_region.amazonaws.com',
        'content-type': contentType,
        'content-length': contentLength,
        'x-amz-date': datetime,
        'x-amz-content-sha256': payloadHash,
      };
      
      // Content-Disposition 헤더 추가 (다운로드 시 원본 파일명 사용)
      // 한글 파일명은 URL 인코딩하여 처리
      final encodedFileName = Uri.encodeComponent(fileName);
      headers['content-disposition'] = 'attachment; filename="$encodedFileName"';
      
      // Canonical Request 생성 (인코딩된 키 사용)
      final canonicalRequest = _createCanonicalRequest(
        'PUT',
        '/$encodedKey',
        headers,
        '',
        contentType,
        payloadHash,
      );
      
      debugPrint('Canonical Request:');
      debugPrint(canonicalRequest);
      
      // String to Sign 생성
      const algorithm = 'AWS4-HMAC-SHA256';
      final credentialScope = '$date/$_region/s3/aws4_request';
      final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();
      final stringToSign = '$algorithm\n$datetime\n$credentialScope\n$canonicalRequestHash';
      
      debugPrint('String to Sign:');
      debugPrint(stringToSign);
      
      // Signature 생성
      final signature = _calculateSignature(stringToSign, date);
      
      debugPrint('계산된 서명: $signature');
      
      // Authorization 헤더 생성
      final signedHeaders = headers.keys.map((k) => k.toLowerCase()).toList()..sort();
      final authorization = '$algorithm Credential=$_accessKeyId/$credentialScope, SignedHeaders=${signedHeaders.join(';')}, Signature=$signature';
      
      debugPrint('Authorization 헤더:');
      debugPrint(authorization);
      
      // HTTP 요청 전송 (인코딩된 키 사용)
      debugPrint('S3 업로드 요청 시작...');
      debugPrint('URL: https://$_bucketName.s3.$_region.amazonaws.com/$encodedKey');
      debugPrint('Content-Type: $contentType');
      debugPrint('Content-Length: $contentLength');
      debugPrint('X-Amz-Date: $datetime');
      debugPrint('X-Amz-Content-Sha256: $payloadHash');
      debugPrint('Authorization: $authorization');
      
      final response = await http.put(
        Uri.parse('https://$_bucketName.s3.$_region.amazonaws.com/$encodedKey'),
        headers: {
          'Content-Type': contentType,
          'Content-Length': contentLength,
          'X-Amz-Date': datetime,
          'X-Amz-Content-Sha256': payloadHash,
          'Content-Disposition': 'attachment; filename="$encodedFileName"',
          'Authorization': authorization,
        },
        body: data,
      ).timeout(const Duration(seconds: 60)); // 이미지 파일은 더 큰 타임아웃

      debugPrint('S3 응답 상태: ${response.statusCode}');
      debugPrint('S3 응답 헤더: ${response.headers}');
      debugPrint('S3 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final url = 'https://$_bucketName.s3.$_region.amazonaws.com/$encodedKey';
        debugPrint('S3 업로드 성공: $url');
        return url;
      } else {
        debugPrint('S3 업로드 실패: ${response.statusCode} - ${response.body}');
        
        // SignatureDoesNotMatch 오류인 경우 더 자세한 정보 제공
        if (response.statusCode == 403 && response.body.contains('SignatureDoesNotMatch')) {
          debugPrint('서명 불일치 오류:');
          debugPrint('1. AWS 자격 증명 확인');
          debugPrint('2. 시계 동기화 확인');
          debugPrint('3. 서명 계산 로직 확인');
          debugPrint('계산된 서명: $signature');
          debugPrint('파일명: $fileName');
          debugPrint('파일 크기: ${data.length} bytes');
          debugPrint('Content-Type: $contentType');
          debugPrint('원본 키: $key');
          debugPrint('인코딩된 키: $encodedKey');
          debugPrint('Canonical Request:');
          debugPrint(canonicalRequest);
          debugPrint('String to Sign:');
          debugPrint(stringToSign);
          
          // AWS에서 제공한 서명과 비교
          if (response.body.contains('SignatureProvided')) {
            final signatureProvided = response.body.split('SignatureProvided>')[1].split('<')[0];
            debugPrint('AWS에서 제공한 서명: $signatureProvided');
            debugPrint('우리가 계산한 서명: $signature');
            debugPrint('서명 일치 여부: ${signature == signatureProvided}');
          }
        }
        
        // 다른 오류들도 처리
        if (response.statusCode == 400) {
          debugPrint('잘못된 요청 (400): 요청 형식이 잘못되었습니다.');
        } else if (response.statusCode == 401) {
          debugPrint('인증 실패 (401): AWS 자격 증명이 잘못되었습니다.');
        } else if (response.statusCode == 403) {
          debugPrint('권한 없음 (403): S3 버킷에 대한 권한이 없습니다.');
        } else if (response.statusCode == 404) {
          debugPrint('버킷을 찾을 수 없음 (404): S3 버킷이 존재하지 않습니다.');
        } else if (response.statusCode == 500) {
          debugPrint('서버 오류 (500): AWS S3 서버 오류입니다.');
        }
        
        return null;
      }
    } catch (e) {
      debugPrint('S3 업로드 오류: $e');
      if (e.toString().contains('XMLHttpRequest')) {
        debugPrint('CORS 오류 감지: 브라우저에서 S3로의 직접 업로드가 차단되었습니다.');
        _checkCorsSettings();
      }
      return null;
    }
  }

  /// Canonical Request 생성 (수정된 버전)
  static String _createCanonicalRequest(
    String method,
    String uri,
    Map<String, String> headers,
    String queryString,
    String contentType,
    String payloadHash,
  ) {
    // 헤더 정렬 (소문자로 변환 후 정렬)
    final canonicalHeaders = headers.entries
        .map((e) => '${e.key.toLowerCase()}:${e.value.trim()}')
        .toList()
      ..sort();
    
    final signedHeaders = headers.keys
        .map((k) => k.toLowerCase())
        .toList()
      ..sort();
    
    final canonicalRequest = [
      method,
      uri,
      queryString,
      canonicalHeaders.join('\n') + '\n',
      signedHeaders.join(';'),
      payloadHash,
    ].join('\n');
    
    debugPrint('Canonical Request 구성:');
    debugPrint('Method: $method');
    debugPrint('URI: $uri');
    debugPrint('Query: $queryString');
    debugPrint('Headers: ${canonicalHeaders.join('\n')}');
    debugPrint('Signed Headers: ${signedHeaders.join(';')}');
    debugPrint('Payload Hash: $payloadHash');
    
    return canonicalRequest;
  }

  /// AWS Signature V4 서명 계산
  static String _calculateSignature(String stringToSign, String date) {
    try {
      // 1단계: kDate 계산 (AWS4 + SecretAccessKey)
      final kDate = Hmac(sha256, utf8.encode('AWS4$_secretAccessKey')).convert(utf8.encode(date));
      debugPrint('kDate: ${kDate.toString()}');
      
      // 2단계: kRegion 계산
      final kRegion = Hmac(sha256, kDate.bytes).convert(utf8.encode(_region));
      debugPrint('kRegion: ${kRegion.toString()}');
      
      // 3단계: kService 계산
      final kService = Hmac(sha256, kRegion.bytes).convert(utf8.encode('s3'));
      debugPrint('kService: ${kService.toString()}');
      
      // 4단계: kSigning 계산
      final kSigning = Hmac(sha256, kService.bytes).convert(utf8.encode('aws4_request'));
      debugPrint('kSigning: ${kSigning.toString()}');
      
      // 5단계: 최종 서명 계산
      final signature = Hmac(sha256, kSigning.bytes).convert(utf8.encode(stringToSign)).toString();
      debugPrint('최종 서명: $signature');
      
      return signature;
    } catch (e) {
      debugPrint('서명 계산 오류: $e');
      rethrow;
    }
  }

  /// S3 Presigned URL을 사용하여 파일 업로드 (CORS 문제 해결)
  static Future<String?> uploadFileWithPresignedUrl(dynamic file) async {
    try {
      debugPrint('Presigned URL 업로드 시작: ${file.runtimeType}');
      Uint8List bytes;
      String fileName;
      
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
        fileName = file.name;
        debugPrint('파일명: $fileName, 크기: ${bytes.length} bytes');
      } else if (file is XFile) {
        // XFile 처리
        bytes = await file.readAsBytes();
        fileName = file.name;
        debugPrint('XFile 읽기 완료: $fileName, 크기: ${bytes.length} bytes');
      } else {
        throw Exception('지원하지 않는 파일 타입: ${file.runtimeType}');
      }

      // Presigned URL 생성 (서버에서 받아와야 함)
      final presignedUrl = await _getPresignedUrl(fileName);
      if (presignedUrl == null) {
        throw Exception('Presigned URL을 받을 수 없습니다.');
      }

      // Presigned URL을 사용하여 파일 업로드
      final contentType = _getContentType(fileName);
      debugPrint('Presigned URL로 업로드 시작: $presignedUrl');
      
      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {
          'Content-Type': contentType,
        },
        body: bytes,
      ).timeout(const Duration(seconds: 30));

      debugPrint('Presigned URL 업로드 응답: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // 업로드 성공 시 파일 URL 반환
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final key = 'uploads/$timestamp/$fileName';
        final url = 'https://$_bucketName.s3.$_region.amazonaws.com/$key';
        debugPrint('Presigned URL 업로드 성공: $url');
        return url;
      } else {
        debugPrint('Presigned URL 업로드 실패: ${response.statusCode} - ${response.body}');
        throw Exception('파일 업로드에 실패했습니다.');
      }
      
    } catch (e) {
      debugPrint('Presigned URL 업로드 오류: $e');
      rethrow;
    }
  }

  /// Presigned URL을 서버에서 받아오는 메서드 (임시 구현)
  static Future<String?> _getPresignedUrl(String fileName) async {
    try {
      // 실제로는 서버 API를 호출하여 Presigned URL을 받아와야 함
      // 현재는 임시로 직접 생성
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final key = 'uploads/$timestamp/$fileName';
      
      // 임시로 직접 S3 업로드 시도 (실제로는 서버에서 받은 Presigned URL 제공)
      debugPrint('임시: 직접 S3 업로드 시도');
      return null; // 실제 구현에서는 서버에서 받은 Presigned URL 반환
    } catch (e) {
      debugPrint('Presigned URL 생성 실패: $e');
      return null;
    }
  }

  /// 이미지 파일인지 확인
  static bool _isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'ico'].contains(extension);
  }
} 