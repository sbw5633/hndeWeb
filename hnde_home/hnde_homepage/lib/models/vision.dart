// 경영이념 및 비전 모델
class VisionContent {
  final String id;
  final String? imageUrl;
  final String? imageFit; // cover, contain, fill, fitWidth, fitHeight, none, scaleDown
  final String? title;
  final String? content;

  VisionContent({
    required this.id,
    this.imageUrl,
    this.imageFit,
    this.title,
    this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'imageFit': imageFit,
      'title': title,
      'content': content,
    };
  }

  factory VisionContent.fromJson(Map<String, dynamic> json) {
    return VisionContent(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String?,
      imageFit: json['imageFit'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String?,
    );
  }

  factory VisionContent.fromFirestore(Map<String, dynamic> data, String id) {
    return VisionContent(
      id: id,
      imageUrl: data['imageUrl'] as String?,
      imageFit: data['imageFit'] as String?,
      title: data['title'] as String?,
      content: data['content'] as String?,
    );
  }

  static VisionContent getDummyData() {
    return VisionContent(
      id: 'vision',
      imageUrl: null,
      title: '경영이념 및 비전',
      content: '''H&DE의 경영이념과 비전을 소개합니다.

고객 중심의 경영을 통해 최고의 가치를 제공하겠습니다.
지속적인 혁신과 성장을 통해 업계를 선도하는 기업이 되겠습니다.''',
    );
  }
}
