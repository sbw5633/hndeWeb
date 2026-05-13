import 'dart:math' as math;

/// WGS84 구면 거리 [m] (Haversine, 지구 반경 6371 km).
///
/// [latlong2] `LengthUnit.Kilometer`는 **정수 km로 반올림**된 뒤 ×1000 하면
/// 0m·1000m·2000m처럼 보이므로 여기서는 미터를 직접 계산한다.
double distanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadiusM = 6371000.0;
  final double phi1 = lat1 * math.pi / 180;
  final double phi2 = lat2 * math.pi / 180;
  final double dPhi = (lat2 - lat1) * math.pi / 180;
  final double dLambda = (lon2 - lon1) * math.pi / 180;
  final double sdPhi = math.sin(dPhi / 2);
  final double sdL = math.sin(dLambda / 2);
  final double a = sdPhi * sdPhi +
      math.cos(phi1) * math.cos(phi2) * sdL * sdL;
  final double aClamped = a.clamp(0.0, 1.0);
  final double c = 2 * math.asin(math.sqrt(aClamped));
  return earthRadiusM * c;
}

/// 두 좌표 간 거리 (km)
double distanceKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) =>
    distanceMeters(lat1, lon1, lat2, lon2) / 1000.0;
