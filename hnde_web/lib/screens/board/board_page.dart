import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hnde_web/core/select_info_provider.dart';
import 'package:provider/provider.dart';
import '../../const_value.dart';
import '../../models/board_post_model.dart';
import '../components/common/app_bar.dart';
import 'package:go_router/go_router.dart';
import '../../utils/search_filter_widget.dart';
import '../../utils/search_filter_utils.dart';

class BoardPage extends StatefulWidget {
  final MenuType type;
  const BoardPage({super.key, required this.type});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  String _searchQuery = '';
  String _selectedBranch = '모든 사업소';

  Stream<List<BoardPost>> boardStream(MenuType type) {

    final boatdType = type.name;

    return FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: boatdType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BoardPost.fromJson(doc.data(), id: doc.id))
            .toList())
        .map((posts) => SearchFilterUtils.filterPosts(
          posts,
          searchQuery: _searchQuery,
          selectedBranch: _selectedBranch,
        ));
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
          // 검색 영역 (사업소 필터 없음)
          SearchFilterWidget(
            searchHint: '제목으로 검색...',
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
          // 게시글 목록
          Expanded(
            child: StreamBuilder<List<BoardPost>>(
              stream: boardStream(widget.type),
              builder: (context, snapshot) {
                debugPrint(
                    '[DEBUG] StreamBuilder snapshot: hasError= {snapshot.hasError}, hasData=${snapshot.hasData}, connectionState=${snapshot.connectionState}');
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('[ERROR] StreamBuilder error: ${snapshot.error}');
                  return const Center(child: Text('게시글을 불러오지 못했습니다.'));
                }
                final posts = snapshot.data ?? <BoardPost>[];
                debugPrint('[DEBUG] posts length: ${posts.length}');
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
                return ListView.separated(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, idx) {
                    final post = posts[idx];
                    final createdAt = post.createdAt;

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
                          // 제목과 작성자 정보
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 제목
                                Text(
                                  post.title,
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
                                      post.anonymity ? '익명' : post.authorName,
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
                        context.go('${widget.type.route}/${post.id}');
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