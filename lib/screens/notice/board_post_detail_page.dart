import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../const_value.dart';
import '../../models/board_post_model.dart';
import '../../services/firebase/board_post_service.dart';
import 'components/unified_post_card.dart';
import 'components/comment_section.dart';
import 'components/post_actions.dart';
import '../board/components/data_request_response_section.dart';

class BoardPostDetailPage extends StatefulWidget {
  final String postId;
  final MenuType type;
  const BoardPostDetailPage({super.key, required this.postId, required this.type});

  @override
  State<BoardPostDetailPage> createState() => _BoardPostDetailPageState();
}

class _BoardPostDetailPageState extends State<BoardPostDetailPage> {
  BoardPost? _post;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    try {
      final post = await BoardPostService.getBoardPostById(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _post == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('일시적 오류'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(widget.type.route),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error ?? '게시물을 찾을 수 없습니다.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(widget.type.route),
                child: const Text('목록으로 돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    return _BoardPostDetailContent(
      post: _post!, 
      type: widget.type,
      onRefresh: _loadPost,
    );
  }
}

class _BoardPostDetailContent extends StatelessWidget {
  final BoardPost post;
  final MenuType type;
  final VoidCallback? onRefresh;
  const _BoardPostDetailContent({
    required this.post, 
    required this.type,
    this.onRefresh,
  });

  String getTitle() {
    switch (type) {
      case MenuType.notice:
        return '공지사항';
      case MenuType.board:
        return '게시판';
      case MenuType.anonymousBoard:
        return '익명게시판';
      case MenuType.dataRequest:
        return '자료요청';
      default:
        return '게시물';
    }
  }

  String getRoute() {

    switch (type) {
      case MenuType.notice:
        return '/notices';
      case MenuType.board:
        return '/boards';
      case MenuType.anonymousBoard:
        return '/anonymous-boards';
      case MenuType.dataRequest:
        return '/data-requests';
      default:
        return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDataRequest = type == MenuType.dataRequest;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(getTitle()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(getRoute()),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 통합 게시물 카드 (제목, 작성자, 본문, 첨부파일)
            UnifiedPostCard(post: post, type: type),
            const SizedBox(height: 16),
            
            // 게시물 액션 (좋아요, 댓글수, 조회수)
            PostActions(post: post),
            const SizedBox(height: 24),
            
            // 자료요청일 때 사업소별 회신 현황 표시
            if (isDataRequest)
              DataRequestResponseSection(
                post: post,
                onResponseDeleted: (branchName) {
                  onRefresh?.call();
                },
              ),
            
            // 댓글 섹션
            if (isDataRequest) const SizedBox(height: 24),
            CommentSection(postId: post.id),
          ],
        ),
      ),
    );
  }
}
