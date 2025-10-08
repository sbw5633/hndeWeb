import 'package:flutter/material.dart';
import 'dart:html';

class FileDownloadUtils {
  /// 파일 다운로드 실행
  static Future<void> downloadFile({
    required BuildContext context,
    required String url,
    required String fileName,
  }) async {
    if (url.isEmpty) {
      _showErrorSnackBar(context, '파일 URL이 없습니다.');
      return;
    }

    try {
      // 다운로드 링크 생성
      final a = AnchorElement(href: url)
        ..download = fileName
        ..target = '_blank';
      document.body!.append(a);
      a.click();
      a.remove();
      
      // 성공 메시지 표시
      _showSuccessSnackBar(context, '$fileName 다운로드를 시작합니다.');
    } catch (e) {
      // 실패 시 새 창에서 열기
      try {
        window.open(url, '_blank');
        _showSuccessSnackBar(context, '$fileName을 새 창에서 열었습니다.');
      } catch (_) {
        // 최종 실패 시 사용자에게 알림
        _showErrorSnackBar(context, '파일 다운로드에 실패했습니다: $fileName');
      }
    }
  }

  /// 이미지 다운로드 실행
  static Future<void> downloadImage({
    required BuildContext context,
    required String url,
    required String fileName,
  }) async {
    if (url.isEmpty) {
      _showErrorSnackBar(context, '이미지 URL이 없습니다.');
      return;
    }

    try {
      // 다운로드 링크 생성
      final a = AnchorElement(href: url)
        ..download = fileName
        ..target = '_blank';
      document.body!.append(a);
      a.click();
      a.remove();
      
      // 성공 메시지 표시
      _showSuccessSnackBar(context, '$fileName 다운로드를 시작합니다.');
    } catch (e) {
      // 실패 시 새 창에서 열기
      try {
        window.open(url, '_blank');
        _showSuccessSnackBar(context, '$fileName을 새 창에서 열었습니다.');
      } catch (_) {
        // 최종 실패 시 사용자에게 알림
        _showErrorSnackBar(context, '이미지 다운로드에 실패했습니다: $fileName');
      }
    }
  }

  /// 성공 스낵바 표시
  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 오류 스낵바 표시
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
