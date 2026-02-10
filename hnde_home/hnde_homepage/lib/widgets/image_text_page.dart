import 'package:flutter/material.dart';

// CEO 인사말과 경영이념은 동일한 구조이므로 재사용 가능한 위젯
class ImageTextPage extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String content;

  const ImageTextPage({
    super.key,
    this.imageUrl,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight * 0.7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      constraints: BoxConstraints(
        maxHeight: availableHeight,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역 (있는 경우에만 표시)
            if (imageUrl != null && imageUrl!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                height: 250,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.image,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            // 제목
            Text(
              title,
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
            // 텍스트 내용
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
