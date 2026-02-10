// 찾아오시는 길 모델
class LocationInfo {
  final String id;
  final String address;
  final String mapAddress;
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

  Map<String, dynamic> toFirestore() {
    return {
      'address': address,
      'mapAddress': mapAddress,
      'phone': phone,
      'busInfo': busInfo,
      'subwayInfo': subwayInfo,
    };
  }
}

