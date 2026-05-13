import 'package:cloud_firestore/cloud_firestore.dart';

// CI 소개 모델
class CIInfo {
  final String id;
  final String title;
  final CIMeaning meaning;
  final CIDefinition definition;

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

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'meaning': meaning.toFirestore(),
      'definition': definition.toFirestore(),
    };
  }
}

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

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'content': content,
    };
  }
}

enum CIDefinitionType {
  image,
  text,
}

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

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'imageUrl': imageUrl,
      'content': content,
    };
  }
}

