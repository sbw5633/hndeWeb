import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';
import '../config/cloudinary_config.dart';

/// Cloudinary를 사용한 파일 업로드 서비스
///
/// 기존 FileUploadService와 호환되는 인터페이스를 제공합니다.
class FileUploadService {
  late final CloudinaryService _cloudinaryService;

  FileUploadService({
    String? cloudName,
    String? apiKey,
    String? apiSecret,
    String? uploadPreset,
  }) {
    _cloudinaryService = CloudinaryService(
      cloudName: cloudName ?? CloudinaryConfig.cloudName,
      apiKey: apiKey ?? CloudinaryConfig.apiKey,
      apiSecret: apiSecret ?? CloudinaryConfig.apiSecret,
      uploadPreset: uploadPreset ?? CloudinaryConfig.uploadPreset,
    );
  }

  /// 단일 파일 업로드
  ///
  /// [file] 업로드할 파일 (XFile)
  ///
  /// Returns: 업로드 결과 Map (기존 인터페이스와 호환)
  Future<Map<String, dynamic>?> uploadFile(XFile file) async {
    try {
      // 설정 확인
      if (CloudinaryConfig.cloudName == 'your-cloud-name' ||
          CloudinaryConfig.apiKey == 'your-api-key') {
        throw Exception(
          'Cloudinary 설정이 필요합니다. lib/config/cloudinary_config.dart 파일을 확인하세요.',
        );
      }

      final fileBytes = await file.readAsBytes();

      final result = await _cloudinaryService.uploadImage(
        fileBytes: fileBytes,
        fileName: file.name,
        folder: 'hnde_admin',
      );

      if (result['success'] == true) {
        // 기존 인터페이스와 호환되도록 변환
        return {
          'view_url': result['url'],
          'download_url': result['url'],
          'public_id': result['publicId'],
          'url': result['url'],
        };
      } else {
        final errorMsg = result['error'] ?? '업로드 실패';
        if (errorMsg.toString().contains('preset')) {
          throw Exception(
            'Upload preset을 찾을 수 없습니다.\n'
            'Cloudinary Dashboard → Settings → Upload presets에서 '
            'Unsigned preset을 생성하세요.\n'
            '현재 설정: ${CloudinaryConfig.uploadPreset}',
          );
        }
        throw Exception(errorMsg.toString());
      }
    } catch (e) {
      print('파일 업로드 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 다중 파일 업로드
  Future<List<Map<String, dynamic>>> uploadMultipleFiles(
      List<XFile> files) async {
    List<Map<String, dynamic>> results = [];

    for (XFile file in files) {
      final result = await uploadFile(file);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  /// 파일 URL 생성 (view_url 기준)
  String getViewUrl(String viewUrl) {
    // Cloudinary URL은 이미 완전한 URL이므로 그대로 반환
    return viewUrl;
  }

  /// 다운로드 URL 생성 (download_url 기준)
  String getDownloadUrl(String downloadUrl) {
    // Cloudinary URL은 이미 완전한 URL이므로 그대로 반환
    return downloadUrl;
  }
}

