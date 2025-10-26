import 'package:flutter/material.dart';
import 'base_tool_page.dart';
import '../models/tool_definition.dart';

/// 도구 네비게이션 헬퍼
class ToolNavigator {
  /// 도구 타입에 따른 페이지 생성
  static Widget getToolPage(ToolType type) {
    final config = _getToolConfig(type);
    return BaseToolPage(config: config);
  }

  /// 도구 타입에 따른 설정 반환
  static ToolConfig _getToolConfig(ToolType type) {
    switch (type) {
      // PDF 구성
      case ToolType.pdfMerge:
        return ToolConfig(
          type: type,
          title: 'PDF 합치기',
          description: '여러 PDF 파일을 하나로 병합',
          icon: Icons.merge_type,
          color: Colors.red.shade400,
          acceptedTypes: ['.pdf'],
          minFiles: 2,
        );
      case ToolType.pdfSplit:
        return ToolConfig(
          type: type,
          title: 'PDF 분할',
          description: 'PDF를 여러 파일로 나누기',
          icon: Icons.content_cut,
          color: Colors.orange.shade400,
          acceptedTypes: ['.pdf'],
          minFiles: 1,
        );
      case ToolType.pdfCompress:
        return ToolConfig(
          type: type,
          title: 'PDF 압축',
          description: '파일 크기 줄이기',
          icon: Icons.compress,
          color: Colors.blue.shade400,
          acceptedTypes: ['.pdf'],
          minFiles: 1,
        );
      // IMG 도구
      case ToolType.imgMerge:
        return ToolConfig(
          type: type,
          title: '이미지 병합',
          description: '여러 이미지를 한 페이지로',
          icon: Icons.merge,
          color: Colors.red.shade300,
          acceptedTypes: ['.jpg', '.jpeg', '.png', '.gif', '.webp'],
          minFiles: 2,
          isNew: true,
        );
      case ToolType.imgCompress:
        return ToolConfig(
          type: type,
          title: '이미지 압축',
          description: '파일 크기 줄이기',
          icon: Icons.compress,
          color: Colors.red.shade400,
          acceptedTypes: ['.jpg', '.jpeg', '.png', '.gif', '.webp'],
          minFiles: 1,
        );
      case ToolType.imgResize:
        return ToolConfig(
          type: type,
          title: '이미지 리사이즈',
          description: '크기 조정',
          icon: Icons.aspect_ratio,
          color: Colors.orange.shade400,
          acceptedTypes: ['.jpg', '.jpeg', '.png', '.gif', '.webp'],
          minFiles: 1,
        );
      default:
        return ToolConfig(
          type: type,
          title: '준비 중',
          description: '곧 출시될 기능입니다',
          icon: Icons.build,
          color: Colors.grey.shade400,
          acceptedTypes: [],
        );
    }
  }

  /// 공통 네비게이션
  static void navigateToTool(BuildContext context, ToolType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => getToolPage(type),
      ),
    );
  }
}

