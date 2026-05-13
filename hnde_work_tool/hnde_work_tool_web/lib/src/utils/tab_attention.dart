import 'tab_attention_stub.dart'
    if (dart.library.html) 'tab_attention_web.dart';

void tabAttentionStart({required String baseTitle}) {
  tabAttentionStartImpl(baseTitle: baseTitle);
}

void tabAttentionStop() {
  tabAttentionStopImpl();
}

