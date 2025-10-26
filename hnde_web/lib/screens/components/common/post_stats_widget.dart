import 'package:flutter/material.dart';
import '../../../services/firebase/post_stats_service.dart';
import 'like_button.dart';

class PostStatsWidget extends StatelessWidget {
  final String postId;
  final bool showComments;
  final bool showLikes;
  final bool showViews;
  final int? views; // 조회수는 게시물 데이터에서 가져옴
  final double iconSize;
  final double fontSize;
  final Color? iconColor;
  final Color? textColor;
  final EdgeInsets? padding;
  final MainAxisAlignment alignment;

  const PostStatsWidget({
    super.key,
    required this.postId,
    this.showComments = true,
    this.showLikes = true,
    this.showViews = false,
    this.views,
    this.iconSize = 14,
    this.fontSize = 12,
    this.iconColor,
    this.textColor,
    this.padding,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final defaultIconColor = iconColor ?? Colors.grey.shade500;
    final defaultTextColor = textColor ?? Colors.grey.shade600;
    final defaultPadding = padding ?? const EdgeInsets.symmetric(horizontal: 4);

    return Row(
      mainAxisAlignment: alignment,
      children: [
        

        // 좋아요수 (단순 표시만)
        if (showLikes) ...[
          StreamBuilder<int>(
            stream: PostStatsService.getLikeCountStream(postId),
            builder: (context, snapshot) {
              final likeCount = snapshot.data ?? 0;
              return Padding(
                padding: defaultPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_outline,
                      size: iconSize,
                      color: defaultIconColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$likeCount',
                      style: TextStyle(
                        fontSize: fontSize,
                        color: defaultTextColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // 댓글수
        if (showComments) ...[
          StreamBuilder<int>(
            stream: PostStatsService.getCommentCountStream(postId),
            builder: (context, snapshot) {
              final commentCount = snapshot.data ?? 0;
              return Padding(
                padding: defaultPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: iconSize,
                      color: defaultIconColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$commentCount',
                      style: TextStyle(
                        fontSize: fontSize,
                        color: defaultTextColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // 조회수 (게시물 데이터에서 가져옴)
        if (showViews && views != null) ...[
          Padding(
            padding: defaultPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: iconSize,
                  color: defaultIconColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '$views',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: defaultTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
