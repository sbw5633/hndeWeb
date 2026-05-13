// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

Timer? _timer;
String? _origTitle;
String? _origFaviconHref;
bool _flip = false;

html.LinkElement? _faviconLink() {
  final List<html.Element> links =
      html.document.querySelectorAll('link[rel=\"icon\"], link[rel=\"shortcut icon\"]');
  if (links.isEmpty) return null;
  return links.first as html.LinkElement;
}

String _badgeSvgDataUrl({required bool on}) {
  final String color = on ? '#ef4444' : '#64748b';
  final String svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">
  <rect width="64" height="64" rx="14" fill="#0f172a"/>
  <circle cx="48" cy="16" r="10" fill="$color"/>
</svg>
''';
  final String encoded = Uri.encodeComponent(svg)
      .replaceAll('%0A', '')
      .replaceAll('%20', ' ');
  return 'data:image/svg+xml,$encoded';
}

void tabAttentionStartImpl({required String baseTitle}) {
  _origTitle ??= html.document.title;
  final html.LinkElement? fav = _faviconLink();
  _origFaviconHref ??= fav?.href;
  _timer?.cancel();
  _flip = false;
  _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
    _flip = !_flip;
    html.document.title = _flip ? '● $baseTitle (새 메시지)' : baseTitle;
    final html.LinkElement? f = _faviconLink();
    if (f != null) {
      f.href = _badgeSvgDataUrl(on: _flip);
    }
  });
}

void tabAttentionStopImpl() {
  _timer?.cancel();
  _timer = null;
  if (_origTitle != null) {
    html.document.title = _origTitle!;
  }
  final html.LinkElement? f = _faviconLink();
  if (f != null && _origFaviconHref != null) {
    f.href = _origFaviconHref!;
  }
  _origTitle = null;
  _origFaviconHref = null;
}

