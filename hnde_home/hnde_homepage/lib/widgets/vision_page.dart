import 'package:flutter/material.dart';
import '../models/vision.dart';

class VisionPage extends StatefulWidget {
  final VisionContent content;

  const VisionPage({
    super.key,
    required this.content,
  });

  @override
  State<VisionPage> createState() => _VisionPageState();
}

class _VisionPageState extends State<VisionPage> {
  double? _imageAspectRatio;
  bool _imageLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.content.imageUrl != null && 
        widget.content.imageUrl!.isNotEmpty) {
      _loadImageDimensions();
    }
  }

  Future<void> _loadImageDimensions() async {
    if (widget.content.imageUrl == null || 
        widget.content.imageUrl!.isEmpty) return;

    setState(() => _imageLoading = true);
    try {
      final imageProvider = NetworkImage(widget.content.imageUrl!);
      final listener = ImageStreamListener((ImageInfo info, bool _) {
        final image = info.image;
        final aspectRatio = image.width / image.height;
        if (mounted) {
          setState(() {
            _imageAspectRatio = aspectRatio;
            _imageLoading = false;
          });
        }
      });
      final stream = imageProvider.resolve(const ImageConfiguration());
      stream.addListener(listener);
      
      // 타임아웃 설정 (5초)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _imageLoading) {
          setState(() {
            _imageAspectRatio = null;
            _imageLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _imageAspectRatio = null;
          _imageLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      padding: const EdgeInsets.only(left: 80, right: 80, top: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 영역 (있는 경우에만 표시)
            if (widget.content.imageUrl != null && 
                widget.content.imageUrl!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageAspectRatio != null
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: 250,
                            maxHeight: screenHeight * 0.8,
                          ),
                          child: AspectRatio(
                            aspectRatio: _imageAspectRatio!,
                            child: Image.network(
                              widget.content.imageUrl!,
                              fit: _getBoxFit(widget.content.imageFit ?? 'cover'),
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 250,
                                  child: Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : Container(
                          constraints: BoxConstraints(
                            minHeight: 250,
                            maxHeight: screenHeight * 0.8,
                          ),
                          child: Image.network(
                            widget.content.imageUrl!,
                            fit: _getBoxFit(widget.content.imageFit ?? 'cover'),
                            width: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Container(
                                height: 250,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 250,
                                child: Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          // 제목 (있는 경우에만 표시)
          if (widget.content.title != null && 
              widget.content.title!.isNotEmpty) ...[
            Text(
              widget.content.title!,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 4,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
          ],
          // 텍스트 내용 (있는 경우에만 표시)
          if (widget.content.content != null && 
              widget.content.content!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Text(
                widget.content.content!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.8,
                ),
              ),
            ),
        ],
      ),
    );
  }

  BoxFit _getBoxFit(String? fit) {
    switch (fit) {
      case 'cover':
        return BoxFit.cover;
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }
}
