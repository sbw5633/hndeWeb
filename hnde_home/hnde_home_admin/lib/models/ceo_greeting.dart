import 'home_page_config.dart';

// 공유 모델 - 프론트엔드와 동일한 구조
// CEO 인사말 모델
class CEOGreeting {
  final String id;
  final String? imageUrl;
  final String? imageFit; // cover, contain, fill, fitWidth, fitHeight, none, scaleDown
  final String? title; // 호환성을 위해 유지
  final String? content; // 호환성을 위해 유지
  final List<TextLineConfig> textLines; // 줄 단위 텍스트 설정 (최대 5줄)

  CEOGreeting({
    required this.id,
    this.imageUrl,
    this.imageFit,
    this.title,
    this.content,
    List<TextLineConfig>? textLines,
  }) : textLines = textLines ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'imageFit': imageFit,
      'title': title,
      'content': content,
      'textLines': textLines.map((line) => line.toFirestore()).toList(),
    };
  }

  factory CEOGreeting.fromJson(Map<String, dynamic> json) {
    List<TextLineConfig> lines = [];
    if (json['textLines'] != null) {
      lines = (json['textLines'] as List)
          .map((e) => TextLineConfig.fromFirestore(e as Map<String, dynamic>))
          .toList();
    } else if (json['content'] != null) {
      // 호환성: 기존 content를 첫 번째 라인으로 변환
      final oldContent = json['content'] as String;
      if (oldContent.isNotEmpty) {
        lines = [TextLineConfig(text: oldContent)];
      }
    }
    
    return CEOGreeting(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String?,
      imageFit: json['imageFit'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String?,
      textLines: lines,
    );
  }

  factory CEOGreeting.fromFirestore(Map<String, dynamic> data, String id) {
    List<TextLineConfig> lines = [];
    if (data['textLines'] != null) {
      lines = (data['textLines'] as List)
          .map((e) => TextLineConfig.fromFirestore(e as Map<String, dynamic>))
          .toList();
    } else if (data['content'] != null) {
      // 호환성: 기존 content를 첫 번째 라인으로 변환
      final oldContent = data['content'] as String;
      if (oldContent.isNotEmpty) {
        lines = [TextLineConfig(text: oldContent)];
      }
    }
    
    return CEOGreeting(
      id: id,
      imageUrl: data['imageUrl'] as String?,
      imageFit: data['imageFit'] as String?,
      title: data['title'] as String?,
      content: data['content'] as String?,
      textLines: lines,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'imageFit': imageFit,
      'title': title,
      'content': content,
      'textLines': textLines.map((line) => line.toFirestore()).toList(),
    };
  }
}


