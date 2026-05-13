import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification_model.dart';
import '../../repositories/work_firestore_repository.dart';
import 'notifications_dock_controller.dart';

class NotificationsOverlay extends StatelessWidget {
  const NotificationsOverlay({super.key, required this.primaryColor});

  final Color primaryColor;

  void _navigateFromNotif(BuildContext context, AppNotificationModel n) {
    final Map<String, dynamic> p = n.payload;
    switch (n.type) {
      case 'notice_created':
      case 'post_commented': {
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
      case 'submission_created':
      case 'submission_due_soon': {
        final String id = (p['submissionId'] as String?)?.trim() ?? '';
        if (id.isNotEmpty) {
          context.go('/exchange/$id');
        } else {
          context.go('/exchange');
        }
        return;
      }
      case 'calendar_event_created': {
        context.go('/calendar');
        return;
      }
      case 'branch_change_decided': {
        context.go('/profile');
        return;
      }
      default:
        // fallback
        context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Consumer<NotificationsDockController>(
          builder: (BuildContext context, NotificationsDockController dock, _) {
            if (!dock.isOpen) return const SizedBox.shrink();

            final double w = dock.dockWidth.clamp(300.0, constraints.maxWidth);

            final Widget panel = Material(
              elevation: 18,
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: primaryColor,
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.notifications, color: Colors.white),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '알림',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => repo.markAllNotificationsRead(),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text('모두 읽음', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => repo.hideReadNotifications(),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text(
                            '확인한 알림 삭제',
                            style: TextStyle(fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () {
                            repo.markAllNotificationsRead();
                            dock.close();
                          },
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<AppNotificationModel>>(
                      stream: repo.watchMyNotifications(limit: 120),
                      builder: (BuildContext context, AsyncSnapshot<List<AppNotificationModel>> snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: SelectableText('알림을 불러오지 못했습니다.\n${snap.error}'),
                            ),
                          );
                        }
                        final List<AppNotificationModel> list = snap.data ?? <AppNotificationModel>[];
                        if (list.isEmpty) {
                          return const Center(child: Text('알림이 없습니다.'));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (BuildContext context, int i) {
                            final AppNotificationModel n = list[i];
                            final bool unread = !n.isRead;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                unread ? Icons.circle : Icons.circle_outlined,
                                size: 12,
                                color: unread ? primaryColor : const Color(0xFF94A3B8),
                              ),
                              title: Text(
                                n.title.isEmpty ? '알림' : n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: '삭제',
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                                onPressed: () async => repo.hideNotification(n.id),
                              ),
                              onTap: () async {
                                await repo.markNotificationRead(n.id);
                                if (!context.mounted) return;
                                _navigateFromNotif(context, n);
                                context.read<NotificationsDockController>().close();
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );

            return SizedBox.expand(
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: w,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(child: panel),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 10,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (DragUpdateDetails d) {
                                dock.setDockWidth(dock.dockWidth - d.delta.dx, constraints);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

