import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firestore_service.dart';
import '../models/ceo_greeting.dart';
import '../models/history_item.dart';
import '../models/vision_content.dart';
import '../models/location_info.dart';

// CEO 인사말 Provider
final ceoGreetingProvider =
    FutureProvider.autoDispose<CEOGreeting?>((ref) async {
  final service = FirestoreService();
  final data = await service.getDocument(
    FirestoreCollections.ceoGreeting,
    'main',
  );
  if (data == null) return null;
  return CEOGreeting.fromFirestore(data, 'main');
});

final ceoGreetingControllerProvider =
    Provider((ref) => CEOGreetingController(ref));

class CEOGreetingController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  CEOGreetingController(this.ref);

  Future<void> save(CEOGreeting greeting) async {
    await _service.saveDocument(
      FirestoreCollections.ceoGreeting,
      greeting.toFirestore(),
      docId: 'main',
    );
    ref.invalidate(ceoGreetingProvider);
  }
}

// 연혁 Provider
final historyListProvider =
    FutureProvider.autoDispose<List<HistoryItem>>((ref) async {
  final service = FirestoreService();
  final dataList = await service.getCollection(FirestoreCollections.history);
  return dataList
      .map((data) => HistoryItem.fromFirestore(data, data['id'] as String))
      .toList()
    ..sort((a, b) => b.year.compareTo(a.year));
});

final historyControllerProvider = Provider((ref) => HistoryController(ref));

class HistoryController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  HistoryController(this.ref);

  Future<void> add(HistoryItem item) async {
    await _service.saveDocument(
      FirestoreCollections.history,
      item.toFirestore(),
    );
    ref.invalidate(historyListProvider);
  }

  Future<void> update(HistoryItem item) async {
    await _service.updateDocument(
      FirestoreCollections.history,
      item.id,
      item.toFirestore(),
    );
    ref.invalidate(historyListProvider);
  }

  Future<void> delete(String id) async {
    await _service.deleteDocument(FirestoreCollections.history, id);
    ref.invalidate(historyListProvider);
  }
}

// 경영이념 및 비전 Provider
final visionProvider = FutureProvider.autoDispose<VisionContent?>((ref) async {
  final service = FirestoreService();
  final data = await service.getDocument(
    FirestoreCollections.vision,
    'main',
  );
  if (data == null) return null;
  return VisionContent.fromFirestore(data, 'main');
});

final visionControllerProvider = Provider((ref) => VisionController(ref));

class VisionController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  VisionController(this.ref);

  Future<void> save(VisionContent vision) async {
    await _service.saveDocument(
      FirestoreCollections.vision,
      vision.toFirestore(),
      docId: 'main',
    );
    ref.invalidate(visionProvider);
  }
}

// 찾아오시는 길 Provider
final locationProvider = FutureProvider.autoDispose<LocationInfo?>((ref) async {
  final service = FirestoreService();
  final data = await service.getDocument(
    FirestoreCollections.location,
    'main',
  );
  if (data == null) return null;
  return LocationInfo.fromFirestore(data, 'main');
});

final locationControllerProvider = Provider((ref) => LocationController(ref));

class LocationController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  LocationController(this.ref);

  Future<void> save(LocationInfo location) async {
    await _service.saveDocument(
      FirestoreCollections.location,
      location.toFirestore(),
      docId: 'main',
    );
    ref.invalidate(locationProvider);
  }
}
