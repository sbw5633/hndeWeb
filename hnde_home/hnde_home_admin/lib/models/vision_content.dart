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

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'imageFit': imageFit,
      'title': title,
      'content': content,
    };
  }
}

