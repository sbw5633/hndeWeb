import 'package:flutter/material.dart';
import '../../../models/board_post_model.dart';
import '../../../const_value.dart';

class PostHeader extends StatelessWidget {
  final BoardPost post;
  final MenuType type;

  const PostHeader({
    super.key,
    required this.post,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isAnonymous = post.anonymity;
    final authorName = isAnonymous ? '익명' : post.authorName;
    final createdAt = post.createdAt;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타입 아이콘과 제목
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 작성자 정보
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  color: Colors.white.withOpacity(0.9),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  authorName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  color: Colors.white.withOpacity(0.9),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (type) {
      case MenuType.notice:
        return [Colors.blue.shade600, Colors.blue.shade800];
      case MenuType.dataRequest:
        return [Colors.green.shade600, Colors.green.shade800];
      case MenuType.board:
        return [Colors.purple.shade600, Colors.purple.shade800];
      case MenuType.anonymousBoard:
        return [Colors.orange.shade600, Colors.orange.shade800];
      default:
        return [Colors.grey.shade600, Colors.grey.shade800];
    }
  }

  IconData _getTypeIcon() {
    switch (type) {
      case MenuType.notice:
        return Icons.announcement;
      case MenuType.dataRequest:
        return Icons.file_present;
      case MenuType.board:
        return Icons.forum;
      case MenuType.anonymousBoard:
        return Icons.chat;
      default:
        return Icons.article;
    }
  }
}
