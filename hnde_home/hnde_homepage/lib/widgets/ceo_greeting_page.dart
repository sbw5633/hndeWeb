import 'package:flutter/material.dart';
import '../models/home_page_config.dart';

class CEOGreetingPage extends StatefulWidget {
  final String? imageUrl;
  final String? imageFit;
  final List<TextLineConfig> textLines;

  const CEOGreetingPage({
    super.key,
    this.imageUrl,
    this.imageFit,
    required this.textLines,
  });

  @override
  State<CEOGreetingPage> createState() => _CEOGreetingPageState();
}

class _CEOGreetingPageState extends State<CEOGreetingPage> {
  double? _imageAspectRatio;
  bool _imageLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _loadImageDimensions();
    }
  }

  Future<void> _loadImageDimensions() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return;

    setState(() => _imageLoading = true);
    try {
      final imageProvider = NetworkImage(widget.imageUrl!);
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

  String _getContentText() {
    if (widget.textLines.isEmpty) return '';
    return widget.textLines
        .where((line) => !line.isDivider && line.text.isNotEmpty)
        .map((line) => line.text)
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final contentText = _getContentText();

    return Container(
      padding: const EdgeInsets.only(left: 80, right: 80, top: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 영역 (있는 경우에만 표시)
          if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
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
                            widget.imageUrl!,
                            fit: BoxFit.contain,
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
                          widget.imageUrl!,
                          fit: BoxFit.contain,
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
          // 텍스트 내용 (있는 경우에만 표시)
          if (contentText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Text(
                contentText,
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
}

