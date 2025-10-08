import 'package:flutter/material.dart';
import '../../../models/board_post_model.dart';
import '../../../const_value.dart';
import '../../../utils/file_download_utils.dart';

class UnifiedPostCard extends StatelessWidget {
  final BoardPost post;
  final MenuType type;

  const UnifiedPostCard({
    super.key,
    required this.post,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isAnonymous = post.anonymity;
    final authorName = isAnonymous ? '익명' : post.authorName;
    final createdAt = post.createdAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (타입 아이콘, 제목)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getTypeColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(),
                  color: _getTypeColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 작성자 정보
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  authorName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 구분선
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 24),
          
          // 본문
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          
          // 첨부파일
          if (post.images.isNotEmpty || post.files.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              height: 1,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 24),
            _buildAttachmentsSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.attach_file,
              color: Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '첨부파일',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 이미지 섹션
        if (post.images.isNotEmpty) ...[
          _buildImageSection(),
          if (post.files.isNotEmpty) const SizedBox(height: 16),
        ],
        
        // 파일 섹션
        if (post.files.isNotEmpty) ...[
          _buildFileSection(),
        ],
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이미지 (${post.images.length}개)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: post.images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final image = post.images[idx];
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

  Widget _buildFileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '파일 (${post.files.length}개)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        ...post.files.map((file) => _buildFileItem(file)),
      ],
    );
  }

  Widget _buildFileItem(Map<String, dynamic> file) {
    final fileName = file['name'] ?? file['url']?.split('/').last ?? '';
    final fileUrl = file['url'] ?? '';
    
    return Builder(
      builder: (context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: InkWell(
          onTap: () {
            FileDownloadUtils.downloadFile(
              context: context,
              url: fileUrl,
              fileName: fileName,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.insert_drive_file,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '클릭하여 다운로드',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.download,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (type) {
      case MenuType.notice:
        return Colors.blue.shade600;
      case MenuType.dataRequest:
        return Colors.green.shade600;
      case MenuType.board:
        return Colors.purple.shade600;
      case MenuType.anonymousBoard:
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getTypeIcon() {
    switch (type) {
      case MenuType.notice:
        return Icons.announcement;
      case MenuType.dataRequest:
        return Icons.file_present;
      case MenuType.board:
        return Icons.forum;
      case MenuType.anonymousBoard:
        return Icons.chat;
      default:
        return Icons.article;
    }
  }
}

// 이미지 hover 오버레이 위젯
class _HoverImageWithOverlay extends StatefulWidget {
  final String imageUrl;
  final String fileName;
  
  const _HoverImageWithOverlay({
    required this.imageUrl,
    required this.fileName,
  });

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
          FileDownloadUtils.downloadImage(
            context: context,
            url: widget.imageUrl,
            fileName: widget.fileName,
          );
        },
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                widget.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_hovered)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            widget.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
