// 찾아오시는 길 모델
class LocationInfo {
  final String id;
  final String address;
  final String mapAddress; // 지도에 표시할 주소 (위도/경도 또는 주소)
  final String phone;
  final String busInfo;
  final String subwayInfo;

  LocationInfo({
    required this.id,
    required this.address,
    required this.mapAddress,
    required this.phone,
    required this.busInfo,
    required this.subwayInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'mapAddress': mapAddress,
      'phone': phone,
      'busInfo': busInfo,
      'subwayInfo': subwayInfo,
    };
  }

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      id: json['id'] as String,
      address: json['address'] as String,
      mapAddress: json['mapAddress'] as String,
      phone: json['phone'] as String,
      busInfo: json['busInfo'] as String,
      subwayInfo: json['subwayInfo'] as String,
    );
  }

  factory LocationInfo.fromFirestore(Map<String, dynamic> data, String id) {
    return LocationInfo(
      id: id,
      address: data['address'] as String,
      mapAddress: data['mapAddress'] as String,
      phone: data['phone'] as String,
      busInfo: data['busInfo'] as String,
      subwayInfo: data['subwayInfo'] as String,
    );
  }

  static LocationInfo getDummyData() {
    return LocationInfo(
      id: 'location',
      address: '서울특별시 강남구 도곡로 515',
      mapAddress: '서울특별시 강남구 도곡로 515',
      phone: '02-1234-5678',
      busInfo: '146, 740, 3412번 버스 이용',
      subwayInfo: '지하철 2호선 강남역 하차, 3번 출구',
    );
  }
}
