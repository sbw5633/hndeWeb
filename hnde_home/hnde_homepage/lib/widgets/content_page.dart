import 'package:flutter/material.dart';
import 'image_text_page.dart';
import 'history_page.dart';
import 'vision_page.dart';
import 'location_page.dart';
import 'rest_area_page.dart';
import 'ci_page.dart';
import 'press_release_page.dart';
import 'customer_event_page.dart';
import 'notice_page.dart';
import 'customer_story_form_page.dart';
import 'business_proposal_form_page.dart';
import 'recruitment_page.dart';
import 'ceo_greeting_page.dart';
import 'manufacturing_business_page.dart';
import 'food_beverage_business_page.dart';
import '../services/data_service.dart';
import '../models/ci_info.dart';
import '../models/rest_area.dart';
import '../models/manufacturing_business.dart';
import '../models/food_beverage_business.dart';
import '../models/recruitment.dart';

class ContentPage extends StatelessWidget {
  final String menuId;
  final String subMenuId;

  const ContentPage({
    super.key,
    required this.menuId,
    required this.subMenuId,
  });

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final routeKey = '${menuId}_$subMenuId';

    // 타입에 따라 적절한 위젯 표시
    switch (routeKey) {
      case 'company_history':
        return FutureBuilder(
          future: dataService.getHistoryList(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            return HistoryPage(historyItems: snapshot.data ?? []);
          },
        );

      case 'company_vision':
        return FutureBuilder(
          future: dataService.getVision(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            if (snapshot.data == null) {
              return const Center(child: Text('데이터가 없습니다.'));
            }
            return VisionPage(content: snapshot.data!);
          },
        );

      case 'company_location':
        return FutureBuilder(
          future: dataService.getLocation(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            if (snapshot.data == null) {
              return const Center(child: Text('데이터가 없습니다.'));
            }
            return LocationPage(locationInfo: snapshot.data!);
          },
        );

      case 'business_restarea':
        // 임시: 더미 데이터로 테스트
        return FutureBuilder(
          future: dataService.getRestAreaList(),
          builder: (context, snapshot) {
            // 더미 데이터 사용 (임시)
            final dummyData = RestAreaData.getDummyData();
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              // 로딩 중에도 더미 데이터 표시
              return RestAreaListPage(restAreas: dummyData);
            }
            if (snapshot.hasError) {
              // 오류 발생 시에도 더미 데이터 표시
              print('휴게소 데이터 로딩 오류: ${snapshot.error}');
              return RestAreaListPage(restAreas: dummyData);
            }
            // 실제 데이터가 있으면 사용, 없으면 더미 데이터 사용
            final restAreas = snapshot.data ?? [];
            return RestAreaListPage(
              restAreas: restAreas.isNotEmpty ? restAreas : dummyData,
            );
          },
        );

      case 'business_manufacturing':
        return FutureBuilder(
          future: dataService.getManufacturingBusiness(),
          builder: (context, snapshot) {
            // 더미 데이터 사용 (임시)
            final dummyData = ManufacturingBusiness.getDummyData();
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ManufacturingBusinessPage(data: dummyData);
            }
            if (snapshot.hasError) {
              print('제조유통사업 데이터 로딩 오류: ${snapshot.error}');
              return ManufacturingBusinessPage(data: dummyData);
            }
            // 실제 데이터가 있으면 사용, 없으면 더미 데이터 사용
            return ManufacturingBusinessPage(
              data: snapshot.data ?? dummyData,
            );
          },
        );

      case 'business_food':
        return FutureBuilder(
          future: dataService.getFoodBeverageBusiness(),
          builder: (context, snapshot) {
            // 더미 데이터 사용 (임시)
            final dummyData = FoodBeverageBusiness.getDummyData();
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return FoodBeverageBusinessPage(data: dummyData);
            }
            if (snapshot.hasError) {
              print('식음료사업 데이터 로딩 오류: ${snapshot.error}');
              return FoodBeverageBusinessPage(data: dummyData);
            }
            // 실제 데이터가 있으면 사용, 없으면 더미 데이터 사용
            return FoodBeverageBusinessPage(
              data: snapshot.data ?? dummyData,
            );
          },
        );

      case 'pr_ci':
        return FutureBuilder(
          future: dataService.getCIInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            if (snapshot.data == null) {
              return CIPage(ciInfo: CIInfo.getDummyData());
            }
            return CIPage(ciInfo: snapshot.data!);
          },
        );

      case 'pr_press':
        return FutureBuilder(
          future: dataService.getPressReleaseList(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            return PressReleasePage(pressReleases: snapshot.data ?? []);
          },
        );

      case 'pr_events':
        return FutureBuilder(
          future: dataService.getCustomerEventList(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            return CustomerEventPage(events: snapshot.data ?? []);
          },
        );

      case 'community_notice':
        return FutureBuilder(
          future: dataService.getNoticeList(limit: 50),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            return NoticePage(notices: snapshot.data ?? []);
          },
        );

      case 'community_stories':
        return const CustomerStoryFormPage();

      case 'community_proposal':
        return const BusinessProposalFormPage();

      case 'recruitment_info':
        return FutureBuilder(
          future: dataService.getRecruitment(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            final recruitment = snapshot.data ?? Recruitment.getDummyData();
            return RecruitmentPage(recruitment: recruitment);
          },
        );

      case 'company_ceo':
        return FutureBuilder(
          future: dataService.getCEOGreeting(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('오류: ${snapshot.error}'));
            }
            final greeting = snapshot.data;
            if (greeting == null) {
              return CEOGreetingPage(
                imageUrl: null,
                imageFit: 'cover',
                textLines: [],
              );
            }
            return CEOGreetingPage(
              imageUrl: greeting.imageUrl,
              imageFit: greeting.imageFit ?? 'cover',
              textLines: greeting.textLines,
            );
          },
        );

      default:
        return ImageTextPage(
          imageUrl: null,
          title: _getTitle(menuId, subMenuId),
          content: _getContent(menuId, subMenuId),
        );
    }
  }

  String _getTitle(String menuId, String subMenuId) {
    final titles = {
      'company_ceo': 'CEO 인사말',
    };
    return titles['${menuId}_$subMenuId'] ?? '제목';
  }

  String _getContent(String menuId, String subMenuId) {
    final contents = {
      'company_ceo': '''안녕하세요. H&DE를 방문해 주신 여러분께 깊은 감사를 드립니다.

저희 H&DE는 고객 만족을 최우선으로 생각하며, 
지속적인 혁신과 품질 향상을 통해 최고의 서비스를 제공하겠습니다.

앞으로도 고객 여러분과 함께 성장하는 신뢰받는 기업이 되도록 
최선을 다하겠습니다.

감사합니다.

H&DE 대표이사''',
    };
    return contents['${menuId}_$subMenuId'] ?? '내용이 여기에 표시됩니다.';
  }
}
