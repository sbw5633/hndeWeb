import 'window_opener_stub.dart'
    if (dart.library.html) 'window_opener_web.dart';

/// 웹이면 새 창(또는 새 탭)으로 URL을 연다.
/// 웹이 아니면 false.
bool openWindow(String url, {required String name, String? features}) {
  return openWindowImpl(url, name: name, features: features);
}

