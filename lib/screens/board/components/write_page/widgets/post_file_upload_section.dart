import 'package:flutter/material.dart';
import '../../../../../models/file_info_model.dart';
import '../../../../components/common/storage_upload_button.dart';

class PostFileUploadSection extends StatelessWidget {
  final List<FileInfo> imageFiles;
  final List<FileInfo> documentFiles;
  final Function(FileInfo) onImageSelected;
  final Function(FileInfo) onDocumentSelected;
  final Function(int) onImageRemoved;
  final Function(int) onDocumentRemoved;

  const PostFileUploadSection({
    super.key,
    required this.imageFiles,
    required this.documentFiles,
    required this.onImageSelected,
    required this.onDocumentSelected,
    required this.onImageRemoved,
    required this.onDocumentRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            StorageUploadButton(
              label: '이미지 첨부 (${imageFiles.length}/5)',
              isImage: true,
              disabled: imageFiles.length >= 5,
              onFileSelected: onImageSelected,
            ),
            const SizedBox(width: 12),
            StorageUploadButton(
              label: '파일 첨부 (${documentFiles.length}/5)',
              isImage: false,
              disabled: documentFiles.length >= 5,
              onFileSelected: onDocumentSelected,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (imageFiles.isNotEmpty) _buildImagePreview(),
        if (documentFiles.isNotEmpty) _buildDocumentList(),
      ],
    );
  }

  Widget _buildImagePreview() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageFiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, idx) {
          final fileInfo = imageFiles[idx];
          return Stack(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    fileInfo.bytes,
                    width: 84,
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onImageRemoved(idx),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocumentList() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('첨부 파일', style: TextStyle(fontWeight: FontWeight.bold)),
          ...documentFiles.asMap().entries.map((entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file, color: Colors.grey),
                title: Text(entry.value.displayName, style: const TextStyle(fontSize: 15)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onDocumentRemoved(entry.key),
                ),
              )),
        ],
      ),
    );
  }
}
