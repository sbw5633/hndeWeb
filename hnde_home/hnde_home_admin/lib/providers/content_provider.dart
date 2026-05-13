import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/firestore_service.dart';
import '../models/press_release.dart';
import '../models/customer_event.dart';
import '../models/notice.dart';
import '../models/ci_info.dart';
import '../models/rest_area.dart';
import '../models/recruitment.dart';
import '../models/customer_story_submission.dart';
import '../models/business_proposal_submission.dart';
import '../models/manufacturing_business.dart';
import '../models/food_beverage_business.dart';
import '../models/business_type.dart';

// 보도자료 Provider
final pressReleaseListProvider =
    FutureProvider.autoDispose<List<PressRelease>>((ref) async {
  final service = FirestoreService();
  final dataList =
      await service.getCollection(FirestoreCollections.pressReleases);
  return dataList
      .map((data) => PressRelease.fromFirestore(data, data['id'] as String))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

final pressReleaseControllerProvider =
    Provider((ref) => PressReleaseController(ref));

class PressReleaseController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  PressReleaseController(this.ref);

  Future<void> add(PressRelease item) async {
    await _service.saveDocument(
      FirestoreCollections.pressReleases,
      item.toFirestore(),
    );
    ref.invalidate(pressReleaseListProvider);
  }

  Future<void> update(PressRelease item) async {
    await _service.updateDocument(
      FirestoreCollections.pressReleases,
      item.id,
      item.toFirestore(),
    );
    ref.invalidate(pressReleaseListProvider);
  }

  Future<void> delete(String id) async {
    await _service.deleteDocument(FirestoreCollections.pressReleases, id);
    ref.invalidate(pressReleaseListProvider);
  }
}

// 고객이벤트 Provider
final customerEventListProvider =
    FutureProvider.autoDispose<List<CustomerEvent>>((ref) async {
  final service = FirestoreService();
  final dataList =
      await service.getCollection(FirestoreCollections.customerEvents);
  return dataList
      .map((data) => CustomerEvent.fromFirestore(data, data['id'] as String))
      .toList()
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
});

final customerEventControllerProvider =
    Provider((ref) => CustomerEventController(ref));

class CustomerEventController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  CustomerEventController(this.ref);

  Future<void> add(CustomerEvent item) async {
    await _service.saveDocument(
      FirestoreCollections.customerEvents,
      item.toFirestore(),
    );
    ref.invalidate(customerEventListProvider);
  }

  Future<void> update(CustomerEvent item) async {
    await _service.updateDocument(
      FirestoreCollections.customerEvents,
      item.id,
      item.toFirestore(),
    );
    ref.invalidate(customerEventListProvider);
  }

  Future<void> delete(String id) async {
    await _service.deleteDocument(FirestoreCollections.customerEvents, id);
    ref.invalidate(customerEventListProvider);
  }
}

// 공지사항 Provider
final noticeListProvider =
    FutureProvider.autoDispose<List<Notice>>((ref) async {
  final service = FirestoreService();
  final dataList = await service.getCollection(FirestoreCollections.notices);
  return dataList
      .map((data) => Notice.fromFirestore(data, data['id'] as String))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
});

final noticeControllerProvider = Provider((ref) => NoticeController(ref));

class NoticeController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  NoticeController(this.ref);

  Future<void> add(Notice item) async {
    await _service.saveDocument(
      FirestoreCollections.notices,
      item.toFirestore(),
    );
    ref.invalidate(noticeListProvider);
  }

  Future<void> update(Notice item) async {
    await _service.updateDocument(
      FirestoreCollections.notices,
      item.id,
      item.toFirestore(),
    );
    ref.invalidate(noticeListProvider);
  }

  Future<void> delete(String id) async {
    await _service.deleteDocument(FirestoreCollections.notices, id);
    ref.invalidate(noticeListProvider);
  }
}

// CI 정보 Provider
final ciInfoProvider = FutureProvider.autoDispose<CIInfo?>((ref) async {
  final service = FirestoreService();
  final data = await service.getDocument(
    FirestoreCollections.ciInfo,
    'main',
  );
  if (data == null) return null;
  return CIInfo.fromFirestore(data, 'main');
});

final ciInfoControllerProvider = Provider((ref) => CIInfoController(ref));

class CIInfoController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  CIInfoController(this.ref);

  Future<void> save(CIInfo ciInfo) async {
    await _service.saveDocument(
      FirestoreCollections.ciInfo,
      ciInfo.toFirestore(),
      docId: 'main',
    );
    ref.invalidate(ciInfoProvider);
  }
}

// 휴게소 Provider
final restAreaListProvider =
    FutureProvider.autoDispose<List<RestArea>>((ref) async {
  final service = FirestoreService();
  final dataList = await service.getCollection(FirestoreCollections.restAreas);
  final result = dataList
      .map((data) => RestArea.fromFirestore(data, data['id'] as String))
      .toList();
  // order 기준으로 정렬
  result.sort((a, b) => a.order.compareTo(b.order));
  return result;
});

final restAreaControllerProvider = Provider((ref) => RestAreaController(ref));

class RestAreaController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  RestAreaController(this.ref);

  Future<void> add(RestArea item) async {
    await _service.saveDocument(
      FirestoreCollections.restAreas,
      item.toFirestore(),
    );
    ref.invalidate(restAreaListProvider);
  }

  Future<void> update(RestArea item) async {
    await _service.updateDocument(
      FirestoreCollections.restAreas,
      item.id,
      item.toFirestore(),
    );
    ref.invalidate(restAreaListProvider);
  }

  Future<void> delete(String id) async {
    await _service.deleteDocument(FirestoreCollections.restAreas, id);
    ref.invalidate(restAreaListProvider);
  }
}

// 인재채용 Provider
final recruitmentProvider =
    FutureProvider.autoDispose<Recruitment?>((ref) async {
  final service = FirestoreService();
  final data = await service.getDocument(
    FirestoreCollections.recruitment,
    'main',
  );
  if (data == null) return null;
  return Recruitment.fromFirestore(data, 'main');
});

final recruitmentControllerProvider =
    Provider((ref) => RecruitmentController(ref));

class RecruitmentController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  RecruitmentController(this.ref);

  Future<void> save(Recruitment recruitment) async {
    await _service.saveDocument(
      FirestoreCollections.recruitment,
      recruitment.toFirestore(),
      docId: 'main',
    );
    ref.invalidate(recruitmentProvider);
  }
}

// 고객의 이야기 조회 Provider
final customerStoryListProvider =
    FutureProvider.autoDispose<List<CustomerStorySubmission>>((ref) async {
  final service = FirestoreService();
  final dataList =
      await service.getCollection(FirestoreCollections.customerStories);
  return dataList
      .map((data) =>
          CustomerStorySubmission.fromFirestore(data, data['id'] as String))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

// 사업제안 조회 Provider
final businessProposalListProvider =
    FutureProvider.autoDispose<List<BusinessProposalSubmission>>((ref) async {
  final service = FirestoreService();
  final dataList =
      await service.getCollection(FirestoreCollections.businessProposals);
  return dataList
      .map((data) =>
          BusinessProposalSubmission.fromFirestore(data, data['id'] as String))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

// 제조유통사업 Provider
final manufacturingBusinessProvider =
    FutureProvider.autoDispose<ManufacturingBusiness?>((ref) async {
  final service = FirestoreService();
  final data = await service.getDocument(
    FirestoreCollections.manufacturingBusiness,
    'main',
  );
  if (data == null) {
    return ManufacturingBusiness(categories: []);
  }
  return ManufacturingBusiness.fromFirestore(data);
});

final manufacturingBusinessControllerProvider =
    Provider((ref) => ManufacturingBusinessController(ref));

class ManufacturingBusinessController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  ManufacturingBusinessController(this.ref);

  Future<void> save(ManufacturingBusiness business) async {
    await _service.saveDocument(
      FirestoreCollections.manufacturingBusiness,
      business.toFirestore(),
      docId: 'main',
    );
    ref.invalidate(manufacturingBusinessProvider);
  }
}

// 식음료사업 Provider
final foodBeverageBusinessProvider =
    FutureProvider.autoDispose<FoodBeverageBusiness?>((ref) async {
  final service = FirestoreService();
  final data = await service.getDocument(
    FirestoreCollections.foodBeverageBusiness,
    'main',
  );
  if (data == null) {
    return FoodBeverageBusiness(categories: []);
  }
  return FoodBeverageBusiness.fromFirestore(data);
});

final foodBeverageBusinessControllerProvider =
    Provider((ref) => FoodBeverageBusinessController(ref));

class FoodBeverageBusinessController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  FoodBeverageBusinessController(this.ref);

  Future<void> save(FoodBeverageBusiness business) async {
    await _service.saveDocument(
      FirestoreCollections.foodBeverageBusiness,
      business.toFirestore(),
      docId: 'main',
    );
    ref.invalidate(foodBeverageBusinessProvider);
  }
}

// 주요사업 타입 Provider
final businessTypeListProvider =
    FutureProvider.autoDispose<List<BusinessType>>((ref) async {
  final service = FirestoreService();
  final dataList =
      await service.getCollection(FirestoreCollections.businessTypes);
  final result = dataList
      .map((data) => BusinessType.fromFirestore(data, data['id'] as String))
      .toList();
  // order 기준으로 정렬
  result.sort((a, b) => a.order.compareTo(b.order));
  return result;
});

final businessTypeControllerProvider =
    Provider((ref) => BusinessTypeController(ref));

class BusinessTypeController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  BusinessTypeController(this.ref);

  Future<String> add(BusinessType item) async {
    final docId = await _service.saveDocument(
      FirestoreCollections.businessTypes,
      item.toFirestore(),
      docId: item.id.isNotEmpty ? item.id : null,
    );
    ref.invalidate(businessTypeListProvider);
    return docId;
  }

  Future<void> update(BusinessType item) async {
    await _service.updateDocument(
      FirestoreCollections.businessTypes,
      item.id,
      item.toFirestore(),
    );
    ref.invalidate(businessTypeListProvider);
  }

  Future<void> delete(String id) async {
    await _service.deleteDocument(FirestoreCollections.businessTypes, id);
    // 사업 타입 삭제 시 해당 사업 데이터도 삭제
    await _service.deleteDocument(FirestoreCollections.businessData, id);
    ref.invalidate(businessTypeListProvider);
  }
}

// 동적 사업 데이터 Provider
final dynamicBusinessDataProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, businessTypeId) async {
    final service = FirestoreService();
    final data = await service.getDocument(
      FirestoreCollections.businessData,
      businessTypeId,
    );
    return data;
  },
);

final dynamicBusinessDataControllerProvider =
    Provider((ref) => DynamicBusinessDataController(ref));

class DynamicBusinessDataController {
  final Ref ref;
  final FirestoreService _service = FirestoreService();

  DynamicBusinessDataController(this.ref);

  Future<void> save(String businessTypeId, String layoutType, Map<String, dynamic> data) async {
    // businessTypeId를 docId로 사용하여 저장
    await _service.saveDocument(
      FirestoreCollections.businessData,
      {
        'layoutType': layoutType,
        ...data,
      },
      docId: businessTypeId,
    );
    ref.invalidate(dynamicBusinessDataProvider(businessTypeId));
  }

  Future<void> delete(String businessTypeId) async {
    await _service.deleteDocument(FirestoreCollections.businessData, businessTypeId);
    ref.invalidate(dynamicBusinessDataProvider(businessTypeId));
  }
}

