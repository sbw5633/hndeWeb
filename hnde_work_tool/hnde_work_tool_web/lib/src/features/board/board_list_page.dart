import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import '../common/app_user_avatar.dart';

const Color _navy = Color(0xFF1E3A8A);

/// 공지 / 자유 / 익명 — 레이아웃 동일, [boardType]·[title]만 다름
class BoardListPage extends StatefulWidget {
  const BoardListPage({
    required this.boardType,
    required this.title,
    super.key,
  });

  final String boardType;
  final String title;

  @override
  State<BoardListPage> createState() => _BoardListPageState();
}

class _BoardListPageState extends State<BoardListPage> {
  late final WorkFirestoreRepository _repo;
  late final Stream<List<PostModel>> _postsStream;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    _postsStream = _repo.watchPosts(widget.boardType);
  }

  Color get _accent {
    switch (widget.boardType) {
      case 'notice':
        return _navy;
      case 'freeboard':
        return const Color(0xFF0369A1);
      case 'anonymous':
        return const Color(0xFF6D28D9);
      default:
        return Colors.blueGrey;
    }
  }

  String get _boardLabel {
    switch (widget.boardType) {
      case 'notice':
        return '공지';
      case 'freeboard':
        return '자유';
      case 'anonymous':
        return '익명';
      default:
        return widget.boardType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withOpacity(0.25)),
                ),
                child: Text(
                  _boardLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _accent,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _navy,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(
                  '/board/${widget.boardType}/write',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('글쓰기'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: StreamBuilder<List<PostModel>>(
                stream: _postsStream,
                builder:
                    (BuildContext context, AsyncSnapshot<List<PostModel>> snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '불러오기 실패: ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(child: LoadingWidget(size: 64));
                  }
                  final List<PostModel> list =
                      snap.data ?? <PostModel>[];
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        '게시글이 없습니다.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (BuildContext context, int i) {
                      final PostModel p = list[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        leading: AppUserAvatar(
                          size: 36,
                          photoUrl: p.authorPhotoUrl,
                          fallbackText: p.authorDisplay,
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.white,
                        ),
                        onTap: () => context.go(
                          '/board/${widget.boardType}/${p.id}',
                        ),
                        title: Row(
                          children: <Widget>[
                            if (p.isOfficial)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Tooltip(
                                  message: '중요공지',
                                  child: Icon(
                                    Icons.campaign_rounded,
                                    size: 24,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                p.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: <Widget>[
                              if (p.imageUrls.isNotEmpty) ...<Widget>[
                                Icon(
                                  Icons.image_outlined,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${p.imageUrls.length}장',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  '${p.authorDisplay} · ${_formatDate(p.createdAt)}'
                                  '${p.editedAt == null ? '' : ' · 수정 ${_formatDate(p.editedAt)}'}'
                                  ' · 조회 ${p.readCount}',
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? t) {
    if (t == null) {
      return '-';
    }
    return DateFormat('yyyy.MM.dd').format(t.toDate());
  }
}
