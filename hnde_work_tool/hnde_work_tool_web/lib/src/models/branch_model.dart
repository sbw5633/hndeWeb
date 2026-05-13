import 'package:cloud_firestore/cloud_firestore.dart';

class BranchModel {
  BranchModel({
    required this.id,
    required this.name,
    required this.groupKey,
    this.latitude,
    this.longitude,
    this.address,
    this.phone,
    this.head,
  });

  final String id;
  final String name;
  final String groupKey;

  /// WGS84 위도 (Firestore: `lat` 또는 `latitude`)
  final double? latitude;

  /// WGS84 경도 (Firestore: `lng` 또는 `longitude`)
  final double? longitude;

  /// 도로명/지번 등 (관리자 입력·카카오 검색으로 확정)
  final String? address;

  final String? phone;

  /// 사업소장 등 표시용
  final String? head;

  static double? _parseCoord(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      return double.tryParse(v.trim());
    }
    return null;
  }

  static String? _str(dynamic v) {
    final String? s = v as String?;
    if (s == null) {
      return null;
    }
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }

  factory BranchModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final double? lat =
        _parseCoord(data['lat']) ?? _parseCoord(data['latitude']);
    final double? lng =
        _parseCoord(data['lng']) ?? _parseCoord(data['longitude']);
    return BranchModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      groupKey: data['groupKey'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      address: _str(data['address']),
      phone: _str(data['phone']),
      head: _str(data['head']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'groupKey': groupKey,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (head != null) 'head': head,
    };
  }
}
