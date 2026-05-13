// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool openWindowImpl(String url, {required String name, String? features}) {
  final html.WindowBase? w1 = html.window.open(url, name, features ?? '');
  if (w1 != null) {
    return true;
  }
  // 팝업 차단 fallback: 새 탭(_blank)으로 1회 재시도
  final html.WindowBase? w2 = html.window.open(url, '_blank', features ?? '');
  return w2 != null;
}

