// 주요사업 타입 모델
class BusinessType {
  final String id;
  final String name; // 사업명 (예: "휴게소사업", "제조유통사업")
  final String layoutType; // "layout1" 또는 "layout2"
  final int order; // 정렬 순서
  final String? iconName; // 아이콘 이름 (예: "restaurant", "factory")
  final String? colorHex; // 색상 (예: "#2196F3")
  final String? description; // 설명

  BusinessType({
    required this.id,
    required this.name,
    required this.layoutType,
    required this.order,
    this.iconName,
    this.colorHex,
    this.description,
  });

  factory BusinessType.fromFirestore(Map<String, dynamic> data, String docId) {
    return BusinessType(
      id: docId,
      name: data['name'] as String? ?? '',
      layoutType: data['layoutType'] as String? ?? 'layout1',
      order: data['order'] as int? ?? 0,
      iconName: data['iconName'] as String?,
      colorHex: data['colorHex'] as String?,
      description: data['description'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'layoutType': layoutType,
      'order': order,
      if (iconName != null) 'iconName': iconName,
      if (colorHex != null) 'colorHex': colorHex,
      if (description != null) 'description': description,
    };
  }

  factory BusinessType.fromJson(Map<String, dynamic> json) {
    return BusinessType(
      id: json['id'] as String,
      name: json['name'] as String,
      layoutType: json['layoutType'] as String,
      order: json['order'] as int,
      iconName: json['iconName'] as String?,
      colorHex: json['colorHex'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'layoutType': layoutType,
      'order': order,
      'iconName': iconName,
      'colorHex': colorHex,
      'description': description,
    };
  }
}

