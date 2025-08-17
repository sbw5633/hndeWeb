import 'package:flutter/material.dart';
import 'package:hnde_web/core/page_state_provider.dart';
import 'package:provider/provider.dart';

class DialogUtils {
  /// 페이지 나가기 확인 다이얼로그
  static Future<bool?> showExitConfirmationDialog(BuildContext context) async {
    // 편집 중이고 저장되지 않은 변경사항이 있는 경우 확인 다이얼로그 표시
    final pageStateProvider = context.read<PageStateProvider>();
    if (pageStateProvider.isEditing && pageStateProvider.hasUnsavedChanges) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('페이지를 나가시겠습니까?'),
            content: const Text('저장되지 않은 변경사항이 있습니다. 페이지를 나가면 변경사항이 손실됩니다.'),
            actions: [
              TextButton(
                onPressed: () {
                  // 안전한 Navigator 사용
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  // 안전한 상태 초기화
                  pageStateProvider.safeClearState();
                  
                  // 안전한 Navigator 사용
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text('나가기'),
              ),
            ],
          );
        },
      );
    }
    return true;
  }
}
