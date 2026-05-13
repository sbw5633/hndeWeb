import 'home_page_config.dart';

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
      'textLines': textLines.map((line) => line.toJson()).toList(),
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

  static CEOGreeting getDummyData() {
    return CEOGreeting(
      id: 'ceo_greeting',
      imageUrl: null,
      imageFit: 'cover',
      textLines: [
        TextLineConfig(text: '안녕하세요. H&DE를 방문해 주신 여러분께 깊은 감사를 드립니다.'),
        TextLineConfig(text: ''),
        TextLineConfig(text: '저희 H&DE는 고객 만족을 최우선으로 생각하며, 지속적인 혁신과 품질 향상을 통해 최고의 서비스를 제공하겠습니다.'),
        TextLineConfig(text: ''),
        TextLineConfig(text: '앞으로도 고객 여러분과 함께 성장하는 신뢰받는 기업이 되도록 최선을 다하겠습니다.'),
      ],
    );
  }
}

