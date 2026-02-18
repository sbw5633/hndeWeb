import '../models/ceo_greeting.dart';
import '../models/history.dart';
import '../models/vision.dart';
import '../models/location.dart';
import '../models/rest_area.dart';
import '../models/notice.dart';
import '../models/press_release.dart';
import '../models/customer_event.dart';
import '../models/recruitment.dart';
import '../models/ci_info.dart';
import '../models/home_page_config.dart';
import '../models/manufacturing_business.dart';
import '../models/food_beverage_business.dart';
import '../models/business_type.dart';
import '../core/firestore_service.dart';
import '../core/cache_manager.dart';

/// 데이터 서비스 클래스
/// 각 컬렉션별로 데이터를 가져오는 메서드 제공
/// 캐시를 활용하여 최초 접근 시에만 데이터를 로드하고, 새로고침 시 변경된 것만 업데이트
class DataService {
  final FirestoreService _service = FirestoreService();
  final CacheManager _cache = CacheManager();

  // CEO 인사말 가져오기
  Future<CEOGreeting?> getCEOGreeting({bool forceRefresh = false}) async {
    const menuKey = 'company_ceo';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<CEOGreeting>(menuKey);
      if (cached != null) {
        print('💾 CEO 인사말 캐시 사용');
        return cached;
      }
    }
    
    final data = await _service.getDocument(
      FirestoreCollections.ceoGreeting,
      'main',
      forceRefresh: forceRefresh,
    );
    if (data == null) return null;
    
    final result = CEOGreeting.fromFirestore(data, 'main');
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 연혁 목록 가져오기
  Future<List<HistoryItem>> getHistoryList({bool forceRefresh = false}) async {
    const menuKey = 'company_history';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<List<HistoryItem>>(menuKey);
      if (cached != null) {
        print('💾 연혁 목록 캐시 사용');
        return cached;
      }
    }
    
    final dataList = await _service.getCollection(
      FirestoreCollections.history,
      orderBy: 'year',
      descending: true,
      forceRefresh: forceRefresh,
    );
    final result = dataList
        .map((data) => HistoryItem.fromFirestore(data, data['id'] as String))
        .toList();
    
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 비전/경영이념 가져오기
  Future<VisionContent?> getVision({bool forceRefresh = false}) async {
    const menuKey = 'company_vision';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<VisionContent>(menuKey);
      if (cached != null) {
        print('💾 경영이념 및 비전 캐시 사용');
        return cached;
      }
    }
    
    final data = await _service.getDocument(
      FirestoreCollections.vision,
      'main',
      forceRefresh: forceRefresh,
    );
    if (data == null) return null;
    
    final result = VisionContent.fromFirestore(data, 'main');
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 회사 위치 정보 가져오기
  Future<LocationInfo?> getLocation({bool forceRefresh = false}) async {
    const menuKey = 'company_location';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<LocationInfo>(menuKey);
      if (cached != null) {
        print('💾 위치 정보 캐시 사용');
        return cached;
      }
    }
    
    final data = await _service.getDocument(
      FirestoreCollections.location,
      'main',
      forceRefresh: forceRefresh,
    );
    if (data == null) return null;
    
    final result = LocationInfo.fromFirestore(data, 'main');
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 휴게소 목록 가져오기
  Future<List<RestArea>> getRestAreaList({bool forceRefresh = false}) async {
    const menuKey = 'business_restarea';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<List<RestArea>>(menuKey);
      if (cached != null) {
        print('💾 휴게소 목록 캐시 사용');
        return cached;
      }
    }
    
    final dataList = await _service.getCollection(
      FirestoreCollections.restAreas,
      forceRefresh: forceRefresh,
    );
    final result = dataList
        .map((data) => RestArea.fromFirestore(data, data['id'] as String))
        .toList();
    
    // order 기준으로 정렬
    result.sort((a, b) => a.order.compareTo(b.order));
    
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 특정 휴게소 가져오기
  Future<RestArea?> getRestArea(String id) async {
    final data = await _service.getDocument(
      FirestoreCollections.restAreas,
      id,
    );
    if (data == null) return null;
    return RestArea.fromFirestore(data, id);
  }

  // 공지사항 목록 가져오기
  Future<List<Notice>> getNoticeList({int? limit, bool forceRefresh = false}) async {
    final menuKey = 'community_notice${limit != null ? '_$limit' : ''}';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<List<Notice>>(menuKey);
      if (cached != null) {
        print('💾 공지사항 목록 캐시 사용');
        return cached;
      }
    }
    
    final dataList = await _service.getCollection(
      FirestoreCollections.notices,
      orderBy: 'date',
      descending: true,
      limit: limit,
      forceRefresh: forceRefresh,
    );
    final result = dataList
        .map((data) => Notice.fromFirestore(data, data['id'] as String))
        .toList();
    
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 특정 공지사항 가져오기
  Future<Notice?> getNotice(String id) async {
    final data = await _service.getDocument(
      FirestoreCollections.notices,
      id,
    );
    if (data == null) return null;
    return Notice.fromFirestore(data, id);
  }

  // 보도자료 목록 가져오기
  Future<List<PressRelease>> getPressReleaseList({int? limit, bool forceRefresh = false}) async {
    final menuKey = 'pr_press${limit != null ? '_$limit' : ''}';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<List<PressRelease>>(menuKey);
      if (cached != null) {
        print('💾 보도자료 목록 캐시 사용');
        return cached;
      }
    }
    
    final dataList = await _service.getCollection(
      FirestoreCollections.pressReleases,
      orderBy: 'date',
      descending: true,
      limit: limit,
      forceRefresh: forceRefresh,
    );
    final result = dataList
        .map((data) => PressRelease.fromFirestore(data, data['id'] as String))
        .toList();
    
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 특정 보도자료 가져오기
  Future<PressRelease?> getPressRelease(String id) async {
    final data = await _service.getDocument(
      FirestoreCollections.pressReleases,
      id,
    );
    if (data == null) return null;
    return PressRelease.fromFirestore(data, id);
  }

  // 고객 이벤트 목록 가져오기 (활성화된 것만)
  Future<List<CustomerEvent>> getCustomerEventList({int? limit, bool forceRefresh = false}) async {
    final menuKey = 'pr_events${limit != null ? '_$limit' : ''}';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<List<CustomerEvent>>(menuKey);
      if (cached != null) {
        print('💾 고객 이벤트 목록 캐시 사용');
        return cached;
      }
    }
    
    final dataList = await _service.getCollection(
      FirestoreCollections.customerEvents,
      orderBy: 'startDate',
      descending: true,
      limit: limit,
      forceRefresh: forceRefresh,
    );
    final events = dataList
        .map((data) => CustomerEvent.fromFirestore(data, data['id'] as String))
        .toList();
    // 활성화된 이벤트만 필터링
    final now = DateTime.now();
    final result = events.where((event) {
      return event.isActive &&
          event.startDate.isBefore(now) &&
          event.endDate.isAfter(now);
    }).toList();
    
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 특정 고객 이벤트 가져오기
  Future<CustomerEvent?> getCustomerEvent(String id) async {
    final data = await _service.getDocument(
      FirestoreCollections.customerEvents,
      id,
    );
    if (data == null) return null;
    return CustomerEvent.fromFirestore(data, id);
  }

  // 채용 정보 가져오기
  Future<Recruitment?> getRecruitment({bool forceRefresh = false}) async {
    const menuKey = 'recruitment_info';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<Recruitment>(menuKey);
      if (cached != null) {
        print('💾 채용 정보 캐시 사용');
        return cached;
      }
    }
    
    final data = await _service.getDocument(
      FirestoreCollections.recruitment,
      'main',
      forceRefresh: forceRefresh,
    );
    if (data == null) return null;
    
    final result = Recruitment.fromFirestore(data, 'main');
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // CI 정보 가져오기
  Future<CIInfo?> getCIInfo({bool forceRefresh = false}) async {
    const menuKey = 'pr_ci';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<CIInfo>(menuKey);
      if (cached != null) {
        print('💾 CI 정보 캐시 사용');
        return cached;
      }
    }
    
    final data = await _service.getDocument(
      FirestoreCollections.ciInfo,
      'main',
      forceRefresh: forceRefresh,
    );
    if (data == null) return null;
    
    final result = CIInfo.fromFirestore(data, 'main');
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 홈페이지 설정 가져오기
  Future<HomePageConfig?> getHomePageConfig({bool forceRefresh = false}) async {
    const menuKey = 'home_page';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<HomePageConfig>(menuKey);
      if (cached != null) {
        print('💾 홈페이지 설정 캐시 사용');
        return cached;
      }
    }
    
    try {
      print('🏠 홈페이지 설정 가져오기 시작');
      final data = await _service.getDocument(
        FirestoreCollections.homePage, // 'home_page' 컬렉션 사용
        'main',
        forceRefresh: forceRefresh,
      );
      print('📊 받은 데이터: $data');
      if (data == null) {
        print('⚠️ 홈페이지 설정 데이터가 없음');
        return null;
      }
      final config = HomePageConfig.fromFirestore(data, 'main');
      print(
          '✅ 홈페이지 설정 파싱 완료: topLogoUrl=${config.topLogoUrl}, mainHero=${config.mainHero?.imageUrl}');
      
      _cache.set(menuKey, config);
      _cache.markAsAccessed(menuKey);
      return config;
    } catch (e, stackTrace) {
      print('❌ 홈페이지 설정 가져오기 오류: $e');
      print('스택 트레이스: $stackTrace');
      return null;
    }
  }

  // 제조유통사업 정보 가져오기
  Future<ManufacturingBusiness?> getManufacturingBusiness({bool forceRefresh = false}) async {
    const menuKey = 'business_manufacturing';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<ManufacturingBusiness>(menuKey);
      if (cached != null) {
        print('💾 제조유통사업 캐시 사용');
        return cached;
      }
    }
    
    final data = await _service.getDocument(
      FirestoreCollections.manufacturingBusiness,
      'main',
      forceRefresh: forceRefresh,
    );
    if (data == null) return null;
    
    final result = ManufacturingBusiness.fromFirestore(data);
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 식음료사업 정보 가져오기
  Future<FoodBeverageBusiness?> getFoodBeverageBusiness({bool forceRefresh = false}) async {
    const menuKey = 'business_food';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<FoodBeverageBusiness>(menuKey);
      if (cached != null) {
        print('💾 식음료사업 캐시 사용');
        return cached;
      }
    }
    
    final data = await _service.getDocument(
      FirestoreCollections.foodBeverageBusiness,
      'main',
      forceRefresh: forceRefresh,
    );
    if (data == null) return null;
    
    final result = FoodBeverageBusiness.fromFirestore(data);
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 주요사업 타입 목록 가져오기
  Future<List<BusinessType>> getBusinessTypeList({bool forceRefresh = false}) async {
    const menuKey = 'business_types';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<List<BusinessType>>(menuKey);
      if (cached != null) {
        print('💾 주요사업 타입 캐시 사용');
        return cached;
      }
    }
    
    final dataList = await _service.getCollection(
      FirestoreCollections.businessTypes,
      forceRefresh: forceRefresh,
    );
    
    final result = dataList
        .map((data) => BusinessType.fromFirestore(data, data['id'] as String))
        .toList();
    result.sort((a, b) => a.order.compareTo(b.order));
    
    _cache.set(menuKey, result);
    _cache.markAsAccessed(menuKey);
    return result;
  }

  // 동적 사업 데이터 가져오기
  Future<Map<String, dynamic>?> getDynamicBusinessData(String businessTypeId, {bool forceRefresh = false}) async {
    final menuKey = 'business_data_$businessTypeId';
    
    // 캐시 확인 (강제 새로고침이 아니면)
    if (!forceRefresh) {
      final cached = _cache.get<Map<String, dynamic>>(menuKey);
      if (cached != null) {
        print('💾 동적 사업 데이터 캐시 사용: $businessTypeId');
        return cached;
      }
    }
    
    final data = await _service.getDocument(
      FirestoreCollections.businessData,
      businessTypeId,
      forceRefresh: forceRefresh,
    );
    
    if (data != null) {
      _cache.set(menuKey, data);
      _cache.markAsAccessed(menuKey);
    }
    
    return data;
  }

  /// 새로고침: 모든 캐시를 무효화하고 변경된 데이터만 업데이트
  /// 실제로는 모든 메뉴의 데이터를 다시 가져오지만, FirestoreService 레벨에서
  /// ETag 비교를 통해 변경된 것만 실제로 네트워크 요청을 수행합니다.
  Future<void> refreshAll({List<String>? menuKeys}) async {
    print('🔄 전체 새로고침 시작');
    
    // 특정 메뉴만 새로고침하거나, 전체 새로고침
    final keysToRefresh = menuKeys ?? [
      'home_page',
      'company_ceo',
      'company_history',
      'company_vision',
      'company_location',
      'business_restarea',
      'business_manufacturing',
      'business_food',
      'business_types',
      'community_notice',
      'pr_press',
      'pr_events',
      'pr_ci',
      'recruitment_info',
    ];
    
    // 각 메뉴별로 forceRefresh로 데이터 다시 가져오기
    // FirestoreService 레벨에서 ETag 비교를 통해 변경된 것만 실제로 업데이트됨
    for (final key in keysToRefresh) {
      try {
        switch (key) {
          case 'home_page':
            await getHomePageConfig(forceRefresh: true);
            break;
          case 'company_ceo':
            await getCEOGreeting(forceRefresh: true);
            break;
          case 'company_history':
            await getHistoryList(forceRefresh: true);
            break;
          case 'company_vision':
            await getVision(forceRefresh: true);
            break;
          case 'company_location':
            await getLocation(forceRefresh: true);
            break;
          case 'business_restarea':
            await getRestAreaList(forceRefresh: true);
            break;
          case 'business_manufacturing':
            await getManufacturingBusiness(forceRefresh: true);
            break;
          case 'business_food':
            await getFoodBeverageBusiness(forceRefresh: true);
            break;
          case 'business_types':
            await getBusinessTypeList(forceRefresh: true);
            break;
          case 'community_notice':
            await getNoticeList(limit: 50, forceRefresh: true);
            break;
          case 'pr_press':
            await getPressReleaseList(forceRefresh: true);
            break;
          case 'pr_events':
            await getCustomerEventList(forceRefresh: true);
            break;
          case 'pr_ci':
            await getCIInfo(forceRefresh: true);
            break;
          case 'recruitment_info':
            await getRecruitment(forceRefresh: true);
            break;
        }
      } catch (e) {
        print('⚠️ $key 새로고침 중 오류: $e');
      }
    }
    
    print('✅ 전체 새로고침 완료');
  }
}
