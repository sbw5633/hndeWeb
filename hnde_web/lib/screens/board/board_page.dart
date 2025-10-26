import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hnde_web/core/select_info_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../const_value.dart';
import '../../core/auth_provider.dart';
import '../../models/board_post_model.dart';
import '../components/common/app_bar.dart';
import '../../utils/search_filter_widget.dart';
import '../../utils/search_filter_utils.dart';
import '../components/common/post_stats_widget.dart';

enum SortType {
  createdAt, // 작성일자 순
  deadline, // 마감기한 순
  submission, // 제출 유무 순
}

class BoardPage extends StatefulWidget {
  final MenuType type;
  const BoardPage({super.key, required this.type});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  String _searchQuery = '';
  String _selectedBranch = '모든 사업소';
  SortType _sortType = SortType.createdAt;
  bool _sortAscending = false;

  Stream<List<BoardPost>> boardStream(MenuType type) {
    final boardType = type.name;

    return FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: boardType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BoardPost.fromJson(doc.data(), id: doc.id))
            .toList())
        .map((posts) => SearchFilterUtils.filterPosts(
              posts,
              searchQuery: _searchQuery,
              selectedBranch: _selectedBranch,
            ))
        .map((posts) => _sortPosts(posts));
  }

  // 게시글 정렬
  List<BoardPost> _sortPosts(List<BoardPost> posts) {
    final sortedPosts = List<BoardPost>.from(posts);

    sortedPosts.sort((a, b) {
      switch (_sortType) {
        case SortType.createdAt:
          return _sortAscending
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt);

        case SortType.deadline:
          final aDeadline = _getDeadlineDateTime(a);
          final bDeadline = _getDeadlineDateTime(b);

          // 기한이 없는 경우 맨 뒤로
          if (aDeadline == null && bDeadline == null) return 0;
          if (aDeadline == null) return 1;
          if (bDeadline == null) return -1;

          return _sortAscending
              ? aDeadline.compareTo(bDeadline)
              : bDeadline.compareTo(aDeadline);

        case SortType.submission:
          final aStatus = _getSubmissionStatus(a);
          final bStatus = _getSubmissionStatus(b);

          // 제출 완료가 우선, 그 다음 제출 전, 마지막은 해당 없음
          if (aStatus == '제출 완료' && bStatus != '제출 완료') return -1;
          if (bStatus == '제출 완료' && aStatus != '제출 완료') return 1;
          if (aStatus == '제출 전' && bStatus == '') return -1;
          if (bStatus == '제출 전' && aStatus == '') return 1;

          return 0;
      }
    });

    return sortedPosts;
  }

  // 자료요청 제출 상태 확인
  String _getSubmissionStatus(BoardPost post) {
    if (widget.type != MenuType.dataRequest) return '';

    final currentUser = context.read<AuthProvider>().appUser;
    if (currentUser == null) return '';

    final userAffiliation = currentUser.affiliation;
    final selectedBranches =
        post.extra['selectedBranches'] as List<dynamic>? ?? [];

    if (!selectedBranches.contains(userAffiliation)) return '';

    final responses = post.responses;
    final userResponse = responses[userAffiliation] as Map<String, dynamic>?;

    if (userResponse != null && userResponse['submittedAt'] != null) {
      return '제출 완료';
    } else {
      return '제출 전';
    }
  }

  // 제출 기한 DateTime 가져오기
  DateTime? _getDeadlineDateTime(BoardPost post) {
    if (widget.type != MenuType.dataRequest) return null;

    final deadline = post.extra['deadline'] as String?;
    if (deadline == null || deadline.isEmpty) return null;

    try {
      return DateTime.parse(deadline);
    } catch (e) {
      return null;
    }
  }

  // 제출 기한 텍스트 확인
  String _getDeadlineText(BoardPost post) {
    if (widget.type != MenuType.dataRequest) return '';

    final deadline = post.extra['deadline'] as String?;
    print('=== 제출기한 디버깅 ===');
    print('post.id: ${post.id}');
    print('post.extra: ${post.extra}');
    print('deadline: $deadline');

    if (deadline == null || deadline.isEmpty) {
      print('기한이 없음');
      return '';
    }

    try {
      final deadlineDate = DateTime.parse(deadline);
      final now = DateTime.now();

      print('deadlineDate: $deadlineDate');
      print('now: $now');

      if (deadlineDate.isBefore(now)) {
        print('기한 만료');
        return '기한 만료';
      } else {
        final daysLeft = deadlineDate.difference(now).inDays;
        if (daysLeft == 0) {
          print('오늘 마감');
          return '오늘 마감';
        } else {
          print('${daysLeft}일 남음');
          return '${daysLeft}일 남음';
        }
      }
    } catch (e) {
      return '';
    }
  }

  // 정렬 버튼 위젯
  Widget _buildSortButton() {
    if (widget.type != MenuType.dataRequest) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Text(
            '정렬:',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('작성일자', SortType.createdAt),
                  const SizedBox(width: 8.0),
                  _buildSortChip('마감기한', SortType.deadline),
                  const SizedBox(width: 8.0),
                  _buildSortChip('제출유무', SortType.submission),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, SortType sortType) {
    final isSelected = _sortType == sortType;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_sortType == sortType) {
            _sortAscending = !_sortAscending;
          } else {
            _sortType = sortType;
            _sortAscending = false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isSelected ? Colors.blue.shade200 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4.0),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14.0,
                color: Colors.blue.shade700,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectInfoProvider = context.read<SelectInfoProvider>();
    if (!selectInfoProvider.loaded) selectInfoProvider.loadAll();

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.type.label,
        tooltip: '${widget.type.label} 쓰기',
        writePage: WritePage.get(widget.type),
      ),
      body: Column(
        children: [
          // 검색 영역
          SearchFilterWidget(
            showBranchFilter: false,
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            onBranchChanged: (branch) {
              setState(() {
                _selectedBranch = branch;
              });
            },
          ),
          // 정렬 버튼 (자료요청만)
          _buildSortButton(),
          // 게시글 목록
          Expanded(
            child: StreamBuilder<List<BoardPost>>(
              stream: boardStream(widget.type),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('게시글을 불러오지 못했습니다.'));
                }
                final posts = snapshot.data ?? <BoardPost>[];
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? '검색 결과가 없습니다.'
                              : '등록된 게시글이 없습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: posts.length,
                  itemBuilder: (context, idx) {
                    final post = posts[idx];
                    return _buildPostCard(post);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BoardPost post) {
    final createdAt = post.createdAt;
    final isDataRequest = widget.type == MenuType.dataRequest;

    final submissionStatus = isDataRequest ? _getSubmissionStatus(post) : '';
    final deadlineText = isDataRequest ? _getDeadlineText(post) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: () {
            context.go('${widget.type.route}/${post.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목과 상태 정보
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    // 자료요청 상태와 기한 표시
                    if (isDataRequest &&
                        (submissionStatus.isNotEmpty ||
                            deadlineText.isNotEmpty)) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 제출기한 표시 (제출 전일 때만, 제출 상태 좌측에)
                          if (submissionStatus == '제출 전' &&
                              deadlineText.isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 8.0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              decoration: BoxDecoration(
                                color: deadlineText.contains('만료')
                                    ? Colors.red.shade50
                                    : deadlineText.contains('오늘')
                                        ? Colors.orange.shade50
                                        : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                  color: deadlineText.contains('만료')
                                      ? Colors.red.shade200
                                      : deadlineText.contains('오늘')
                                          ? Colors.orange.shade200
                                          : Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 12.0,
                                    color: deadlineText.contains('만료')
                                        ? Colors.red.shade700
                                        : deadlineText.contains('오늘')
                                            ? Colors.orange.shade700
                                            : Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    deadlineText,
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w500,
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
                          // 제출 상태 표시
                          if (submissionStatus.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              decoration: BoxDecoration(
                                color: submissionStatus == '제출 완료'
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                  color: submissionStatus == '제출 완료'
                                      ? Colors.green.shade200
                                      : Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                submissionStatus,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: submissionStatus == '제출 완료'
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12.0),

                // 작성자 정보
                Row(
                  children: [
                    Row(
                      children: [
                        // 작성자 정보
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16.0,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              post.anonymity ? '익명' : post.authorName,
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16.0),

                        // 작성일시
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16.0,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 통합 통계 위젯 (댓글수, 좋아요수)
                    PostStatsWidget(
                      postId: post.id,
                      showComments: true,
                      showLikes: true,
                      showViews: false,
                      iconSize: 14,
                      fontSize: 12,
                      iconColor: Colors.grey.shade500,
                      textColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: MainAxisAlignment.end,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
