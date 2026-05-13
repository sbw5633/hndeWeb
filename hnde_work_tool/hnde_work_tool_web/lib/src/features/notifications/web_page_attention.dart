import 'web_page_attention_stub.dart'
    if (dart.library.html) 'web_page_attention_web.dart';

/// 웹 탭 비활성 시 알림 주의 환기용(타이틀 변경/가시성 확인).
class WebPageAttention {
  static bool isPageVisible() => WebPageAttentionImpl.isPageVisible();

  static void setTitle(String title) => WebPageAttentionImpl.setTitle(title);
}

