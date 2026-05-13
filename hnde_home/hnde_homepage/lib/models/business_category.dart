// 사업 카테고리 모델 (제조유통사업, 식음료사업 공통)
class BusinessCategory {
  final String id;
  final String name; // 분류명
  final List<CategoryItem> items; // 분류 내 항목들
  final int order; // 순서

  BusinessCategory({
    required this.id,
    required this.name,
    required this.items,
    this.order = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
      'order': order,
    };
  }

  factory BusinessCategory.fromJson(Map<String, dynamic> json) {
    return BusinessCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => CategoryItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      order: json['order'] as int? ?? 0,
    );
  }

  factory BusinessCategory.fromFirestore(Map<String, dynamic> data) {
    return BusinessCategory(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => CategoryItem.fromFirestore(item as Map<String, dynamic>))
              .toList() ??
          [],
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toFirestore()).toList(),
      'order': order,
    };
  }
}

// 카테고리 항목 모델
class CategoryItem {
  final String id;
  final String? imageUrl; // 좌측 이미지
  final String? type; // 구분 (가장 위)
  final String? title; // 제목
  final String? content; // 내용
  final int order; // 순서

  CategoryItem({
    required this.id,
    this.imageUrl,
    this.type,
    this.title,
    this.content,
    this.order = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'type': type,
      'title': title,
      'content': content,
      'order': order,
    };
  }

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String?,
      type: json['type'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }

  factory CategoryItem.fromFirestore(Map<String, dynamic> data) {
    return CategoryItem(
      id: data['id'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      type: data['type'] as String?,
      title: data['title'] as String?,
      content: data['content'] as String?,
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'type': type,
      'title': title,
      'content': content,
      'order': order,
    };
  }
}

