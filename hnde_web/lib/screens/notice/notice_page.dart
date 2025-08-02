import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hnde_web/core/select_info_provider.dart';
import 'package:provider/provider.dart';
import '../../models/board_post_model.dart';
import 'write_notice_page.dart';
import '../components/common/app_bar.dart';
import 'package:go_router/go_router.dart';
import '../../utils/search_filter_widget.dart';
import '../../utils/search_filter_utils.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  String _searchQuery = '';
  String _selectedBranch = '모든 사업소';

  Stream<List<BoardPost>> noticeStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'notice')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BoardPost.fromJson(doc.data(), id: doc.id))
            .toList())
        .map((notices) => SearchFilterUtils.filterPosts(
          notices,
          searchQuery: _searchQuery,
          selectedBranch: _selectedBranch,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final selectInfoProvider = context.read<SelectInfoProvider>();
    if (!selectInfoProvider.loaded) selectInfoProvider.loadAll();

    return Scaffold(
      appBar: const CustomAppBar(
        title: '공지사항',
        tooltip: '공지사항 쓰기',
        writePage: WriteNoticePage(),
      ),
      body: Column(
        children: [
          // 검색 및 필터 영역
          SearchFilterWidget(
            searchHint: '제목으로 검색...',
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
          // 공지사항 목록
          Expanded(
            child: StreamBuilder<List<BoardPost>>(
              stream: noticeStream(),
              builder: (context, snapshot) {
                debugPrint(
                    '[DEBUG] StreamBuilder snapshot: hasError= {snapshot.hasError}, hasData=${snapshot.hasData}, connectionState=${snapshot.connectionState}');
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('[ERROR] StreamBuilder error: ${snapshot.error}');
                  return const Center(child: Text('공지사항을 불러오지 못했습니다.'));
                }
                final notices = snapshot.data ?? <BoardPost>[];
                debugPrint('[DEBUG] notices length: ${notices.length}');
                if (notices.isEmpty) {
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
                          _searchQuery.isNotEmpty || _selectedBranch != '모든 사업소'
                              ? '검색 결과가 없습니다.'
                              : '등록된 공지사항이 없습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: notices.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, idx) {
                    final notice = notices[idx];
                    final createdAt = notice.createdAt;
                    final targetGroup = notice.targetGroup;
                    final isAll = targetGroup == '전체'; // Firestore에 저장된 '전체' 사업소명 기준

                    String formatDate(DateTime date) {
                      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
                    }

                    String formatTime(DateTime date) {
                      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 태그
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isAll
                                  ? Colors.blue.shade100
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: isAll
                                    ? Colors.blue.shade300
                                    : Colors.green.shade300,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              '[$targetGroup]',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: isAll
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          // 제목과 작성자 정보
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 제목
                                Text(
                                  notice.title,
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8.0),
                                // 작성자명과 시간
                                Row(
                                  children: [
                                    Text(
                                      notice.authorName,
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Text(
                                      '${formatDate(createdAt)} ${formatTime(createdAt)}',
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        context.go('/notices/${notice.id}');
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
