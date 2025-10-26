import 'package:flutter/material.dart';
import '../../../models/board_post_model.dart';
import '../../components/common/post_stats_widget.dart';
import '../../components/common/like_button.dart';

class PostActions extends StatelessWidget {
  final BoardPost post;

  const PostActions({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // 좋아요 버튼 (클릭 가능)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: LikeButton(
              postId: post.id,
              iconSize: 16,
              fontSize: 14,
              likedColor: Colors.red.shade600,
              unlikedColor: Colors.grey.shade600,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 16),
          
          // 통합 통계 위젯 (댓글수만)
          PostStatsWidget(
            postId: post.id,
            showComments: true,
            showLikes: false, // 좋아요는 위에서 별도 처리
            showViews: false, // 조회수 제거
            iconSize: 16,
            fontSize: 14,
            iconColor: Colors.grey.shade600,
            textColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: MainAxisAlignment.start,
          ),
        ],
      ),
    );
  }
}
