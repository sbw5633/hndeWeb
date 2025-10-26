import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth_provider.dart';
import '../../../services/firebase/post_stats_service.dart';

class LikeButton extends StatefulWidget {
  final String postId;
  final double iconSize;
  final double fontSize;
  final Color? likedColor;
  final Color? unlikedColor;
  final EdgeInsets? padding;

  const LikeButton({
    super.key,
    required this.postId,
    this.iconSize = 14,
    this.fontSize = 12,
    this.likedColor,
    this.unlikedColor,
    this.padding,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _isLiking = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.appUser;
    
    if (currentUser == null) {
      // 로그인하지 않은 경우 좋아요 수만 표시
      return StreamBuilder<int>(
        stream: PostStatsService.getLikeCountStream(widget.postId),
        builder: (context, snapshot) {
          final likeCount = snapshot.data ?? 0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_outline,
                size: widget.iconSize,
                color: widget.unlikedColor ?? Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                '$likeCount',
                style: TextStyle(
                  fontSize: widget.fontSize,
                  color: widget.unlikedColor ?? Colors.grey.shade600,
                ),
              ),
            ],
          );
        },
      );
    }

    return StreamBuilder<int>(
      stream: PostStatsService.getLikeCountStream(widget.postId),
      builder: (context, snapshot) {
        final likeCount = snapshot.data ?? 0;
        
        return StreamBuilder<bool>(
          stream: PostStatsService.getLikeStatusStream(widget.postId, currentUser.uid),
          builder: (context, statusSnapshot) {
            final isLiked = statusSnapshot.data ?? false;
            
            return InkWell(
              onTap: _isLiking ? null : () => _toggleLike(isLiked),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLiking)
                      SizedBox(
                        width: widget.iconSize,
                        height: widget.iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isLiked 
                                ? (widget.likedColor ?? Colors.red.shade600)
                                : (widget.unlikedColor ?? Colors.grey.shade500),
                          ),
                        ),
                      )
                    else
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_outline,
                        size: widget.iconSize,
                        color: isLiked 
                            ? (widget.likedColor ?? Colors.red.shade600)
                            : (widget.unlikedColor ?? Colors.grey.shade500),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      '$likeCount',
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        color: isLiked 
                            ? (widget.likedColor ?? Colors.red.shade600)
                            : (widget.unlikedColor ?? Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleLike(bool isLiked) async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.appUser;
    if (currentUser == null) return;

    setState(() {
      _isLiking = true;
    });

    try {
      await PostStatsService.toggleLike(
        postId: widget.postId,
        userId: currentUser.uid,
        isLiked: !isLiked,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('좋아요 처리에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }
}
