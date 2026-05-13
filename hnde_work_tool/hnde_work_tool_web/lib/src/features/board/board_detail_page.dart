import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/board_comment_model.dart';
import '../../models/post_model.dart';
import '../../constants/firestore_paths.dart';
import '../../repositories/work_firestore_repository.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import '../common/message_alert.dart';
import '../common/app_user_avatar.dart';

const Color _navy = Color(0xFF1E3A8A);
const int _kCommentMax = 300;
const int _kBodyCollapsedLines = 30;
const int _kCommentCollapsedLines = 2;

class BoardDetailPage extends StatefulWidget {
  const BoardDetailPage({
    required this.boardType,
    required this.postId,
    super.key,
  });

  final String boardType;
  final String postId;

  @override
  State<BoardDetailPage> createState() => _BoardDetailPageState();
}

class _BoardDetailPageState extends State<BoardDetailPage> {
  late final WorkFirestoreRepository _repo;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _readIncremented = false;
  bool _commentSubmitting = false;
  bool _postActionBusy = false;

  late final Stream<PostModel?> _postStream;
  late final Stream<List<BoardCommentModel>> _commentsStream;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    _commentCtrl.addListener(() => setState(() {}));
    _postStream = _repo.watchPost(widget.postId);
    _commentsStream = _repo.watchPostComments(widget.postId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_readIncremented) {
        _readIncremented = true;
        _repo.incrementReadCount(widget.postId);
      }
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment(BuildContext context) async {
    final String t = _commentCtrl.text.trim();
    if (t.isEmpty) {
      return;
    }
    setState(() => _commentSubmitting = true);
    try {
      await _repo.addPostComment(widget.postId, t);
      if (context.mounted) {
        _commentCtrl.clear();
      }
    } catch (e) {
      if (context.mounted) {
        showMessageAlert(context, message: '$e', title: '댓글 등록 실패');
      }
    } finally {
      if (mounted) {
        setState(() => _commentSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PostModel?>(
      stream: _postStream,
      builder: (BuildContext context, AsyncSnapshot<PostModel?> snap) {
        if (snap.hasError) {
          return EnterpriseScaffold(
            title: '게시판',
            child: Center(child: Text('오류: ${snap.error}')),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const EnterpriseScaffold(
            title: '게시판',
            child: Center(child: LoadingWidget(size: 64)),
          );
        }
        final PostModel? p = snap.data;
        if (p == null) {
          return EnterpriseScaffold(
            title: '게시판',
            child: Center(
              child: TextButton(
                onPressed: () => context.go(_boardPath(widget.boardType)),
                child: const Text('목록으로'),
              ),
            ),
          );
        }

        final String? myUid = FirebaseAuth.instance.currentUser?.uid;
        final bool isAuthor = myUid != null && p.authorUid == myUid;

        Future<bool> canDelete() async {
          if (myUid == null) return false;
          if (isAuthor) return true;
          // 관리자(0/1)만 전 글 삭제 가능
          try {
            final Map<String, dynamic> me =
                await FirestorePaths.fetchMergedUserProfileMain(myUid);
            final int roleIdx = (me['roleIdx'] as num?)?.toInt() ?? 999;
            return roleIdx == 0 || roleIdx == 1;
          } catch (_) {
            return false;
          }
        }

        Future<void> doDelete() async {
          if (_postActionBusy) return;
          final bool ok = await showDialog<bool>(
                context: context,
                builder: (BuildContext ctx) => AlertDialog(
                  title: const Text('게시글 삭제'),
                  content: const Text(
                    '삭제하면 목록에서 보이지 않습니다.\nDB에는 기록이 남으며, 관리자는 별도 화면에서 확인할 수 있습니다.\n진행할까요?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (!ok) return;
          setState(() => _postActionBusy = true);
          try {
            await _repo.deletePostSoft(widget.postId);
            if (context.mounted) {
              context.go(_boardPath(widget.boardType));
            }
          } catch (e) {
            if (context.mounted) {
              showMessageAlert(context, message: '$e', title: '삭제 실패');
            }
          } finally {
            if (mounted) setState(() => _postActionBusy = false);
          }
        }

        Future<void> doEdit() async {
          if (_postActionBusy) return;
          final TextEditingController t =
              TextEditingController(text: p.title);
          final TextEditingController b =
              TextEditingController(text: p.body);
          final bool? ok = await showDialog<bool>(
            context: context,
            builder: (BuildContext ctx) => AlertDialog(
              title: const Text('게시글 수정'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: t,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          labelText: '제목',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: b,
                        maxLines: 10,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                          labelText: '내용',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '수정하면 DB에는 원본이 그대로 남고, 수정본은 새 게시글로 저장됩니다.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('수정'),
                ),
              ],
            ),
          );
          if (ok != true) return;
          setState(() => _postActionBusy = true);
          try {
            final String newId = await _repo.editPostCreateRevision(
              postId: widget.postId,
              title: t.text,
              body: b.text,
            );
            if (context.mounted) {
              context.go('/board/${widget.boardType}/$newId');
            }
          } catch (e) {
            if (context.mounted) {
              showMessageAlert(context, message: '$e', title: '수정 실패');
            }
          } finally {
            t.dispose();
            b.dispose();
            if (mounted) setState(() => _postActionBusy = false);
          }
        }

        return EnterpriseScaffold(
          title: '게시판',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => context.go(_boardPath(widget.boardType)),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('목록으로'),
              ),
              Expanded(
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (p.isOfficial)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Tooltip(
                                    message: '중요공지',
                                    child: Icon(
                                      Icons.campaign_rounded,
                                      color: Colors.orange.shade800,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              Text(
                                p.title,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                  color: _navy,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: <Widget>[
                                  AppUserAvatar(
                                    size: 28,
                                    photoUrl: p.authorPhotoUrl,
                                    fallbackText: p.authorDisplay,
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${p.authorDisplay} · ${_formatDate(p.createdAt)}'
                                      '${p.editedAt == null ? '' : ' · 수정 ${_formatDate(p.editedAt)}'}'
                                      ' · 조회 ${p.readCount}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  FutureBuilder<bool>(
                                    future: canDelete(),
                                    builder: (BuildContext context, AsyncSnapshot<bool> canDelSnap) {
                                      final bool canDel = canDelSnap.data ?? false;
                                      final bool canEdit = isAuthor; // 작성자만 수정
                                      if (!canDel && !canEdit) return const SizedBox.shrink();
                                      return PopupMenuButton<String>(
                                        enabled: !_postActionBusy,
                                        tooltip: '게시글 관리',
                                        onSelected: (String v) {
                                          if (v == 'edit') {
                                            doEdit();
                                          } else if (v == 'delete') {
                                            doDelete();
                                          }
                                        },
                                        itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                                          if (canEdit)
                                            const PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Text('수정'),
                                            ),
                                          if (canDel)
                                            const PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Text('삭제'),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              if (p.imageUrls.isNotEmpty) ...<Widget>[
                                _BoardImageHorizontalStrip(
                                  urls: p.imageUrls,
                                  repo: _repo,
                                ),
                                const SizedBox(height: 24),
                              ],
                              _ExpandableBodyText(
                                text: p.body,
                                maxLinesCollapsed: _kBodyCollapsedLines,
                              ),
                              const SizedBox(height: 32),
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                '댓글',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 12),
                              StreamBuilder<List<BoardCommentModel>>(
                                stream: _commentsStream,
                                builder: (
                                  BuildContext context,
                                  AsyncSnapshot<List<BoardCommentModel>> cs,
                                ) {
                                  if (cs.connectionState ==
                                          ConnectionState.waiting &&
                                      !cs.hasData) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final List<BoardCommentModel> comments =
                                      cs.data ?? <BoardCommentModel>[];
                                  if (comments.isEmpty) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        '아직 댓글이 없습니다.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    );
                                  }
                                  return Column(
                                    children: <Widget>[
                                      for (final BoardCommentModel c
                                          in comments)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: _CommentCard(
                                            comment: c,
                                            dateFormat: _formatDate,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _commentCtrl,
                                maxLines: 3,
                                minLines: 1,
                                maxLength: _kCommentMax,
                                inputFormatters: <TextInputFormatter>[
                                  LengthLimitingTextInputFormatter(
                                    _kCommentMax,
                                  ),
                                ],
                                decoration: InputDecoration(
                                  hintText:
                                      '댓글을 입력하세요 (최대 $_kCommentMax자)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: const OutlineInputBorder(),
                                  counterText: '',
                                  suffixText:
                                      '${_commentCtrl.text.length}/$_kCommentMax',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _commentSubmitting ||
                                      _commentCtrl.text.trim().isEmpty
                                  ? null
                                  : () => _submitComment(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: _navy,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                              ),
                              child: _commentSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('등록'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(Timestamp? t) {
    if (t == null) {
      return '-';
    }
    return DateFormat('yyyy.MM.dd HH:mm').format(t.toDate());
  }

  static String _boardPath(String type) {
    switch (type) {
      case 'notice':
        return '/notice';
      case 'freeboard':
        return '/freeboard';
      case 'anonymous':
        return '/anonymous';
      default:
        return '/';
    }
  }
}

/// 마우스·트랙패드로 드래그 스크롤 허용 (웹/데스크톱)
class _BoardImageScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// 가로 이미지: 마우스 드래그 + 휠(세로 휠을 가로 이동으로 변환)
class _BoardImageHorizontalStrip extends StatefulWidget {
  const _BoardImageHorizontalStrip({
    required this.urls,
    required this.repo,
  });

  final List<String> urls;
  final WorkFirestoreRepository repo;

  @override
  State<_BoardImageHorizontalStrip> createState() =>
      _BoardImageHorizontalStripState();
}

class _BoardImageHorizontalStripState extends State<_BoardImageHorizontalStrip> {
  late final ScrollController _controller;
  late final Map<String, Future<String>> _signedFutures;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _signedFutures = <String, Future<String>>{};
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent ev) {
    if (ev is! PointerScrollEvent) {
      return;
    }
    if (!_controller.hasClients) {
      return;
    }
    // 가로로 실제 스크롤할 필요가 없으면(오버플로우 없음) 이벤트를 소비하지 않고
    // 부모(페이지) 기본 세로 스크롤 동작에 맡깁니다.
    if (_controller.position.maxScrollExtent <=
        _controller.position.minScrollExtent) {
      return;
    }
    // 이미지 영역 위에서는 휠 이벤트를 이 위젯이 소비(Claim)해서,
    // 부모(페이지) 세로 스크롤로 전달되지 않도록 합니다.
    GestureBinding.instance.pointerSignalResolver.register(
      ev,
      (PointerSignalEvent event) {
        final PointerScrollEvent e = event as PointerScrollEvent;
        final double delta =
            e.scrollDelta.dx != 0 ? e.scrollDelta.dx : e.scrollDelta.dy;
        final double next = (_controller.offset + delta).clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        );
        _controller.jumpTo(next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ScrollConfiguration(
        behavior: _BoardImageScrollBehavior(),
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              itemCount: widget.urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int i) {
                final String u = widget.urls[i];
                final Future<String> fut = _signedFutures.putIfAbsent(
                  u,
                  () => widget.repo.getPresignedViewUrl(u),
                );
                return FutureBuilder<String>(
                  future: fut,
                  builder: (BuildContext context, AsyncSnapshot<String> snap) {
                    final String displayUrl =
                        (snap.hasData && (snap.data ?? '').isNotEmpty)
                            ? snap.data!
                            : u;
                    return GestureDetector(
                      onTap: () => _openImageDialog(context, displayUrl),
                      child: Container(
                        width: 280,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: displayUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openImageDialog(BuildContext context, String url) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(ctx).pop(),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 900,
                      maxHeight: 700,
                    ),
                    color: Colors.black.withOpacity(0.06),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                        width: 120,
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 520,
                        height: 320,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 본문: 최대 [maxLinesCollapsed]줄까지, 이후 펼쳐보기
class _ExpandableBodyText extends StatefulWidget {
  const _ExpandableBodyText({
    required this.text,
    required this.maxLinesCollapsed,
  });

  final String text;
  final int maxLinesCollapsed;

  @override
  State<_ExpandableBodyText> createState() => _ExpandableBodyTextState();
}

class _ExpandableBodyTextState extends State<_ExpandableBodyText> {
  bool _expanded = false;
  bool _hoverExpand = false;

  static const TextStyle _style = TextStyle(
    fontSize: 16,
    height: 1.55,
    color: Color(0xFF334155),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          textDirection: Directionality.of(context),
          maxLines: widget.maxLinesCollapsed,
        )..layout(maxWidth: constraints.maxWidth);
        final bool needExpand = painter.didExceedMaxLines;

        // 짧으면(펼쳐보기 불필요) 여백/버튼 없이 그대로 표시
        if (!needExpand) {
          return SelectableText(widget.text, style: _style);
        }

        if (_expanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SelectableText(widget.text, style: _style),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = false),
                  icon: const Icon(Icons.expand_less),
                  label: const Text('접기'),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SelectableText(
              widget.text,
              style: _style,
              maxLines: widget.maxLinesCollapsed,
            ),
            const SizedBox(height: 8),
            MouseRegion(
              onEnter: (_) => setState(() => _hoverExpand = true),
              onExit: (_) => setState(() => _hoverExpand = false),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _expanded = true),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _hoverExpand
                          ? Colors.blueGrey.shade100.withOpacity(0.85)
                          : Colors.grey.shade100.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.expand_more,
                          size: 20,
                          color: Colors.grey.shade800,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '펼쳐보기 (전체 본문)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({
    required this.comment,
    required this.dateFormat,
  });

  final BoardCommentModel comment;
  final String Function(Timestamp? t) dateFormat;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _expanded = false;
  bool _hoverExpand = false;

  static const TextStyle _bodyStyle = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: Color(0xFF334155),
  );

  @override
  Widget build(BuildContext context) {
    final BoardCommentModel c = widget.comment;
    final String name = c.authorDisplay.trim().isEmpty
        ? '익명'
        : c.authorDisplay.trim();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double textW =
            (constraints.maxWidth - 24 - 40 - 12).clamp(0, double.infinity);
        final TextPainter painter = TextPainter(
          text: TextSpan(text: c.body, style: _bodyStyle),
          textDirection: Directionality.of(context),
          maxLines: _kCommentCollapsedLines,
        )..layout(maxWidth: textW);
        final bool needExpand = painter.didExceedMaxLines;

        return Material(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppUserAvatar(
                  size: 40,
                  photoUrl: c.authorPhotoUrl,
                  fallbackText: name,
                  backgroundColor: _avatarColor(name),
                  foregroundColor: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            height: 1.2,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' · ${widget.dateFormat(c.createdAt)}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!needExpand)
                        SelectableText(c.body, style: _bodyStyle)
                      else if (_expanded) ...<Widget>[
                        SelectableText(c.body, style: _bodyStyle),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() => _expanded = false),
                            icon: const Icon(Icons.expand_less, size: 18),
                            label: const Text('접기'),
                          ),
                        ),
                      ] else ...<Widget>[
                        SelectableText(
                          c.body,
                          style: _bodyStyle,
                          maxLines: _kCommentCollapsedLines,
                        ),
                        const SizedBox(height: 6),
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoverExpand = true),
                          onExit: (_) => setState(() => _hoverExpand = false),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => _expanded = true),
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _hoverExpand
                                      ? Colors.blueGrey.shade100
                                          .withOpacity(0.85)
                                      : Colors.grey.shade200.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.expand_more,
                                      size: 18,
                                      color: Colors.grey.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '펼쳐보기',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _avatarColor(String name) {
    final int h = name.hashCode.abs();
    final List<Color> palette = <Color>[
      const Color(0xFF1E3A8A),
      const Color(0xFF0369A1),
      const Color(0xFF6D28D9),
      const Color(0xFF0D9488),
      const Color(0xFFBE123C),
    ];
    return palette[h % palette.length];
  }
}
