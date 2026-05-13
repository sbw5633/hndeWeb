import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/role_constants.dart';
import '../../constants/super_admin.dart';
// AI 오버레이(_AiOverlay)에서만 사용 — 오버레이 주석 시 함께 복구
// import '../common/loading_widget.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../models/app_notification_model.dart';
import '../messenger/messenger_dock_controller.dart';
import '../messenger/messenger_overlay.dart';
import '../notifications/notifications_dock_controller.dart';
import '../notifications/notifications_overlay.dart';
import '../notifications/in_app_notification_toast.dart';
import '../notifications/web_page_attention.dart';
// AI(Gemini) 보류 — 필요 시 아래 import·_gemini·상단바 버튼·오버레이·클래스 주석 해제
// import '../../services/gemini_chat_service.dart';
import '../../theme/app_theme.dart';
import '../common/app_user_avatar.dart';
import '../common/merged_user_profile_stream_builder.dart';
import 'shell_parent_route.dart';

/// React 프로토타입과 유사한 접이식 사이드바 + 상단 앱바 + 드로어
class WorkAppShell extends StatefulWidget {
  const WorkAppShell({required this.child, super.key});

  final Widget child;

  @override
  State<WorkAppShell> createState() => _WorkAppShellState();
}

class _WorkAppShellState extends State<WorkAppShell> with WidgetsBindingObserver {
  bool _sidebarOpen = true;
  // 메신저 열림/크기/위치는 MessengerDockController가 관리합니다.
  // bool _aiOpen = false;

  late final WorkFirestoreRepository _repo;
  StreamSubscription<List<AppNotificationModel>>? _notifSub;
  DateTime? _lastNotifShownAt;
  bool _blinkTitle = false;
  Timer? _blinkTimer;
  InAppNotificationToastManager? _toast;
  String _baseTitle = 'HNDE 업무 지원 툴';

  static const double _narrowBreakpoint = 900;
  bool _wasNarrow = false;
  // final GeminiChatService _gemini = GeminiChatService();

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    WidgetsBinding.instance.addObserver(this);
    _repo.startPresenceHeartbeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toast = InAppNotificationToastManager(Overlay.of(context));
      unawaited(_repo.syncDueSoonSubmissionNotificationsOnLogin());
      _startNotificationStream();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repo.stopPresenceHeartbeat(setOffline: true);
    _notifSub?.cancel();
    _notifSub = null;
    _blinkTimer?.cancel();
    _blinkTimer = null;
    super.dispose();
  }

  void _startNotificationStream() {
    _notifSub?.cancel();
    _notifSub = _repo.watchMyNotifications(limit: 5).listen((List<AppNotificationModel> list) {
      if (!mounted) return;
      if (list.isEmpty) return;
      final AppNotificationModel top = list.first;
      final DateTime? created = top.createdAt?.toDate();
      if (created == null) return;

      // 초기 접속 시 과거 알림이 한꺼번에 토스트 되는 걸 방지
      final DateTime now = DateTime.now();
      final bool isFresh = now.difference(created).inSeconds.abs() <= 8;
      final bool notRecentlyShown = _lastNotifShownAt == null || now.difference(_lastNotifShownAt!).inSeconds >= 2;
      if (!isFresh || !notRecentlyShown) return;
      _lastNotifShownAt = now;

      final bool active = _isTabVisible();
      if (!active) {
        _startTitleBlink();
      }
      _toast?.show(
        notif: top,
        primaryColor: context.read<AppThemeNotifier>().theme.primary,
        onTap: () {
          // 패널/리스트 클릭과 동일하게: 읽음 처리 후 이동
          unawaited(_repo.markNotificationRead(top.id));
          _navigateFromNotif(top);
        },
      );
    });
  }

  // Web only: document.hidden 기반
  bool _isTabVisible() {
    return WebPageAttention.isPageVisible();
  }

  void _startTitleBlink() {
    if (!kIsWeb) return;
    _blinkTimer?.cancel();
    _blinkTitle = false;
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      _blinkTitle = !_blinkTitle;
      _applyTitle();
    });
    _applyTitle();
  }

  void _stopTitleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    _blinkTitle = false;
    _applyTitle();
  }

  void _applyTitle() {
    if (!kIsWeb) return;
    WebPageAttention.setTitle(
      _blinkTitle ? '새 알림 · $_baseTitle' : _baseTitle,
    );
  }

  void _navigateFromNotif(AppNotificationModel n) {
    final Map<String, dynamic> p = n.payload;
    final String type = n.type;
    if (type == 'notice_created' || type == 'post_commented') {
      final String boardType = (p['boardType'] as String?)?.trim().isNotEmpty == true
          ? (p['boardType'] as String).trim()
          : 'notice';
      final String postId = (p['postId'] as String?)?.trim() ?? '';
      if (postId.isNotEmpty) {
        context.go('/board/$boardType/$postId');
      } else {
        context.go('/notice');
      }
      return;
    }
    if (type == 'submission_created' || type == 'submission_due_soon') {
      final String id = (p['submissionId'] as String?)?.trim() ?? '';
      if (id.isNotEmpty) {
        context.go('/exchange/$id');
      } else {
        context.go('/exchange');
      }
      return;
    }
    if (type == 'calendar_event_created') {
      context.go('/calendar');
      return;
    }
    if (type == 'branch_change_decided') {
      context.go('/profile');
      return;
    }
    context.go('/');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _repo.startPresenceHeartbeat();
        _stopTitleBlink();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _repo.stopPresenceHeartbeat(setOffline: true);
        break;
    }
  }

  String _menuId(String path) {
    if (path == '/' || path.isEmpty) return 'dashboard';
    if (path.startsWith('/insurance')) return 'insurance';
    if (path.startsWith('/exchange')) return 'exchange';
    if (path.startsWith('/work-tools')) return 'work-tools';
    if (path.startsWith('/company-info') ||
        path.startsWith('/company-org') ||
        path.startsWith('/company-rules')) {
      return 'company-info';
    }
    if (path.startsWith('/culture-day')) return 'culture-day';
    if (path.startsWith('/calendar')) return 'calendar';
    if (path.startsWith('/todo')) return 'todo';
    if (path.startsWith('/board/notice')) return 'notice';
    if (path.startsWith('/board/freeboard')) return 'freeboard';
    if (path.startsWith('/board/anonymous')) return 'anonymous';
    if (path.startsWith('/notice')) return 'notice';
    if (path.startsWith('/freeboard')) return 'freeboard';
    if (path.startsWith('/anonymous')) return 'anonymous';
    if (path.startsWith('/profile')) return 'profile';
    if (path.startsWith('/my-settings')) return 'my-settings';
    if (path.startsWith('/settings')) return 'admin-settings';
    if (path.startsWith('/files')) return 'files';
    return 'todo';
  }

  String _portalTitle(String menuId, String path) {
    if (menuId == 'work-tools') {
      if (path.startsWith('/work-tools/pdf-merge')) return 'PDF 합치기';
      if (path.startsWith('/work-tools/pdf-split')) return 'PDF 분할';
      if (path.startsWith('/work-tools/file-rename')) return '파일명 편집';
      if (path.startsWith('/work-tools/image-edit')) return '이미지 편집';
      if (path.startsWith('/work-tools/image-collage')) return '이미지 콜라주';
      if (path.startsWith('/work-tools/image-compress')) return '이미지 압축';
      return 'Work Tools';
    }
    switch (menuId) {
      case 'dashboard':
        return 'Dashboard Portal';
      case 'insurance':
        return 'Insurance Portal';
      case 'exchange':
        return 'Exchange Portal';
      case 'company-info':
        if (path.startsWith('/company-org')) return '조직도';
        if (path.startsWith('/company-rules')) return '사규집';
        return 'Company Info';
      case 'culture-day':
        return 'Culture Day Portal';
      case 'calendar':
        return 'Calendar Portal';
      case 'todo':
        return '해야할 일';
      case 'notice':
        return 'Notice Portal';
      case 'freeboard':
        return 'Freeboard Portal';
      case 'anonymous':
        return 'Anonymous Portal';
      case 'profile':
        return 'Profile Portal';
      case 'my-settings':
        return 'Settings Portal';
      case 'admin-settings':
        return 'Admin Settings Portal';
      case 'files':
        return 'Files Portal';
      default:
        return 'Work Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String path = GoRouterState.of(context).uri.path;
    final String menu = _menuId(path);
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    return Consumer<AppThemeNotifier>(
      builder: (
        BuildContext context,
        AppThemeNotifier themeNotifier,
        _,
      ) {
        final AppThemeData appTheme = themeNotifier.theme;
        final Color sidebarColor = appTheme.sidebar;
        final Color sidebarHeaderColor =
            Color.lerp(appTheme.sidebar, Colors.black, 0.15) ?? appTheme.sidebar;
        final Color sidebarTextColor = appTheme.sidebarText;
        final Color primaryColor = appTheme.primary;
        final Color bgColor = appTheme.bg;

        if (uid == null) {
          return Scaffold(
            backgroundColor: bgColor,
            body: const Center(child: Text('로그인이 필요합니다.')),
          );
        }

        final DocumentReference<Map<String, dynamic>> profileRef =
            FirestorePaths.userProfileMainDoc(uid);

        return MergedUserProfileStreamBuilder(
          uid: uid,
          builder: (
            BuildContext context,
            Map<String, dynamic> merged,
            bool streamsWaiting,
          ) {
            final Map<String, dynamic> prof = merged;
            final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
              profileMainAdmin: prof['mainAdmin'],
              profileEmail: prof['email'] as String?,
              authEmail: user?.email,
              roleIdx: (prof['roleIdx'] as num?)?.toInt(),
            );
            final String employmentStatus =
                (prof['employmentStatus'] as String?)?.trim() ?? 'active';
            final bool retired = employmentStatus == 'retired';
            final int roleIdx =
                (prof['roleIdx'] as num?)?.toInt() ?? RoleConstants.unspecified;
            final bool canAccessInsurance =
                RoleConstants.canAccessInsurance(roleIdx);
            final String name = (prof['name'] as String?)?.trim().isNotEmpty == true
                ? (prof['name'] as String).trim()
                : (user?.email ?? '사용자');
            final String position = (prof['position'] as String?)?.trim() ?? '';
            final String branch =
                (prof['branchName'] as String?)?.trim().isNotEmpty == true
                    ? (prof['branchName'] as String).trim()
                    : ((prof['branch'] as String?)?.trim() ?? '');
            final String? photoUrl = (prof['photoUrl'] as String?)?.trim().isNotEmpty == true
                ? (prof['photoUrl'] as String).trim()
                : null;

            final bool allowedForRetired =
                path.startsWith('/profile') || path.startsWith('/my-settings');
            if (retired && !allowedForRetired) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.go('/profile');
              });
            }

            final double width = MediaQuery.of(context).size.width;
            final bool narrow = width < _narrowBreakpoint;
            if (narrow && !_wasNarrow) {
              _wasNarrow = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _sidebarOpen = false);
              });
            } else if (!narrow) {
              if (_wasNarrow) {
                _wasNarrow = false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _sidebarOpen = true);
                });
              }
            }

            Widget buildSidebar() => AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: _sidebarOpen ? 256 : 80,
              color: sidebarColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    height: 64,
                    color: sidebarHeaderColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => setState(
                            () => _sidebarOpen = !_sidebarOpen,
                          ),
                          icon: Icon(
                            _sidebarOpen
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            color: sidebarTextColor,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 280),
                            crossFadeState: _sidebarOpen
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Image.asset(
                                'assets/images/logo_horizontal.png',
                                fit: BoxFit.contain,
                                height: 36,
                              ),
                            ),
                            secondChild: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Image.asset(
                                'assets/images/logo_vertical.png',
                                fit: BoxFit.contain,
                                height: 36,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) {
                              final double sidebarWidth = constraints.maxWidth;
                              return ListView(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                children: <Widget>[
                                  if (!retired)
                                    _navBtn(
                                      context,
                                      id: 'dashboard',
                                      icon: Icons.dashboard_rounded,
                                      label: '대시보드',
                                      selected: menu == 'dashboard',
                                      expanded: _sidebarOpen,
                                      sidebarWidth: sidebarWidth,
                                      onTap: () => context.go('/'),
                                      sidebarTextColor: sidebarTextColor,
                                    ),
                                  _groupLabel('업무지원', sidebarTextColor, _sidebarOpen, sidebarWidth),
                              if (canAccessInsurance)
                                _navBtn(
                                  context,
                                  id: 'insurance',
                                  icon: Icons.health_and_safety_outlined,
                                  label: '4대보험 관리',
                                  selected: menu == 'insurance',
                                  expanded: _sidebarOpen,
                                  sidebarWidth: sidebarWidth,
                                  onTap: () => context.go('/insurance'),
                                  sidebarTextColor: sidebarTextColor,
                                ),
                              _navBtn(
                                context,
                                id: 'exchange',
                                icon: Icons.send_rounded,
                                label: '자료송수신',
                                selected: menu == 'exchange',
                                expanded: _sidebarOpen,
                                sidebarWidth: sidebarWidth,
                                onTap: () => context.go('/exchange'),
                                sidebarTextColor: sidebarTextColor,
                              ),
                              _navBtn(
                                context,
                                id: 'work-tools',
                                icon: Icons.handyman_rounded,
                                label: '업무 도구',
                                selected: menu == 'work-tools',
                                expanded: _sidebarOpen,
                                sidebarWidth: sidebarWidth,
                                onTap: () => context.go('/work-tools'),
                                sidebarTextColor: sidebarTextColor,
                              ),
                              _navBtn(
                                context,
                                id: 'company-info',
                                icon: Icons.business_outlined,
                                label: '회사정보',
                                selected: menu == 'company-info',
                                expanded: _sidebarOpen,
                                sidebarWidth: sidebarWidth,
                                onTap: () => context.go('/company-info'),
                                sidebarTextColor: sidebarTextColor,
                              ),
                              // 문화의 날 — 일반 메뉴 보류 (라우트 `/culture-day`·화면 코드는 유지)
                              // _navBtn(
                              //   context,
                              //   id: 'culture-day',
                              //   icon: Icons.confirmation_number_outlined,
                              //   label: '문화의 날 정보',
                              //   selected: menu == 'culture-day',
                              //   expanded: _sidebarOpen,
                              //   sidebarWidth: sidebarWidth,
                              //   onTap: () => context.go('/culture-day'),
                              //   sidebarTextColor: sidebarTextColor,
                              // ),
                                  if (!retired) ...<Widget>[
                                    _groupLabel('일정관리', sidebarTextColor, _sidebarOpen, sidebarWidth),
                                    _navBtn(
                                      context,
                                      id: 'calendar',
                                      icon: Icons.calendar_month_rounded,
                                      label: '업무 캘린더',
                                      selected: menu == 'calendar',
                                      expanded: _sidebarOpen,
                                      sidebarWidth: sidebarWidth,
                                      onTap: () => context.go('/calendar'),
                                      sidebarTextColor: sidebarTextColor,
                                    ),
                                    _navBtn(
                                      context,
                                      id: 'todo',
                                      icon: Icons.check_box_outlined,
                                      label: '해야할 일',
                                      selected: menu == 'todo',
                                      expanded: _sidebarOpen,
                                      sidebarWidth: sidebarWidth,
                                      onTap: () => context.go('/todo'),
                                      sidebarTextColor: sidebarTextColor,
                                    ),
                                    _groupLabel('커뮤니티', sidebarTextColor, _sidebarOpen, sidebarWidth),
                                    _navBtn(
                                      context,
                                      id: 'notice',
                                      icon: Icons.campaign_outlined,
                                      label: '공지사항',
                                      selected: menu == 'notice',
                                      expanded: _sidebarOpen,
                                      sidebarWidth: sidebarWidth,
                                      onTap: () => context.go('/notice'),
                                      sidebarTextColor: sidebarTextColor,
                                    ),
                                    _navBtn(
                                      context,
                                      id: 'freeboard',
                                      icon: Icons.forum_outlined,
                                      label: '자유게시판',
                                      selected: menu == 'freeboard',
                                      expanded: _sidebarOpen,
                                      sidebarWidth: sidebarWidth,
                                      onTap: () => context.go('/freeboard'),
                                      sidebarTextColor: sidebarTextColor,
                                    ),
                                    _navBtn(
                                      context,
                                      id: 'anonymous',
                                      icon: Icons.visibility_off_outlined,
                                      label: '익명게시판',
                                      selected: menu == 'anonymous',
                                      expanded: _sidebarOpen,
                                      sidebarWidth: sidebarWidth,
                                      onTap: () => context.go('/anonymous'),
                                      sidebarTextColor: sidebarTextColor,
                                    ),
                                  ],
                              _groupLabel('시스템', sidebarTextColor, _sidebarOpen, sidebarWidth),
                              _navBtn(
                                context,
                                id: 'my-settings',
                                icon: Icons.settings_outlined,
                                label: '앱 설정',
                                selected: menu == 'my-settings',
                                expanded: _sidebarOpen,
                                sidebarWidth: sidebarWidth,
                                onTap: () => context.go('/my-settings'),
                                sidebarTextColor: sidebarTextColor,
                              ),
                              if (!retired && mainAdmin) ...<Widget>[
                                _groupLabel('관리', sidebarTextColor, _sidebarOpen, sidebarWidth),
                                _navBtn(
                                  context,
                                  id: 'files',
                                  icon: Icons.folder_open_rounded,
                                  label: '파일 관리',
                                  selected: menu == 'files',
                                  expanded: _sidebarOpen,
                                  sidebarWidth: sidebarWidth,
                                  onTap: () => context.go('/files'),
                                  sidebarTextColor: sidebarTextColor,
                                ),
                                _navBtn(
                                  context,
                                  id: 'admin-settings',
                                  icon: Icons.admin_panel_settings_outlined,
                                  label: '관리자 설정',
                                  selected: menu == 'admin-settings',
                                  expanded: _sidebarOpen,
                                  sidebarWidth: sidebarWidth,
                                  onTap: () => context.go('/settings'),
                                  sidebarTextColor: sidebarTextColor,
                                ),
                              ],
                              _navBtn(
                                context,
                                id: 'profile',
                                icon: Icons.person_outline_rounded,
                                label: '개인설정 변경',
                                selected: menu == 'profile',
                                expanded: _sidebarOpen,
                                sidebarWidth: sidebarWidth,
                                onTap: () => context.go('/profile'),
                                sidebarTextColor: sidebarTextColor,
                              ),
                            ],
                          );
                            },
                          ),
                        ),
                        _sidebarFooter(
                          context,
                          expanded: _sidebarOpen,
                          name: name,
                          position: position,
                          branch: branch,
                          photoUrl: photoUrl,
                          profileRef: profileRef,
                          sidebarColor: sidebarColor,
                          sidebarTextColor: sidebarTextColor,
                        ),
                      ],
                    ),
                  );

        Widget buildMainContent({Widget? resolvedChild}) {
          final String? parentRoute = shellParentRoute(path);
          return Column(
          children: <Widget>[
                        Material(
                          elevation: 1,
                          color: Colors.white,
                          child: SizedBox(
                            height: 64,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: <Widget>[
                                  if (parentRoute != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _ShellBackChip(
                                        onPressed: () =>
                                            context.go(parentRoute),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      _portalTitle(menu, path),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: primaryColor,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  // FilledButton.tonalIcon(
                                  //   onPressed: () =>
                                  //       setState(() => _aiOpen = true),
                                  //   icon: const Icon(Icons.auto_awesome, size: 18),
                                  //   label: const Text('AI Assistant'),
                                  //   style: FilledButton.styleFrom(
                                  //     foregroundColor: primaryColor,
                                  //     backgroundColor: primaryColor.withOpacity(0.1),
                                  //   ),
                                  // ),
                                  // const SizedBox(width: 12),
                                  StreamBuilder<int>(
                                    stream: _repo.watchUnreadConversationCount(),
                                    builder: (
                                      BuildContext context,
                                      AsyncSnapshot<int> c,
                                    ) {
                                      if (c.hasError) {
                                        // 스트림 실패 시에도 메신저 버튼은 유지 (미읽음 0으로 표시)
                                        return IconButton(
                                          tooltip: '메신저',
                                          onPressed: () =>
                                              context.read<MessengerDockController>().open(),
                                          icon: const Icon(
                                            Icons.chat_bubble_outline_rounded,
                                          ),
                                        );
                                      }
                                      final int n = c.data ?? 0;
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: <Widget>[
                                          IconButton(
                                            tooltip: '메신저',
                                            onPressed: () =>
                                                context.read<MessengerDockController>().open(),
                                            icon: const Icon(
                                              Icons.chat_bubble_outline_rounded,
                                            ),
                                          ),
                                          if (n > 0)
                                            Positioned(
                                              right: 6,
                                              top: 6,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                  minWidth: 18,
                                                  minHeight: 18,
                                                ),
                                                child: Text(
                                                  n > 9 ? '9+' : '$n',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                  IconButton(
                                    tooltip: '알림',
                                    onPressed: () => context.read<NotificationsDockController>().toggle(),
                                    icon: StreamBuilder<int>(
                                      stream: _repo.watchUnreadNotificationCount(),
                                      builder: (
                                        BuildContext context,
                                        AsyncSnapshot<int> s,
                                      ) {
                                        final int n = s.data ?? 0;
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: <Widget>[
                                            const Icon(Icons.notifications_none),
                                            if (n > 0)
                                              Positioned(
                                                right: -2,
                                                top: -2,
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  constraints: const BoxConstraints(
                                                    minWidth: 18,
                                                    minHeight: 18,
                                                  ),
                                                  child: Text(
                                                    n > 9 ? '9+' : '$n',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: <Color>[
                                  Color.lerp(bgColor, Colors.white, 0.1)!,
                                  bgColor,
                                  Color.lerp(bgColor, Colors.white, 0.02)!,
                                  bgColor,
                                  Color.lerp(bgColor, Colors.white, 0.1)!,
                                ],
                                stops: const <double>[0.0, 0.12, 0.5, 0.88, 1.0],
                              ),
                            ),
                            child: resolvedChild ?? widget.child,
                          ),
                        ),
          ],
        );
        }

        final bool isInsurancePath = path.startsWith('/insurance');
        final Widget resolvedChild = isInsurancePath && !canAccessInsurance
            ? _buildAccessDeniedPlaceholder(context, primaryColor)
            : widget.child;

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: <Widget>[
              if (narrow)
                Stack(
                  children: <Widget>[
                    Positioned(
                      left: _sidebarOpen ? 0 : 80,
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: buildMainContent(resolvedChild: resolvedChild),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Material(
                        elevation: _sidebarOpen ? 16 : 0,
                        child: buildSidebar(),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    buildSidebar(),
                    Expanded(child: buildMainContent(resolvedChild: resolvedChild)),
                  ],
                ),
              Consumer<MessengerDockController>(
                builder: (BuildContext context, MessengerDockController dock, _) {
                  if (!dock.isOpen) return const SizedBox.shrink();
                  return MessengerOverlay(
                    onClose: () => dock.close(),
                    primaryColor: primaryColor,
                  );
                },
              ),
              NotificationsOverlay(primaryColor: primaryColor),
              // if (_aiOpen)
              //   _AiOverlay(
              //     onClose: () => setState(() => _aiOpen = false),
              //     gemini: _gemini,
              //     primaryColor: primaryColor,
              //   ),
            ],
          ),
        );
      },
    );
      },
    );
  }

  Widget _buildAccessDeniedPlaceholder(BuildContext context, Color primaryColor) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.block, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                '4대보험 관리 메뉴에 대한 접근 권한이 없습니다.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('대시보드로 이동'),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _groupLabelHeight = 34.0;
  static const EdgeInsets _groupLabelPadding = EdgeInsets.fromLTRB(12, 14, 12, 6);

  Widget _groupLabel(String text, Color sidebarTextColor, bool expanded, double sidebarWidth) {
    final Widget content = SizedBox(
      height: _groupLabelHeight,
      child: Padding(
        padding: _groupLabelPadding,
        child: expanded
            ? _buildGroupLabelExpanded(text, sidebarTextColor, sidebarWidth)
            : _buildGroupLabelCollapsed(text, sidebarTextColor),
      ),
    );
    return expanded ? content : Tooltip(message: text, child: content);
  }

  Widget _buildGroupLabelExpanded(String text, Color sidebarTextColor, double sidebarWidth) {
    final double textOpacity = sidebarWidth > 160
        ? ((sidebarWidth - 160) / 60).clamp(0.0, 1.0)
        : 0.0;
    return Opacity(
      opacity: textOpacity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: sidebarTextColor.withOpacity(0.35),
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupLabelCollapsed(String text, Color sidebarTextColor) {
    return Center(
      child: Divider(
        height: 1,
        thickness: 1,
        color: sidebarTextColor.withOpacity(0.2),
      ),
    );
  }

  Widget _navBtn(
    BuildContext context, {
    required String id,
    required IconData icon,
    required String label,
    required bool selected,
    required bool expanded,
    required double sidebarWidth,
    required VoidCallback onTap,
    required Color sidebarTextColor,
  }) {
    final double textOpacity = expanded && sidebarWidth > 160
        ? ((sidebarWidth - 160) / 60).clamp(0.0, 1.0)
        : 0.0;
    final Widget button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected
            ? sidebarTextColor.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? sidebarTextColor : sidebarTextColor.withOpacity(0.7),
                ),
                if (expanded) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: textOpacity,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? sidebarTextColor : sidebarTextColor.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return expanded ? button : Tooltip(message: label, child: button);
  }

  Widget _sidebarFooter(
    BuildContext context, {
    required bool expanded,
    required String name,
    required String position,
    required String branch,
    required String? photoUrl,
    required DocumentReference<Map<String, dynamic>>? profileRef,
    required Color sidebarColor,
    required Color sidebarTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.lerp(sidebarColor, Colors.black, 0.15)?.withOpacity(0.45) ?? sidebarColor.withOpacity(0.45),
        border: Border(
          top: BorderSide(color: sidebarTextColor.withOpacity(0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppUserAvatar(
                    size: expanded ? 36 : 24,
                    photoUrl: photoUrl,
                    fallbackText: name,
                    backgroundColor: sidebarTextColor.withOpacity(0.35),
                    foregroundColor: sidebarTextColor,
                  ),
                  if (expanded) ...<Widget>[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            position.trim().isEmpty ? ' ' : position.trim(),
                            style: TextStyle(
                              color: sidebarTextColor.withOpacity(0.65),
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            name.trim().isEmpty ? '사용자' : name.trim(),
                            style: TextStyle(
                              color: sidebarTextColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              height: 1.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            branch,
                            style: TextStyle(
                              color: sidebarTextColor.withOpacity(0.45),
                              fontSize: 10.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상단 흰 바 좌측: 반투명 원 + 뒤로 (세부 → 상위 허브/목록)
class _ShellBackChip extends StatelessWidget {
  const _ShellBackChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.07),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 15,
            color: Colors.black.withOpacity(0.55),
          ),
        ),
      ),
    );
  }
}

/*
class _AiOverlay extends StatefulWidget {
  const _AiOverlay({required this.onClose, required this.gemini, required this.primaryColor});

  final VoidCallback onClose;
  final GeminiChatService gemini;
  final Color primaryColor;

  @override
  State<_AiOverlay> createState() => _AiOverlayState();
}

class _AiOverlayState extends State<_AiOverlay> {
  final List<_ChatMsg> _msgs = <_ChatMsg>[
    _ChatMsg(
      false,
      '반갑습니다! hnde-work AI 비서입니다. 무엇을 도와드릴까요?',
    ),
  ];
  final TextEditingController _input = TextEditingController();
  bool _typing = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String t = _input.text.trim();
    if (t.isEmpty || _typing) {
      return;
    }
    setState(() {
      _msgs.add(_ChatMsg(true, t));
      _input.clear();
      _typing = true;
    });
    final String reply = await widget.gemini.generateReply(t);
    if (!mounted) {
      return;
    }
    setState(() {
      _msgs.add(_ChatMsg(false, reply));
      _typing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black45),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 400,
          child: Material(
            elevation: 16,
            child: Column(
              children: <Widget>[
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        widget.primaryColor,
                        Color.lerp(widget.primaryColor, Colors.black, 0.2)!,
                      ],
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.psychology_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Work AI Agent',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _msgs.length + (_typing ? 1 : 0),
                    itemBuilder: (BuildContext context, int i) {
                      if (_typing && i == _msgs.length) {
                        return const ListTile(
                          leading: SizedBox(
                            width: 24,
                            height: 24,
                            child: LoadingWidget(size: 20, duration: Duration(milliseconds: 1000)),
                          ),
                          title: Text('응답 생성 중…'),
                        );
                      }
                      final _ChatMsg m = _msgs[i];
                      return Align(
                        alignment: m.user
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: m.user ? widget.primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: m.user
                                  ? widget.primaryColor
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Text(
                            m.text,
                            style: TextStyle(
                              color: m.user ? Colors.white : Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _input,
                          decoration: const InputDecoration(
                            hintText: '무엇이든 물어보세요…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _typing ? null : _send,
                        child: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _msgs
                          ..clear()
                          ..add(
                            _ChatMsg(
                              false,
                              '채팅을 초기화했습니다.',
                            ),
                          );
                      });
                    },
                    child: const Text('Reset Chat'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMsg {
  _ChatMsg(this.user, this.text);
  final bool user;
  final String text;
}
*/
