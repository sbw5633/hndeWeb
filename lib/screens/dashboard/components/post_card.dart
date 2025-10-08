import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth_provider.dart';
import '../../../models/board_post_model.dart';
import '../../../const_value.dart';

class PostCard extends StatelessWidget {
  final BoardPost post;
  final bool isDataRequest;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.isDataRequest,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.appUser;
    final userAffiliation = currentUser?.affiliation ?? '';
    
    // 자료요청 전용 정보
    String submissionStatus = '';
    String deadlineText = '';
    
    if (isDataRequest) {
      // 제출 상태 확인
      final selectedBranches = post.extra['selectedBranches'] as List<dynamic>? ?? [];
      final isTargetBranch = selectedBranches.contains(userAffiliation);
      final responses = post.responses;
      final userResponse = responses[userAffiliation] as Map<String, dynamic>?;
      final isSubmitted = userResponse != null && userResponse['submittedAt'] != null;
      
      if (isTargetBranch) {
        submissionStatus = isSubmitted ? '제출완료' : '제출전';
      }
      
      // 제출기한 확인
      final deadline = post.extra['deadline'] as String?;
      if (deadline != null && deadline.isNotEmpty) {
        try {
          final deadlineDate = DateTime.parse(deadline);
          final now = DateTime.now();
          
          if (deadlineDate.isBefore(now)) {
            deadlineText = '기한 만료';
          } else {
            final daysLeft = deadlineDate.difference(now).inDays;
            if (daysLeft == 0) {
              deadlineText = '오늘 마감';
            } else {
              deadlineText = '${daysLeft}일 남음';
            }
          }
        } catch (e) {
          deadlineText = '';
        }
      }
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDataRequest 
                ? [Colors.green.shade50, Colors.green.shade100]
                : [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목과 상태
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 아이콘
                  Icon(
                    isDataRequest ? MenuType.dataRequest.icon : MenuType.notice.icon,
                    size: 20,
                    color: isDataRequest ? Colors.green.shade600 : Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.title.length > 10 
                          ? '${post.title.substring(0, 10)}...' 
                          : post.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDataRequest ? Colors.green.shade800 : Colors.blue.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 자료요청 상태 표시
                  if (isDataRequest && submissionStatus.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: submissionStatus == '제출완료' 
                                ? Colors.green.shade200 
                                : Colors.orange.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            submissionStatus,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: submissionStatus == '제출완료' 
                                  ? Colors.green.shade800 
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                        // 제출기한 (제출 전이고 기한이 있을 때만)
                        if (submissionStatus == '제출전' && deadlineText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: deadlineText.contains('만료') 
                                  ? Colors.red.shade100
                                  : deadlineText.contains('오늘') 
                                      ? Colors.orange.shade100
                                      : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: deadlineText.contains('만료') 
                                      ? Colors.red.shade700
                                      : deadlineText.contains('오늘') 
                                          ? Colors.orange.shade700
                                          : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  deadlineText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: deadlineText.contains('만료') 
                                        ? Colors.red.shade700
                                        : deadlineText.contains('오늘') 
                                            ? Colors.orange.shade700
                                            : Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              
              // 내용
              Text(
                post.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isDataRequest ? Colors.green.shade700 : Colors.blue.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // 하단 정보 (작성자, 작성일자)
              Row(
                children: [
                  // 작성자
                  Text(
                    post.authorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 작성일자
                  Text(
                    '${post.createdAt.year}.${post.createdAt.month.toString().padLeft(2, '0')}.${post.createdAt.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
