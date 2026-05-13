import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/company/company_info_hub_page.dart';
import '../features/company/company_info_page.dart';
import '../features/pdf/pdf_toolkit_models.dart';
import '../features/work_tools/file_batch_rename_page.dart';
import '../features/work_tools/image_collage_page.dart';
import '../features/work_tools/image_compress_page.dart';
import '../features/work_tools/image_edit_page.dart';
import '../features/work_tools/work_tools_hub_page.dart';
import '../features/board/board_compose_page.dart';
import '../features/board/board_detail_page.dart';
import '../features/board/board_list_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/culture_day/culture_detail_page.dart';
import '../features/culture_day/culture_list_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/exchange/exchange_detail_page.dart';
import '../features/exchange/exchange_list_page.dart';
import '../features/exchange/exchange_request_page.dart';
import '../features/files/file_management_screen.dart';
import '../features/insurance/daily_worker_page.dart';
import '../features/insurance/insurance_hub_page.dart';
import '../features/insurance/insurance_search_page.dart';
import '../features/insurance/insurance_status_page.dart';
import '../features/pdf/pdf_toolkit_page.dart';
import '../features/profile/work_profile_page.dart';
import '../features/settings/admin_settings_page.dart';
import '../features/settings/settings_page.dart';
import '../features/messenger/chat_room_page.dart';
import '../features/shell/work_app_shell.dart';
import '../features/todo/todo_list_page.dart';

String _initialLocationFromUrl() {
  // 웹에서 `/#/chat/xxx` 같은 해시 라우팅을 새창으로 열면,
  // Cold start 시점엔 `Uri.base.path`는 `/`이고 실제 경로는 `fragment`에 들어갑니다.
  final String frag = Uri.base.fragment;
  if (frag.startsWith('/')) {
    return frag;
  }
  final String p = Uri.base.path;
  if (p.isNotEmpty) {
    return p;
  }
  return '/';
}

GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: _initialLocationFromUrl(),
    redirect: (BuildContext context, GoRouterState state) {
      final String p = state.uri.path;
      if (p == '/pdf-tool') {
        return '/work-tools';
      }
      if (p == '/pdf-merge') {
        return '/work-tools/pdf-merge';
      }
      if (p == '/pdf-split') {
        return '/work-tools/pdf-split';
      }
      if (p == '/file-rename') {
        return '/work-tools/file-rename';
      }
      if (p == '/image-edit') {
        return '/work-tools/image-edit';
      }
      if (p == '/image-collage') {
        return '/work-tools/image-collage';
      }
      if (p == '/image-compress') {
        return '/work-tools/image-compress';
      }
      return null;
    },
    routes: <RouteBase>[
      // 채팅 전용 화면: 셸(좌측바/상단바) 없이 깔끔하게 렌더링
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String id = state.pathParameters['id'] ?? '';
          return _page(
            state.pageKey,
            ChatRoomPage(
              conversationId: id,
              standalone: true,
            ),
          );
        },
      ),
      ShellRoute(
        builder: (
          BuildContext context,
          GoRouterState state,
          Widget child,
        ) {
          return WorkAppShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const DashboardPage());
            },
          ),
          GoRoute(
            path: '/todo',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const TodoListPage());
            },
          ),
          GoRoute(
            path: '/insurance',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const InsuranceHubPage());
            },
          ),
          GoRoute(
            path: '/insurance/status',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const InsuranceStatusPage());
            },
          ),
          GoRoute(
            path: '/insurance/search',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const InsuranceSearchPage());
            },
          ),
          GoRoute(
            path: '/insurance/daily',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const DailyWorkerPage());
            },
          ),
          GoRoute(
            path: '/exchange',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const ExchangeListPage());
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'create',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return _page(
                    state.pageKey,
                    const ExchangeRequestPage(),
                  );
                },
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  final String id = state.pathParameters['id'] ?? '';
                  return _page(
                    state.pageKey,
                    ExchangeDetailPage(submissionId: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/work-tools/pdf-merge',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(
                state.pageKey,
                const PdfToolkitPage(tool: PdfToolkitTool.merge),
              );
            },
          ),
          GoRoute(
            path: '/work-tools/pdf-split',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(
                state.pageKey,
                const PdfToolkitPage(tool: PdfToolkitTool.split),
              );
            },
          ),
          GoRoute(
            path: '/work-tools/file-rename',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const FileBatchRenamePage());
            },
          ),
          GoRoute(
            path: '/work-tools/image-edit',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const ImageEditPage());
            },
          ),
          GoRoute(
            path: '/work-tools/image-collage',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const ImageCollagePage());
            },
          ),
          GoRoute(
            path: '/work-tools/image-compress',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const ImageCompressPage());
            },
          ),
          GoRoute(
            path: '/work-tools',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const WorkToolsHubPage());
            },
          ),
          GoRoute(
            path: '/company-info',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const CompanyInfoHubPage());
            },
          ),
          GoRoute(
            path: '/company-org',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const OrganizationChartPage());
            },
          ),
          GoRoute(
            path: '/company-rules',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const CompanyRulesPage());
            },
          ),
          GoRoute(
            path: '/culture-day',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const CultureListPage());
            },
          ),
          GoRoute(
            path: '/culture-day/detail/:contentId',
            pageBuilder: (BuildContext context, GoRouterState state) {
              final String id = state.pathParameters['contentId']!;
              // 이전 구현 호환: CultureSpot 또는 TourItem
              final Object? extra = state.extra;
              return _page(
                state.pageKey,
                CultureDetailPage(
                  contentId: Uri.decodeComponent(id),
                  monthKey: state.uri.queryParameters['month'],
                  preview: extra,
                ),
              );
            },
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const CalendarPage());
            },
          ),
          GoRoute(
            path: '/notice',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(
                state.pageKey,
                const BoardListPage(
                  boardType: 'notice',
                  title: '전사 공지사항',
                ),
              );
            },
          ),
          GoRoute(
            path: '/freeboard',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(
                state.pageKey,
                const BoardListPage(
                  boardType: 'freeboard',
                  title: '자유게시판',
                ),
              );
            },
          ),
          GoRoute(
            path: '/anonymous',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(
                state.pageKey,
                const BoardListPage(
                  boardType: 'anonymous',
                  title: '익명게시판',
                ),
              );
            },
          ),
          GoRoute(
            path: '/board/:boardType/write',
            pageBuilder: (BuildContext context, GoRouterState state) {
              final String boardType =
                  state.pathParameters['boardType'] ?? '';
              return _page(
                state.pageKey,
                BoardComposePage(boardType: boardType),
              );
            },
          ),
          GoRoute(
            path: '/board/:boardType/:postId',
            pageBuilder: (BuildContext context, GoRouterState state) {
              final String boardType = state.pathParameters['boardType'] ?? '';
              final String postId = state.pathParameters['postId'] ?? '';
              return _page(
                state.pageKey,
                BoardDetailPage(boardType: boardType, postId: postId),
              );
            },
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const WorkProfilePage());
            },
          ),
          GoRoute(
            path: '/files',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const FileManagementScreen());
            },
          ),
          GoRoute(
            path: '/my-settings',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const SettingsPage());
            },
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (BuildContext context, GoRouterState state) {
              return _page(state.pageKey, const AdminSettingsPage());
            },
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage<void> _page(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<double> fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      final Animation<Offset> slide = Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuad));

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}
