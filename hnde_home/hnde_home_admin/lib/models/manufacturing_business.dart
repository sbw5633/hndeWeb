import 'business_category.dart';

// 제조유통사업 모델
class ManufacturingBusiness {
  final String? mainImageUrl; // 메인 이미지
  final List<BusinessCategory> categories; // 분류 목록

  ManufacturingBusiness({
    this.mainImageUrl,
    required this.categories,
  });

  factory ManufacturingBusiness.fromFirestore(Map<String, dynamic> data) {
    return ManufacturingBusiness(
      mainImageUrl: data['mainImageUrl'] as String?,
      categories: (data['categories'] as List<dynamic>?)
              ?.map((cat) => BusinessCategory.fromFirestore(cat as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (mainImageUrl != null) 'mainImageUrl': mainImageUrl,
      'categories': categories.map((cat) => cat.toFirestore()).toList(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'mainImageUrl': mainImageUrl,
      'categories': categories.map((cat) => cat.toJson()).toList(),
    };
  }

  factory ManufacturingBusiness.fromJson(Map<String, dynamic> json) {
    return ManufacturingBusiness(
      mainImageUrl: json['mainImageUrl'] as String?,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((cat) => BusinessCategory.fromJson(cat as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

