// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebPageAttentionImpl {
  static bool isPageVisible() {
    // true면 현재 탭이 보이는 상태
    return !(html.document.hidden ?? false);
  }

  static void setTitle(String title) {
    html.document.title = title;
  }
}

