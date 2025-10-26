import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/loading_provider.dart';
import '../../../../../core/page_state_provider.dart';
import '../../../../../models/file_info_model.dart';
import '../../../../../const_value.dart';

class PostFormSubmit {
  static Future<void> submitForm({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required MenuType type,
    required TextEditingController titleController,
    required TextEditingController contentController,
    required List<FileInfo> imageFiles,
    required List<FileInfo> documentFiles,
    required String selectedBranch,
    Map<String, dynamic>? extraData,
    required Function(
      String title,
      String content,
      List<Map<String, String>> images,
      List<Map<String, String>> files,
      String selectedBranch,
      Map<String, dynamic>? extraData,
    ) onSubmit,
    VoidCallback? onSuccess,
  }) async {
    if (formKey.currentState?.validate() ?? false) {
      context.read<LoadingProvider>().setLoading(true,
          text: _getLoadingText(type));

      try {
        final imageList = await _uploadFiles(imageFiles, context, true);
        final fileList = await _uploadFiles(documentFiles, context, false);

        onSubmit(
          titleController.text.trim(),
          contentController.text.trim(),
          imageList,
          fileList,
          selectedBranch,
          extraData,
        );

        onSuccess?.call();
      } catch (e) {
        _showError(context, e.toString());
      } finally {
        context.read<LoadingProvider>().setLoading(false);
      }
    }
  }

  static String _getLoadingText(MenuType type) {
    switch (type) {
      case MenuType.notice:
        return '공지사항 등록 중...';
      case MenuType.board:
        return '게시글 등록 중...';
      case MenuType.anonymousBoard:
        return '익명게시글 등록 중...';
      case MenuType.dataRequest:
        return '자료요청 등록 중...';
      default:
        return '등록 중...';
    }
  }

  static Future<List<Map<String, String>>> _uploadFiles(
    List<FileInfo> files,
    BuildContext context,
    bool isImage,
  ) async {
    List<Map<String, String>> result = [];

    for (final fileInfo in files) {
      try {
        final success = await fileInfo.upload();
        if (success) {
          result.add(fileInfo.toMap());
        } else {
          throw Exception('${isImage ? "이미지" : "파일"} 업로드 실패: ${fileInfo.displayName}');
        }
      } catch (e) {
        _showUploadError(context, fileInfo.displayName, isImage);
        throw e;
      }
    }

    return result;
  }

  static void _showUploadError(BuildContext context, String fileName, bool isImage) {
    if (context.mounted) {
      String errorMessage = '${isImage ? "이미지" : "파일"} 업로드 실패: $fileName';
      errorMessage += '\n\nS3 업로드 중 오류가 발생했습니다.';
      errorMessage += '\n네트워크 연결을 확인하고 다시 시도해주세요.';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  static void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('등록 실패: $message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
