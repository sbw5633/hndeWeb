import 'package:cloud_firestore/cloud_firestore.dart';

enum TextPosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum ImageEffect {
  none,
  shimmer, // 빛이 지나가는 효과
  fade, // 페이드 인/아웃
  pulse, // 맥박 효과
  slide, // 슬라이드 효과
  zoom, // 줌 인/아웃
}

enum ImageSlideTransition {
  none, // 변환 없음
  fade, // 페이드
  slideLeft, // 왼쪽으로 슬라이드
  slideRight, // 오른쪽으로 슬라이드
  slideUp, // 위로 슬라이드
  slideDown, // 아래로 슬라이드
  zoom, // 줌
}

class TextLineConfig {
  final String text;
  final double? fontSize;
  final String? color;
  final String? fontWeight;
  final String? textAlign; // left, center, right
  final bool isDivider; // 구분선 여부
  final double? dividerWidth; // 구분선 길이 (0.0 ~ 1.0, null이면 전체 너비)

  TextLineConfig({
    required this.text,
    this.fontSize,
    this.color,
    this.fontWeight,
    this.textAlign,
    this.isDivider = false,
    this.dividerWidth,
  });

  factory TextLineConfig.fromFirestore(Map<String, dynamic> data) {
    return TextLineConfig(
      text: data['text'] as String? ?? '',
      fontSize: (data['fontSize'] as num?)?.toDouble(),
      color: data['color'] as String?,
      fontWeight: data['fontWeight'] as String?,
      textAlign: data['textAlign'] as String?,
      isDivider: data['isDivider'] as bool? ?? false,
      dividerWidth: (data['dividerWidth'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'fontSize': fontSize,
      'color': color,
      'fontWeight': fontWeight,
      'textAlign': textAlign,
      'isDivider': isDivider,
      'dividerWidth': dividerWidth,
    };
  }
}

class MainHeroConfig {
  final String? imageUrl; // 호환성을 위해 유지 (첫 번째 이미지)
  final List<String> imageUrls; // 여러 이미지 리스트
  final String? text; // 호환성을 위해 유지
  final List<TextLineConfig> textLines; // 줄 단위 텍스트 설정 (최대 5줄)
  final TextPosition textPosition;
  final ImageEffect imageEffect; // 개별 이미지에 적용되는 지속 이펙트
  final double effectValue; // 이펙트 속도/강도 (0.0 ~ 1.0)
  final ImageSlideTransition slideTransition; // 이미지 간 변환 효과
  final int transitionDuration; // 변환 시간 (초)
  // 텍스트 배경 스타일 (전체 공통)
  final String? textBackgroundColor; // 배경 색상 (hex, null이면 배경 없음)
  final double textBackgroundOpacity; // 배경 불투명도 (0.0 ~ 1.0)

  MainHeroConfig({
    this.imageUrl,
    List<String>? imageUrls,
    this.text,
    List<TextLineConfig>? textLines,
    this.textPosition = TextPosition.center,
    this.imageEffect = ImageEffect.none,
    this.effectValue = 0.5,
    this.slideTransition = ImageSlideTransition.fade,
    this.transitionDuration = 3,
    this.textBackgroundColor,
    this.textBackgroundOpacity = 0.0,
  }) : imageUrls = imageUrls ?? (imageUrl != null ? [imageUrl] : []),
       textLines = textLines ?? [];

  factory MainHeroConfig.fromFirestore(Map<String, dynamic> data) {
    // 호환성: imageUrl이 있으면 리스트로 변환
    final List<String> urls;
    if (data['imageUrls'] != null) {
      urls = List<String>.from(data['imageUrls'] as List);
    } else if (data['imageUrl'] != null) {
      urls = [data['imageUrl'] as String];
    } else {
      urls = [];
    }

    // 텍스트 라인 파싱
    List<TextLineConfig> lines = [];
    if (data['textLines'] != null) {
      lines = (data['textLines'] as List)
          .map((e) => TextLineConfig.fromFirestore(e as Map<String, dynamic>))
          .toList();
    } else if (data['text'] != null) {
      // 호환성: 기존 text를 첫 번째 라인으로 변환
      final oldText = data['text'] as String;
      if (oldText.isNotEmpty) {
        lines = [TextLineConfig(
          text: oldText,
          fontSize: (data['textFontSize'] as num?)?.toDouble(),
          color: data['textColor'] as String?,
          fontWeight: data['textFontWeight'] as String?,
        )];
      }
    }

    return MainHeroConfig(
      imageUrl: urls.isNotEmpty ? urls.first : null,
      imageUrls: urls,
      text: data['text'] as String?,
      textLines: lines,
      textPosition: TextPosition.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['textPosition'] as String? ?? 'center'),
        orElse: () => TextPosition.center,
      ),
      imageEffect: ImageEffect.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['imageEffect'] as String? ?? 'none'),
        orElse: () => ImageEffect.none,
      ),
      effectValue: (data['effectValue'] as num?)?.toDouble() ?? 0.5,
      slideTransition: ImageSlideTransition.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (data['slideTransition'] as String? ?? 'fade'),
        orElse: () => ImageSlideTransition.fade,
      ),
      transitionDuration: (data['transitionDuration'] as int?) ?? 3,
      textBackgroundColor: data['textBackgroundColor'] as String?,
      textBackgroundOpacity: (data['textBackgroundOpacity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
      'imageUrls': imageUrls,
      'text': textLines.isNotEmpty ? textLines.map((e) => e.text).join('\n') : text,
      'textLines': textLines.map((e) => e.toFirestore()).toList(),
      'textPosition': textPosition.toString().split('.').last,
      'imageEffect': imageEffect.toString().split('.').last,
      'effectValue': effectValue,
      'slideTransition': slideTransition.toString().split('.').last,
      'transitionDuration': transitionDuration,
      'textBackgroundColor': textBackgroundColor,
      'textBackgroundOpacity': textBackgroundOpacity,
    };
  }
}

class HomePageConfig {
  final String id;
  final String? topLogoUrl;
  final MainHeroConfig? mainHero;

  HomePageConfig({
    required this.id,
    this.topLogoUrl,
    this.mainHero,
  });

  factory HomePageConfig.fromFirestore(Map<String, dynamic> data, String id) {
    return HomePageConfig(
      id: id,
      topLogoUrl: data['topLogoUrl'] as String?,
      mainHero: data['mainHero'] != null
          ? MainHeroConfig.fromFirestore(
              data['mainHero'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'topLogoUrl': topLogoUrl,
      'mainHero': mainHero?.toFirestore(),
    };
  }
}
