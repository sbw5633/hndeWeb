import 'package:flutter/material.dart';
import 'components/dashboard_appbar.dart';
import '../components/common/notice_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Expanded(
        child: Column(
          children: [
            const DashboardAppBar(),
            // 메인 카드 리스트
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 32,
                  crossAxisSpacing: 32,
                  childAspectRatio: 2,
                  children: const [
                    NoticeCard(title: '6월 전체공지', summary: '전 직원 대상 필독 공지입니다.'),
                    NoticeCard(title: '연차 사용 안내', summary: '연차 신청 및 사용 방법 안내.'),
                    NoticeCard(title: '자료 제출 마감', summary: '6월 자료 제출 마감일은 6/30입니다.'),
                    // TODO: 실제 Firestore 연동, 로그인/회원가입 카드, 승인대기 카드 등 추가
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 