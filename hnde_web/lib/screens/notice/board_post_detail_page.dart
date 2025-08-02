import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/board_post_model.dart';
import '../../services/firebase/board_post_service.dart';
import 'dart:html';

class BoardPostDetailPage extends StatefulWidget {
  final String postId;
  const BoardPostDetailPage({super.key, required this.postId});

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
          title: const Text('공지사항'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/notices'),
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
                onPressed: () => context.go('/notices'),
                child: const Text('목록으로 돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    return _BoardPostDetailContent(post: _post!);
  }
}

class _BoardPostDetailContent extends StatelessWidget {
  final BoardPost post;
  const _BoardPostDetailContent({required this.post});

  @override
  Widget build(BuildContext context) {
    final isAnonymous = post.type == 'anonymous';
    final isDataRequest = post.type == 'dataRequest';
    final isNotice = post.type == 'notice';
    final isGeneral = post.type == 'post';
    final authorName = isAnonymous ? '익명' : post.authorName;
    final createdAt = post.createdAt;
    final images = post.images;
    final files = post.files;
    final extra = post.extra;

    // 파일 목록 빌드
    Widget buildFileList() {
      if (files.isEmpty) return const SizedBox();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('첨부 파일', style: TextStyle(fontWeight: FontWeight.bold)),
          ...files.map((file) => ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Colors.grey),
                title: Text(file['name'] ?? file['url']?.split('/')?.last ?? ''),
                onTap: () {
                  final url = file['url'] ?? '';
                  final name = file['name'] ?? url.split('/').last;
                  
                  if (url.isNotEmpty) {
                    try {
                      
                      // 다운로드 링크 생성
                      final a = AnchorElement(href: url)
                        ..download = name
                        ..target = '_blank';
                      document.body!.append(a);
                      a.click();
                      a.remove();
                      
                      // 성공 메시지 표시
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$name 다운로드를 시작합니다.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      // 실패 시 새 창에서 열기
                      try {
                        window.open(url, '_blank');
                      } catch (_) {
                        // 최종 실패 시 사용자에게 알림
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('파일 다운로드에 실패했습니다: $name'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('파일 URL이 없습니다.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              )),
        ],
      );
    }

    // 이미지 목록 빌드
    Widget buildImageList() {
      if (images.isEmpty) return const SizedBox();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('첨부 이미지', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final image = images[idx];
                final url = image['url'] ?? '';
                final fileName = image['name'] ?? url.split('/').last;
                return _HoverImageWithOverlay(
                  imageUrl: url,
                  fileName: fileName,
                );
              },
            ),
          ),
        ],
      );
    }

    // 사업소별 제출 현황 빌드
    Widget buildDataRequestStatus() {
      if (!isDataRequest) return const SizedBox();
      // 예시: extra['uploadStatus'] = [{branch: '본사', uploaded: true, fileUrl: ...}, ...]
      final List<dynamic> statusList = extra['uploadStatus'] ?? [];
      if (statusList.isEmpty) return const SizedBox();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('사업소별 제출 현황', style: TextStyle(fontWeight: FontWeight.bold)),
          ...statusList.map((e) {
            final branch = e['branch'] ?? '-';
            final uploaded = e['uploaded'] == true;
            final fileUrl = e['fileUrl'] ?? null;
            return ListTile(
              leading: Icon(uploaded ? Icons.check_circle : Icons.cancel, color: uploaded ? Colors.green : Colors.red),
              title: Text(branch),
              subtitle: uploaded && fileUrl != null ? Text('파일: ${fileUrl.split('/').last}') : null,
              onTap: uploaded && fileUrl != null ? () {
                // 파일 다운로드/미리보기 등 구현
              } : null,
            );
          }).toList(),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/notices'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // 작성자/일시
            Row(
              children: [
                Text(authorName, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                const SizedBox(width: 12),
                Text('${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 24),
            // 본문
            Text(post.content, style: const TextStyle(fontSize: 16)),
            buildImageList(),
            buildFileList(),
            buildDataRequestStatus(),
            // TODO: 댓글 등 추가 가능
          ],
        ),
      ),
    );
  }
}

// 이미지 hover 오버레이 위젯
class _HoverImageWithOverlay extends StatefulWidget {
  final String imageUrl;
  final String fileName;
  const _HoverImageWithOverlay({required this.imageUrl, required this.fileName});
  @override
  State<_HoverImageWithOverlay> createState() => _HoverImageWithOverlayState();
}
class _HoverImageWithOverlayState extends State<_HoverImageWithOverlay> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          final url = widget.imageUrl;
          final name = widget.fileName;
          
          if (url.isNotEmpty) {
            try {
              // 다운로드 링크 생성
              final a = AnchorElement(href: url)
                ..download = name
                ..target = '_blank';
              document.body!.append(a);
              a.click();
              a.remove();
              
              // 성공 메시지 표시
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name 다운로드를 시작합니다.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            } catch (e) {
              // 실패 시 새 창에서 열기
              try {
                window.open(url, '_blank');
              } catch (_) {
                // 최종 실패 시 사용자에게 알림
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('이미지 다운로드에 실패했습니다: $name'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('이미지 URL이 없습니다.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: Stack(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                widget.imageUrl,
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            if (_hovered)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        widget.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 