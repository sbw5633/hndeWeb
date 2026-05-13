bool _koreaLatBand(double v) => v >= 32 && v <= 44;
bool _koreaLngBand(double v) => v >= 122 && v <= 135;

/// Firestore 등에 위·경도가 뒤바뀌어 저장된 경우(한반도 좌표대만) 보정
({double lat, double lng}) normalizeWgs84Branch(double lat, double lng) {
  if (_koreaLatBand(lat) && _koreaLngBand(lng)) {
    return (lat: lat, lng: lng);
  }
  if (_koreaLatBand(lng) && _koreaLngBand(lat)) {
    return (lat: lng, lng: lat);
  }
  return (lat: lat, lng: lng);
}

/// 한국관광공사 TourAPI 명세: `mapx`=경도, `mapy`=위도 (WGS84 도 단위).
/// 일부 응답은 값만 뒤바뀌어 `mapx`에 위도·`mapy`에 경도가 들어오는 경우가 있어 보정합니다.
({double lat, double lng})? tourApiMapXyToLatLng(double? mapx, double? mapy) {
  if (mapx == null || mapy == null) {
    return null;
  }
  if (_koreaLatBand(mapx) && _koreaLngBand(mapy)) {
    return (lat: mapx, lng: mapy);
  }
  if (_koreaLatBand(mapy) && _koreaLngBand(mapx)) {
    return (lat: mapy, lng: mapx);
  }
  return (lat: mapy, lng: mapx);
}

