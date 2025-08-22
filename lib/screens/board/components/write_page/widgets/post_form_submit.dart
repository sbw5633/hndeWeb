import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/loading_provider.dart';
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
    required String? selectedBranch,
    Map<String, dynamic>? extraData,
    required Function(String, String, List<Map<String, String>>, List<Map<String, String>>, String, Map<String, dynamic>?) onSubmit,
    required VoidCallback onSuccess,
  }) async {
    if (formKey.currentState?.validate() ?? false) {
      context.read<LoadingProvider>().setLoading(true,
          text: type == MenuType.notice
              ? '공지사항 등록 중...'
              : type == MenuType.board
                  ? '게시글 등록 중...'
                  : type == MenuType.anonymousBoard
                      ? '익명게시글 등록 중...'
                      : type == MenuType.dataRequest
                          ? '자료요청 등록 중...'
                          : '등록 중...');
      try {
        List<Map<String, String>> imageList = [];
        List<Map<String, String>> fileList = [];

        for (final fileInfo in imageFiles) {
          try {
            final success = await fileInfo.upload();
            if (success) {
              imageList.add(fileInfo.toMap());
            } else {
              throw Exception('이미지 업로드 실패: ${fileInfo.displayName}');
            }
          } catch (e) {
            debugPrint('이미지 업로드 실패: $e');
            if (context.mounted) {
              String errorMessage = '이미지 업로드 실패: ${fileInfo.displayName}';
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
            context.read<LoadingProvider>().setLoading(false);
            return;
          }
        }

        for (final fileInfo in documentFiles) {
          try {
            final success = await fileInfo.upload();
            if (success) {
              fileList.add(fileInfo.toMap());
            } else {
              throw Exception('파일 업로드 실패: ${fileInfo.displayName}');
            }
          } catch (e) {
            debugPrint('문서 업로드 실패: $e');
            if (context.mounted) {
              String errorMessage = '파일 업로드 실패: ${fileInfo.displayName}';
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
            context.read<LoadingProvider>().setLoading(false);
            return;
          }
        }

        onSubmit(
            titleController.text.trim(),
            contentController.text.trim(),
            imageList,
            fileList,
            selectedBranch ?? '',
            extraData);
        onSuccess();
      } catch (e) {
        debugPrint('제출 실패: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('등록 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        context.read<LoadingProvider>().setLoading(false);
      }
    }
  }
}
