import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth_provider.dart';
import '../../../models/comment_model.dart';
import '../../../services/firebase/comment_service.dart';

class CommentItem extends StatefulWidget {
  final Comment comment;
  final VoidCallback? onReply;
  final VoidCallback? onCommentUpdated;

  const CommentItem({
    super.key,
    required this.comment,
    this.onReply,
    this.onCommentUpdated,
  });

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool _isLiking = false;
  bool _showReplyInput = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.appUser;
    final isOwner = currentUser?.uid == widget.comment.authorId;
    final isLiked = currentUser != null && widget.comment.likes.contains(currentUser.uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // 댓글 헤더 (작성자, 시간, 액션 버튼)
          Row(
            children: [
              // 작성자 정보
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 10,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      widget.comment.isAnonymous ? '익명' : widget.comment.authorName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // 작성 시간
              Text(
                _formatDateTime(widget.comment.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              const Spacer(),
              
              // 액션 버튼들
              if (isOwner) ...[
                _buildActionButton(
                  icon: Icons.edit,
                  onTap: _showEditDialog,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete,
                  onTap: _showDeleteDialog,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          
          // 댓글 내용
          Text(
            widget.comment.content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          
          // 하단 액션 (좋아요, 답글)
          Row(
            children: [
              // 좋아요 버튼
              InkWell(
                onTap: currentUser != null ? _toggleLike : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLiked ? Colors.red.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLiked ? Colors.red.shade200 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 14,
                        color: isLiked ? Colors.red.shade600 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.comment.likes.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isLiked ? Colors.red.shade600 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // 답글 버튼 (대댓글이 아닌 경우만)
              if (widget.comment.parentId == null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _showReplyInput = !_showReplyInput;
                    });
                    widget.onReply?.call();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.reply,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '답글',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(
          icon,
          size: 14,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.appUser;
    if (currentUser == null) return;

    final isLiked = widget.comment.likes.contains(currentUser.uid);

    setState(() {
      _isLiking = true;
    });

    try {
      await CommentService.toggleLike(
        commentId: widget.comment.id,
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

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.comment.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: '수정할 내용을 입력해주세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              try {
                await CommentService.updateComment(
                  commentId: widget.comment.id,
                  content: controller.text.trim(),
                );
                Navigator.of(context).pop();
                widget.onCommentUpdated?.call();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('댓글 수정에 실패했습니다: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('정말로 이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await CommentService.deleteComment(widget.comment.id);
                Navigator.of(context).pop();
                widget.onCommentUpdated?.call();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('댓글 삭제에 실패했습니다: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
