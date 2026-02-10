import 'business_category.dart';

// 식음료사업 모델
class FoodBeverageBusiness {
  final String? mainImageUrl; // 메인 이미지
  final List<BusinessCategory> categories; // 분류 목록

  FoodBeverageBusiness({
    this.mainImageUrl,
    required this.categories,
  });

  factory FoodBeverageBusiness.fromFirestore(Map<String, dynamic> data) {
    return FoodBeverageBusiness(
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

  factory FoodBeverageBusiness.fromJson(Map<String, dynamic> json) {
    return FoodBeverageBusiness(
      mainImageUrl: json['mainImageUrl'] as String?,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((cat) => BusinessCategory.fromJson(cat as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mainImageUrl': mainImageUrl,
      'categories': categories.map((cat) => cat.toJson()).toList(),
    };
  }

  static FoodBeverageBusiness getDummyData() {
    return FoodBeverageBusiness(
      mainImageUrl: null,
      categories: [],
    );
  }
}

