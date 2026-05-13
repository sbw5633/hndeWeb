/// Cloudinary 서비스 클래스를 정의하는 파일
///
/// 이 파일은 Cloudinary를 사용한 이미지 업로드 및 관리 기능을 제공합니다.
/// 이미지 업로드, 변환, 삭제 등의 기능을 포함합니다.

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../constants/app_constants.dart';

/// Cloudinary 서비스 클래스
///
/// Cloudinary API를 사용하여 이미지 업로드 및 관리를 담당합니다.
class CloudinaryService {
  // ==================== 상수 ====================

  /// Cloudinary API 기본 URL
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// 업로드 API 엔드포인트
  static const String _uploadEndpoint = '/image/upload';

  /// 삭제 API 엔드포인트
  static const String _deleteEndpoint = '/image/destroy';

  // ==================== 설정 ====================

  /// Cloudinary 클라우드 이름
  final String cloudName;

  /// Cloudinary API 키
  final String apiKey;

  /// Cloudinary API 시크릿
  final String apiSecret;

  /// 업로드 프리셋
  final String uploadPreset;

  // ==================== 생성자 ====================

  /// 기본 생성자
  ///
  /// [cloudName] Cloudinary 클라우드 이름
  /// [apiKey] Cloudinary API 키
  /// [apiSecret] Cloudinary API 시크릿
  /// [uploadPreset] 업로드 프리셋 (기본값: 'ml_default')
  CloudinaryService({
    required this.cloudName,
    required this.apiKey,
    required this.apiSecret,
    this.uploadPreset = 'ml_default',
  });

  // ==================== 업로드 관련 ====================

  /// 이미지 파일 업로드
  ///
  /// [fileBytes] 업로드할 파일의 바이트 데이터
  /// [fileName] 파일 이름
  /// [folder] 저장할 폴더 경로
  /// [publicId] 공개 ID (선택사항)
  /// [tags] 태그 목록 (선택사항)
  /// [transformation] 이미지 변환 옵션 (선택사항)
  ///
  /// Returns: 업로드 결과 Map
  Future<Map<String, dynamic>> uploadImage({
    required Uint8List fileBytes,
    required String fileName,
    String? folder,
    String? publicId,
    List<String>? tags,
    Map<String, dynamic>? transformation,
  }) async {
    try {
      // 파일 크기 확인
      final maxSizeBytes = AppConstants.maxFileSize * 1024 * 1024;
      if (fileBytes.length > maxSizeBytes) {
        throw Exception(
          '파일 크기가 너무 큽니다. 최대 ${AppConstants.maxFileSize} MB까지 업로드 가능합니다.',
        );
      }

      // 파일 형식 확인
      final fileExtension = fileName.split('.').last.toLowerCase();
      if (!AppConstants.supportedImageFormats.contains(fileExtension)) {
        throw Exception(
          '지원되지 않는 이미지 형식입니다. 지원 형식: ${AppConstants.supportedImageFormats.join(', ')}',
        );
      }

      // 업로드 URL 생성
      final uploadUrl = '$_baseUrl/$cloudName$_uploadEndpoint';

      // 폼 데이터 생성
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // 기본 파라미터 추가
      request.fields['upload_preset'] = uploadPreset;
      if (folder != null) request.fields['folder'] = folder;
      if (publicId != null) request.fields['public_id'] = publicId;
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = tags.join(',');
      }

      // 변환 옵션 추가
      if (transformation != null) {
        final transformParams = _buildTransformationParams(transformation);
        if (transformParams.isNotEmpty) {
          request.fields['transformation'] = transformParams;
        }
      }

      // 파일 추가
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      // 요청 전송 (타임아웃 설정)
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('파일 업로드 타임아웃 (30초 초과)');
        },
      );

      final responseData = await streamedResponse.stream.bytesToString();
      final result = json.decode(responseData);

      // 응답 확인
      if (streamedResponse.statusCode == 200) {
        return {
          'success': true,
          'url': result['secure_url'],
          'publicId': result['public_id'],
          'width': result['width'],
          'height': result['height'],
          'format': result['format'],
          'size': result['bytes'],
          'createdAt': result['created_at'],
        };
      } else {
        throw Exception(
          '업로드 실패: ${result['error']?['message'] ?? '알 수 없는 오류'}',
        );
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== 삭제 관련 ====================

  /// 이미지 삭제
  ///
  /// [publicId] 삭제할 이미지의 공개 ID
  ///
  /// Returns: 삭제 결과 Map
  Future<Map<String, dynamic>> deleteImage(String publicId) async {
    try {
      // 삭제 URL 생성
      final deleteUrl = '$_baseUrl/$cloudName$_deleteEndpoint';

      // 서명 생성
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      final signature = _generateSignature(publicId, timestamp);

      // 폼 데이터 생성
      final request = http.MultipartRequest('POST', Uri.parse(deleteUrl));
      request.fields['public_id'] = publicId;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['signature'] = signature;
      request.fields['api_key'] = apiKey;

      // 요청 전송
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final result = json.decode(responseData);

      // 응답 확인
      if (response.statusCode == 200) {
        return {'success': true, 'message': '이미지가 성공적으로 삭제되었습니다.'};
      } else {
        throw Exception('삭제 실패: ${result['error']?['message'] ?? '알 수 없는 오류'}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== 변환 관련 ====================

  /// 이미지 변환 URL 생성
  ///
  /// [publicId] 변환할 이미지의 공개 ID
  /// [transformation] 변환 옵션
  ///
  /// Returns: 변환된 이미지 URL
  String getTransformedImageUrl(
    String publicId,
    Map<String, dynamic> transformation,
  ) {
    final transformParams = _buildTransformationParams(transformation);
    return 'https://res.cloudinary.com/$cloudName/image/upload/$transformParams/$publicId';
  }

  // ==================== 유틸리티 메서드 ====================

  /// 변환 파라미터 문자열 생성
  ///
  /// [transformation] 변환 옵션 Map
  ///
  /// Returns: 변환 파라미터 문자열
  String _buildTransformationParams(Map<String, dynamic> transformation) {
    final params = <String>[];

    // 크기 관련
    if (transformation['width'] != null) {
      params.add('w_${transformation['width']}');
    }
    if (transformation['height'] != null) {
      params.add('h_${transformation['height']}');
    }

    // 크롭 관련
    if (transformation['crop'] != null) {
      params.add('c_${transformation['crop']}');
    }

    // 품질 관련
    if (transformation['quality'] != null) {
      params.add('q_${transformation['quality']}');
    }

    // 포맷 관련
    if (transformation['format'] != null) {
      params.add('f_${transformation['format']}');
    }

    // 효과 관련
    if (transformation['effect'] != null) {
      params.add('e_${transformation['effect']}');
    }

    // 회전 관련
    if (transformation['angle'] != null) {
      params.add('a_${transformation['angle']}');
    }

    return params.join(',');
  }

  /// 서명 생성
  ///
  /// [publicId] 공개 ID
  /// [timestamp] 타임스탬프
  ///
  /// Returns: 서명 문자열
  String _generateSignature(String publicId, int timestamp) {
    final params = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
    final bytes = utf8.encode(params);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  /// URL에서 공개 ID 추출
  ///
  /// [url] Cloudinary 이미지 URL
  ///
  /// Returns: 공개 ID
  String? extractPublicIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // URL 패턴: /v1_1/cloud_name/image/upload/transformation/public_id
      if (pathSegments.length >= 6 &&
          pathSegments[2] == 'image' &&
          pathSegments[3] == 'upload') {
        return pathSegments.last;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
