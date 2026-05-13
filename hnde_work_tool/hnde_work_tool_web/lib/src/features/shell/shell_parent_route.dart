/// 셸 상단 뒤로가기용 상위 [GoRouter] 경로.
/// 사이드바 최상위(4대보험·자료송수신·업무 도구 허브 등)에서는 null → 버튼 미표시.
String? shellParentRoute(String rawPath) {
  String p = rawPath;
  if (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }

  if (p == '/work-tools') return null;
  if (p.startsWith('/work-tools/')) return '/work-tools';

  if (p == '/company-info') return null;
  if (p == '/company-org' || p == '/company-rules') return '/company-info';

  if (p.startsWith('/culture-day/')) {
    return '/culture-day';
  }

  if (p == '/insurance') return null;
  if (p.startsWith('/insurance/')) return '/insurance';

  if (p == '/exchange') return null;
  if (p.startsWith('/exchange/')) return '/exchange';

  if (p.startsWith('/board/')) {
    final List<String> segs =
        p.split('/').where((String s) => s.isNotEmpty).toList();
    if (segs.length >= 3 && segs[0] == 'board') {
      switch (segs[1]) {
        case 'notice':
          return '/notice';
        case 'freeboard':
          return '/freeboard';
        case 'anonymous':
          return '/anonymous';
        default:
          return null;
      }
    }
  }

  return null;
}
