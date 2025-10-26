import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationCenter extends StatelessWidget {
  final int weeklyNoticesCount;
  final int weeklyBoardsCount;
  final int unsubmittedDataRequestsCount;

  const NotificationCenter({
    super.key,
    required this.weeklyNoticesCount,
    required this.weeklyBoardsCount,
    required this.unsubmittedDataRequestsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade50, Colors.purple.shade100],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.purple.shade600, size: 24),
                const SizedBox(width: 8),
                Text(
                  '알림센터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNotificationItem('새 공지사항', '${weeklyNoticesCount}개', Colors.red, () => context.go('/notices')),
            _buildNotificationItem('새 게시물', '${weeklyBoardsCount}개', Colors.blue, () => context.go('/boards')),
            _buildNotificationItem('자료요청', '${unsubmittedDataRequestsCount}개', Colors.green, () => context.go('/data-requests')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 전체 알림 페이지로 이동
                },
                icon: const Icon(Icons.list, size: 16),
                label: const Text('전체 알림 보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String count, Color color, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: onTap != null ? Colors.purple.shade50.withOpacity(0.3) : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.purple.shade600,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
