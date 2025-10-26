import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/board_post_model.dart';
import '../../const_value.dart';
import 'components/dashboard_appbar.dart';
import 'data/dashboard_data_handler.dart';
import 'components/post_card.dart';
import 'components/notification_center.dart';
import 'components/today_schedule.dart';
import 'components/empty_card.dart';
import 'components/last_update_info.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardDataHandler _dataHandler;
  bool _isLoading = true;
  DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    _setupDataHandler();
  }

  @override
  void dispose() {
    _dataHandler.dispose();
    super.dispose();
  }

  void _setupDataHandler() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.appUser;
    
    if (user == null) return;

    _dataHandler = DashboardDataHandler();
    _dataHandler.setupRealtimeListeners(user);
    
    // 콜백 설정
    _dataHandler.onInitialLoadComplete = () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastLoadTime = DateTime.now();
        });
      }
    };
  }



  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.appUser;

    return Scaffold(
      body: Column(
        children: [
          const DashboardAppBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        // 상단 카드 그리드
                        _buildPostGrid(),
                        const SizedBox(height: 32),
                        // 하단 정보 섹션
                        _buildBottomInfoSection(user),
                        // 마지막 업데이트 시간
                        if (_lastLoadTime != null) ...[
                          const SizedBox(height: 16),
                          LastUpdateInfo(lastLoadTime: _lastLoadTime!),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostGrid() {
    return Column(
      children: [
        // 첫 번째 행: 공지사항
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _dataHandler.recentNotices.isNotEmpty
                    ? PostCard(
                        post: _dataHandler.recentNotices[0],
                        isDataRequest: false,
                        onTap: () => _navigateToPost(_dataHandler.recentNotices[0]),
                      )
                    : const EmptyCard(message: '공지사항이 없습니다'),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _dataHandler.recentNotices.length > 1
                    ? PostCard(
                        post: _dataHandler.recentNotices[1],
                        isDataRequest: false,
                        onTap: () => _navigateToPost(_dataHandler.recentNotices[1]),
                      )
                    : const EmptyCard(message: '공지사항이 없습니다'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 두 번째 행: 자료요청
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _dataHandler.recentDataRequests.isNotEmpty
                    ? PostCard(
                        post: _dataHandler.recentDataRequests[0],
                        isDataRequest: true,
                        onTap: () => _navigateToPost(_dataHandler.recentDataRequests[0]),
                      )
                    : const EmptyCard(message: '자료요청이 없습니다'),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _dataHandler.recentDataRequests.length > 1
                    ? PostCard(
                        post: _dataHandler.recentDataRequests[1],
                        isDataRequest: true,
                        onTap: () => _navigateToPost(_dataHandler.recentDataRequests[1]),
                      )
                    : const EmptyCard(message: '자료요청이 없습니다'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfoSection(AppUser? user) {
    return Row(
      children: [
        // 왼쪽: 알림센터
        Expanded(
          flex: 1,
          child: NotificationCenter(
            weeklyNoticesCount: _dataHandler.weeklyNotices.length,
            weeklyBoardsCount: _dataHandler.weeklyBoards.length,
            unsubmittedDataRequestsCount: _dataHandler.getUnsubmittedDataRequestsCount(
              user?.affiliation ?? '',
            ),
          ),
        ),
        const SizedBox(width: 24),
        // 오른쪽: 오늘의 일정
        const Expanded(
          flex: 1,
          child: TodaySchedule(),
        ),
      ],
    );
  }

  void _navigateToPost(BoardPost post) {
    // 게시물 타입에 따라 상세 페이지로 이동
    switch (post.type) {
      case MenuType.notice:
        context.go('/notices/${post.id}');
        break;
      case MenuType.dataRequest:
        context.go('/data-requests/${post.id}');
        break;
      case MenuType.board:
        context.go('/boards/${post.id}');
        break;
      case MenuType.anonymousBoard:
        context.go('/anonymous-boards/${post.id}');
        break;
      default:
        context.go('/boards/${post.id}');
    }
  }
} 