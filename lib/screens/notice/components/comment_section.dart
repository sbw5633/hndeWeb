import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth_provider.dart';
import '../../../models/comment_model.dart';
import '../../../services/firebase/comment_service.dart';
import 'comment_input.dart';
import 'comment_item.dart';

class CommentSection extends StatefulWidget {
  final String postId;

  const CommentSection({
    super.key,
    required this.postId,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  String? _replyingToCommentId;
  String? _replyingToAuthorName;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.appUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 댓글 섹션 헤더
          Row(
            children: [
              Icon(
                Icons.comment,
                color: Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '댓글',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 댓글 입력 (로그인한 사용자만)
          if (currentUser != null) ...[
            CommentInput(
              postId: widget.postId,
              parentId: _replyingToCommentId,
              parentAuthorName: _replyingToAuthorName,
              onCommentAdded: () {
                setState(() {
                  _replyingToCommentId = null;
                  _replyingToAuthorName = null;
                });
              },
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '댓글을 작성하려면 로그인이 필요합니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 댓글 목록
          StreamBuilder<List<Comment>>(
            stream: CommentService.getCommentsStream(widget.postId),
            builder: (context, snapshot) {
              print('=== CommentSection StreamBuilder ===');
              print('postId: ${widget.postId}');
              print('connectionState: ${snapshot.connectionState}');
              print('hasError: ${snapshot.hasError}');
              print('error: ${snapshot.error}');
              print('hasData: ${snapshot.hasData}');
              print('data length: ${snapshot.data?.length ?? 0}');

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                print('=== 댓글 로드 에러 ===');
                print('에러: ${snapshot.error}');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '댓글을 불러오지 못했습니다.\n${snapshot.error}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final comments = snapshot.data ?? [];
              print('=== 댓글 목록 ===');
              for (int i = 0; i < comments.length; i++) {
                print('댓글 $i: ${comments[i].id} - ${comments[i].content}');
              }
              
              if (comments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '아직 댓글이 없습니다.\n첫 번째 댓글을 작성해보세요!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 댓글과 대댓글을 계층 구조로 정리
              final parentComments = comments.where((c) => c.parentId == null).toList();
              final childComments = comments.where((c) => c.parentId != null).toList();

              return Column(
                children: [
                  ...parentComments.map((parentComment) {
                    final replies = childComments
                        .where((c) => c.parentId == parentComment.id)
                        .toList();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            spreadRadius: 1,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 부모 댓글
                          CommentItem(
                            comment: parentComment,
                            onReply: () {
                              setState(() {
                                _replyingToCommentId = parentComment.id;
                                _replyingToAuthorName = parentComment.isAnonymous 
                                    ? '익명' 
                                    : parentComment.authorName;
                              });
                            },
                            onCommentUpdated: () {
                              setState(() {});
                            },
                          ),
                          
                          // 대댓글들 (부모 댓글 카드 안에 통합)
                          if (replies.isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  ...replies.map((reply) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: CommentItem(
                                      comment: reply,
                                      onCommentUpdated: () {
                                        setState(() {});
                                      },
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
