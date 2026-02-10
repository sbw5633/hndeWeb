import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firestore_service.dart';
import '../models/home_page_config.dart';

final homePageConfigProvider =
    FutureProvider.autoDispose<HomePageConfig?>((ref) async {
  final service = FirestoreService();
  final data = await service.getDocument('home_page', 'main'); // 'home_page' 컬렉션 사용
  if (data == null) return null;
  return HomePageConfig.fromFirestore(data, 'main');
});

final homePageConfigControllerProvider =
    Provider((ref) => HomePageConfigController(ref));

class HomePageConfigController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  HomePageConfigController(this.ref);

  Future<void> save(HomePageConfig config) async {
    await _service.saveDocument(
      'home_page', // 'home_page' 컬렉션 사용
      config.toFirestore(),
      docId: 'main',
    );
    ref.invalidate(homePageConfigProvider);
  }
}
