import 'package:cloud_firestore/cloud_firestore.dart';

// CI 소개 모델
class CIInfo {
  final String id;
  final String title;
  final CIMeaning meaning; // 의미
  final CIDefinition definition; // 정의

  CIInfo({
    required this.id,
    required this.title,
    required this.meaning,
    required this.definition,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'meaning': meaning.toJson(),
      'definition': definition.toJson(),
    };
  }

  factory CIInfo.fromJson(Map<String, dynamic> json) {
    return CIInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      meaning: CIMeaning.fromJson(json['meaning'] as Map<String, dynamic>),
      definition:
          CIDefinition.fromJson(json['definition'] as Map<String, dynamic>),
    );
  }

  factory CIInfo.fromFirestore(Map<String, dynamic> data, String id) {
    return CIInfo(
      id: id,
      title: data['title'] as String,
      meaning: CIMeaning.fromFirestore(data['meaning'] as Map<String, dynamic>),
      definition: CIDefinition.fromFirestore(
        data['definition'] as Map<String, dynamic>,
      ),
    );
  }

  static CIInfo getDummyData() {
    return CIInfo(
      id: 'ci',
      title: 'CI 소개',
      meaning: CIMeaning(
        id: 'meaning',
        content:
            'H&DE의 CI는 회사의 정체성과 가치를 시각적으로 표현합니다. H&DE는 고객 만족과 혁신을 통해 지속 가능한 성장을 추구합니다.',
      ),
      definition: CIDefinition(
        id: 'definition',
        type: CIDefinitionType.image, // 또는 text
        imageUrl: null,
        content: null,
      ),
    );
  }
}

// CI 의미
class CIMeaning {
  final String id;
  final String content;

  CIMeaning({
    required this.id,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
    };
  }

  factory CIMeaning.fromJson(Map<String, dynamic> json) {
    return CIMeaning(
      id: json['id'] as String,
      content: json['content'] as String,
    );
  }

  factory CIMeaning.fromFirestore(Map<String, dynamic> data) {
    return CIMeaning(
      id: data['id'] as String? ?? '',
      content: data['content'] as String,
    );
  }
}

// CI 정의 타입
enum CIDefinitionType {
  image,
  text,
}

// CI 정의
class CIDefinition {
  final String id;
  final CIDefinitionType type;
  final String? imageUrl;
  final String? content;

  CIDefinition({
    required this.id,
    required this.type,
    this.imageUrl,
    this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'imageUrl': imageUrl,
      'content': content,
    };
  }

  factory CIDefinition.fromJson(Map<String, dynamic> json) {
    return CIDefinition(
      id: json['id'] as String,
      type: CIDefinitionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => CIDefinitionType.text,
      ),
      imageUrl: json['imageUrl'] as String?,
      content: json['content'] as String?,
    );
  }

  factory CIDefinition.fromFirestore(Map<String, dynamic> data) {
    return CIDefinition(
      id: data['id'] as String? ?? '',
      type: CIDefinitionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => CIDefinitionType.text,
      ),
      imageUrl: data['imageUrl'] as String?,
      content: data['content'] as String?,
    );
  }
}
