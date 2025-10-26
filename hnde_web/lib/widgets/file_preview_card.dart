import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'file_handler_widget.dart';

class FilePreviewCard extends StatelessWidget {
  final FileData file;
  final VoidCallback onRemove;
  final int? pageCount;

  const FilePreviewCard({
    super.key,
    required this.file,
    required this.onRemove,
    this.pageCount,
  });

  bool get _isImage => _isImageFile(file.fileName);

  bool _isImageFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  Uint8List get _imageData {
    if (_isImage) {
      return file.data;
    }
    // PDF 썸네일을 생성하려면 추가 로직 필요
    return file.data;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지/PDF 썸네일
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              child: _isImage
                  ? Image.memory(
                      _imageData,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.broken_image,
                            size: 16,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 16,
                            color: Colors.red,
                          ),
                          if (pageCount != null) ...[
                            SizedBox(height: 1),
                            Text(
                              '$pageCount',
                              style: TextStyle(
                                fontSize: 7,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
          
          // 파일 정보
          Padding(
            padding: EdgeInsets.all(2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.fileName,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


