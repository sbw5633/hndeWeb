import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth_provider.dart';
import '../../../services/firebase/comment_service.dart';

class CommentInput extends StatefulWidget {
  final String postId;
  final String? parentId;
  final String? parentAuthorName;
  final VoidCallback? onCommentAdded;

  const CommentInput({
    super.key,
    required this.postId,
    this.parentId,
    this.parentAuthorName,
    this.onCommentAdded,
  });

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_controller.text.trim().isEmpty || _isSubmitting) return;

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.appUser;
    if (user == null) {
      print('=== 댓글 작성 실패: 사용자가 로그인되지 않음 ===');
      return;
    }

    print('=== 댓글 작성 시작 ===');
    print('postId: ${widget.postId}');
    print('parentId: ${widget.parentId}');
    print('authorId: ${user.uid}');
    print('authorName: ${user.name}');
    print('content: ${_controller.text.trim()}');

    setState(() {
      _isSubmitting = true;
    });

    try {
      final comment = await CommentService.createComment(
        postId: widget.postId,
        parentId: widget.parentId,
        authorId: user.uid,
        authorName: user.name,
        content: _controller.text.trim(),
      );

      print('=== 댓글 작성 성공 ===');
      print('생성된 댓글 ID: ${comment.id}');

      _controller.clear();
      _focusNode.unfocus();
      widget.onCommentAdded?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('댓글이 등록되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('=== 댓글 작성 실패 ===');
      print('오류: $e');
      print('오류 타입: ${e.runtimeType}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 등록에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 대댓글인 경우 부모 댓글 표시
          if (widget.parentId != null && widget.parentAuthorName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.parentAuthorName}님에게 답글',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 댓글 입력 필드
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  minLines: 1,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: widget.parentId != null 
                        ? '답글을 입력해주세요...' 
                        : '댓글을 입력해주세요...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    counterText: '${_controller.text.length}/500',
                  ),
                  onChanged: (value) {
                    setState(() {}); // 카운터 업데이트
                  },
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('등록'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
