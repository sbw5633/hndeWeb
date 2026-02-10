// 휴게소 카테고리
enum RestAreaCategory {
  intro('소개'),
  stores('매장'),
  food('먹거리'),
  facilities('편의시설'),
  status('현황'),
  awards('수상내역');

  final String label;
  const RestAreaCategory(this.label);
}

// 휴게소 모델
class RestArea {
  final String id;
  final String name;
  final String? imageUrl;
  final String? description; // 간단 설명
  final RestAreaDetail detail;
  final int order; // 순서

  RestArea({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
    required this.detail,
    this.order = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'description': description,
      'detail': detail.toJson(),
      'order': order,
    };
  }

  factory RestArea.fromJson(Map<String, dynamic> json) {
    return RestArea(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      detail: RestAreaDetail.fromJson(json['detail'] as Map<String, dynamic>),
      order: json['order'] as int? ?? 0,
    );
  }

  factory RestArea.fromFirestore(Map<String, dynamic> data, String id) {
    return RestArea(
      id: id,
      name: data['name'] as String,
      imageUrl: data['imageUrl'] as String?,
      description: data['description'] as String?,
      detail: RestAreaDetail.fromFirestore(
        data['detail'] as Map<String, dynamic>,
      ),
      order: data['order'] as int? ?? 0,
    );
  }
}

// 휴게소 상세 정보
class RestAreaDetail {
  final String intro; // 소개
  final String? address; // 주소
  final String? mapAddress; // 지도 표시용 주소
  final RestAreaStatus? status; // 현황 정보
  final List<AwardInfo> awards; // 수상내역
  final List<StoreInfo> stores; // 매장 정보
  final List<FoodInfo> foods; // 먹거리 정보
  final List<FacilityInfo> facilities; // 편의시설 정보
  final List<AdditionalItemInfo> additionalItems; // 소개 하단 추가 항목

  RestAreaDetail({
    required this.intro,
    this.address,
    this.mapAddress,
    this.status,
    required this.awards,
    required this.stores,
    required this.foods,
    required this.facilities,
    required this.additionalItems,
  });

  Map<String, dynamic> toJson() {
    return {
      'intro': intro,
      'address': address,
      'mapAddress': mapAddress,
      'status': status?.toJson(),
      'awards': awards.map((a) => a.toJson()).toList(),
      'stores': stores.map((s) => s.toJson()).toList(),
      'foods': foods.map((f) => f.toJson()).toList(),
      'facilities': facilities.map((f) => f.toJson()).toList(),
      'additionalItems': additionalItems.map((a) => a.toJson()).toList(),
    };
  }

  factory RestAreaDetail.fromJson(Map<String, dynamic> json) {
    return RestAreaDetail(
      intro: json['intro'] as String,
      address: json['address'] as String?,
      mapAddress: json['mapAddress'] as String?,
      status: json['status'] != null
          ? RestAreaStatus.fromJson(json['status'] as Map<String, dynamic>)
          : null,
      awards: (json['awards'] as List<dynamic>?)
              ?.map((a) => AwardInfo.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      stores: (json['stores'] as List)
          .map((s) => StoreInfo.fromJson(s as Map<String, dynamic>))
          .toList(),
      foods: (json['foods'] as List)
          .map((f) => FoodInfo.fromJson(f as Map<String, dynamic>))
          .toList(),
      facilities: (json['facilities'] as List)
          .map((f) => FacilityInfo.fromJson(f as Map<String, dynamic>))
          .toList(),
      additionalItems: (json['additionalItems'] as List<dynamic>?)
              ?.map((a) => AdditionalItemInfo.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory RestAreaDetail.fromFirestore(Map<String, dynamic> data) {
    return RestAreaDetail(
      intro: data['intro'] as String? ?? '',
      address: data['address'] as String?,
      mapAddress: data['mapAddress'] as String?,
      status: data['status'] != null
          ? RestAreaStatus.fromFirestore(data['status'] as Map<String, dynamic>)
          : null,
      awards: (data['awards'] as List<dynamic>?)
              ?.map((a) => AwardInfo.fromFirestore(a as Map<String, dynamic>))
              .toList() ??
          [],
      stores: (data['stores'] as List<dynamic>?)
              ?.map((s) => StoreInfo.fromFirestore(s as Map<String, dynamic>))
              .toList() ??
          [],
      foods: (data['foods'] as List<dynamic>?)
              ?.map((f) => FoodInfo.fromFirestore(f as Map<String, dynamic>))
              .toList() ??
          [],
      facilities: (data['facilities'] as List<dynamic>?)
              ?.map(
                  (f) => FacilityInfo.fromFirestore(f as Map<String, dynamic>))
              .toList() ??
          [],
      additionalItems: (data['additionalItems'] as List<dynamic>?)
              ?.map((a) => AdditionalItemInfo.fromFirestore(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// 소개 하단 추가 항목 정보
class AdditionalItemInfo {
  final String id;
  final String iconName; // 아이콘 이름
  final String title; // 제목
  final String content; // 내용
  final String? imageUrl; // 이미지 URL
  final int order; // 순서

  AdditionalItemInfo({
    required this.id,
    required this.iconName,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.order,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'iconName': iconName,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'order': order,
    };
  }

  factory AdditionalItemInfo.fromJson(Map<String, dynamic> json) {
    return AdditionalItemInfo(
      id: json['id'] as String,
      iconName: json['iconName'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      imageUrl: json['imageUrl'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }

  factory AdditionalItemInfo.fromFirestore(Map<String, dynamic> data) {
    return AdditionalItemInfo(
      id: data['id'] as String? ?? '',
      iconName: data['iconName'] as String? ?? 'info',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      order: data['order'] as int? ?? 0,
    );
  }
}

// 매장 정보
class StoreInfo {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;

  StoreInfo({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
    };
  }

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  factory StoreInfo.fromFirestore(Map<String, dynamic> data) {
    return StoreInfo(
      id: data['id'] as String? ?? '',
      name: data['name'] as String,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

// 먹거리 정보
class FoodInfo {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;

  FoodInfo({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
    };
  }

  factory FoodInfo.fromJson(Map<String, dynamic> json) {
    return FoodInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  factory FoodInfo.fromFirestore(Map<String, dynamic> data) {
    return FoodInfo(
      id: data['id'] as String? ?? '',
      name: data['name'] as String,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

// 편의시설 정보
class FacilityInfo {
  final String id;
  final String name;
  final String? description;
  final String? iconName; // 아이콘 이름 (예: 'restroom', 'parking', etc.)

  FacilityInfo({
    required this.id,
    required this.name,
    this.description,
    this.iconName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
    };
  }

  factory FacilityInfo.fromJson(Map<String, dynamic> json) {
    return FacilityInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconName: json['iconName'] as String?,
    );
  }

  factory FacilityInfo.fromFirestore(Map<String, dynamic> data) {
    return FacilityInfo(
      id: data['id'] as String? ?? '',
      name: data['name'] as String,
      description: data['description'] as String?,
      iconName: data['iconName'] as String?,
    );
  }
}

// 휴게소 현황 정보
class RestAreaStatus {
  final String? buildingStatus; // 건물현황
  final String? parkingStatus; // 주차장 현황
  final String? restroomStatus; // 화장실 현황
  final String? convenienceStatus; // 편의시설 현황
  final bool hasGasStation; // 주유소 여부
  final String? gasStationStatus; // 주유소 현황

  RestAreaStatus({
    this.buildingStatus,
    this.parkingStatus,
    this.restroomStatus,
    this.convenienceStatus,
    this.hasGasStation = false,
    this.gasStationStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'buildingStatus': buildingStatus,
      'parkingStatus': parkingStatus,
      'restroomStatus': restroomStatus,
      'convenienceStatus': convenienceStatus,
      'hasGasStation': hasGasStation,
      'gasStationStatus': gasStationStatus,
    };
  }

  factory RestAreaStatus.fromJson(Map<String, dynamic> json) {
    return RestAreaStatus(
      buildingStatus: json['buildingStatus'] as String?,
      parkingStatus: json['parkingStatus'] as String?,
      restroomStatus: json['restroomStatus'] as String?,
      convenienceStatus: json['convenienceStatus'] as String?,
      hasGasStation: json['hasGasStation'] as bool? ?? false,
      gasStationStatus: json['gasStationStatus'] as String?,
    );
  }

  factory RestAreaStatus.fromFirestore(Map<String, dynamic> data) {
    return RestAreaStatus(
      buildingStatus: data['buildingStatus'] as String?,
      parkingStatus: data['parkingStatus'] as String?,
      restroomStatus: data['restroomStatus'] as String?,
      convenienceStatus: data['convenienceStatus'] as String?,
      hasGasStation: data['hasGasStation'] as bool? ?? false,
      gasStationStatus: data['gasStationStatus'] as String?,
    );
  }
}

// 수상내역 정보
class AwardInfo {
  final String id;
  final String title; // 수상명
  final String? description; // 설명
  final String? imageUrl; // 수상 이미지
  final String? year; // 연도

  AwardInfo({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.year,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'year': year,
    };
  }

  factory AwardInfo.fromJson(Map<String, dynamic> json) {
    return AwardInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      year: json['year'] as String?,
    );
  }

  factory AwardInfo.fromFirestore(Map<String, dynamic> data) {
    return AwardInfo(
      id: data['id'] as String? ?? '',
      title: data['title'] as String,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      year: data['year'] as String?,
    );
  }
}

// 더미 데이터
class RestAreaData {
  static List<RestArea> getDummyData() {
    return [
      RestArea(
        id: '1',
        name: '천안휴게소',
        description: '경부고속도로의 대표적인 휴게소',
        imageUrl: null,
        detail: RestAreaDetail(
          intro: '천안휴게소는 경부고속도로의 핵심 휴게소로, 다양한 편의시설과 매장을 갖추고 있습니다.',
          address: null,
          mapAddress: null,
          status: null,
          awards: [],
          additionalItems: [],
          stores: [
            StoreInfo(
              id: '1',
              name: '편의점',
              description: '24시간 운영',
            ),
            StoreInfo(
              id: '2',
              name: '기념품샵',
              description: '지역 특산품 판매',
            ),
          ],
          foods: [
            FoodInfo(
              id: '1',
              name: '김밥',
              description: '신선한 재료로 만든 김밥',
            ),
            FoodInfo(
              id: '2',
              name: '떡볶이',
              description: '매콤달콤한 떡볶이',
            ),
          ],
          facilities: [
            FacilityInfo(
              id: '1',
              name: '화장실',
              iconName: 'restroom',
            ),
            FacilityInfo(
              id: '2',
              name: '주차장',
              iconName: 'parking',
            ),
          ],
        ),
      ),
      RestArea(
        id: '2',
        name: '서울휴게소',
        description: '수도권 접근성 최고의 휴게소',
        imageUrl: null,
        detail: RestAreaDetail(
          intro: '서울휴게소는 수도권 지역의 대표적인 휴게소입니다.',
          address: null,
          mapAddress: null,
          status: null,
          awards: [],
          additionalItems: [],
          stores: [
            StoreInfo(
              id: '1',
              name: '편의점',
              description: '24시간 운영',
            ),
          ],
          foods: [
            FoodInfo(
              id: '1',
              name: '라면',
              description: '따끈따끈한 라면',
            ),
          ],
          facilities: [
            FacilityInfo(
              id: '1',
              name: '화장실',
              iconName: 'restroom',
            ),
          ],
        ),
      ),
      RestArea(
        id: '3',
        name: '대전휴게소',
        description: '호남고속도로의 주요 휴게소',
        imageUrl: null,
        detail: RestAreaDetail(
          intro: '대전휴게소는 호남고속도로의 주요 거점으로, 다양한 서비스를 제공합니다.',
          address: null,
          mapAddress: null,
          status: null,
          awards: [],
          additionalItems: [],
          stores: [
            StoreInfo(
              id: '1',
              name: '편의점',
              description: '24시간 운영',
            ),
            StoreInfo(
              id: '2',
              name: '카페',
              description: '최고급 원두 커피 제공',
            ),
            StoreInfo(
              id: '3',
              name: '쇼핑몰',
              description: '다양한 상품 판매',
            ),
          ],
          foods: [
            FoodInfo(
              id: '1',
              name: '돈까스',
              description: '바삭한 돈까스 정식',
            ),
            FoodInfo(
              id: '2',
              name: '냉면',
              description: '시원한 물냉면',
            ),
            FoodInfo(
              id: '3',
              name: '비빔밥',
              description: '영양만점 비빔밥',
            ),
          ],
          facilities: [
            FacilityInfo(
              id: '1',
              name: '화장실',
              iconName: 'restroom',
            ),
            FacilityInfo(
              id: '2',
              name: '주차장',
              iconName: 'parking',
            ),
            FacilityInfo(
              id: '3',
              name: '주유소',
              iconName: 'gas',
            ),
            FacilityInfo(
              id: '4',
              name: '휴게실',
              iconName: 'info',
            ),
          ],
        ),
      ),
    ];
  }
}
