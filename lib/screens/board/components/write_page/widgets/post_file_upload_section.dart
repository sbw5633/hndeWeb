import 'package:flutter/material.dart';
import '../../../../../models/file_info_model.dart';
import '../../../../../screens/components/common/storage_upload_button.dart';

class PostFileUploadSection extends StatefulWidget {
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
  State<PostFileUploadSection> createState() => _PostFileUploadSectionState();
}

class _PostFileUploadSectionState extends State<PostFileUploadSection> {
  int? _hoveredImageIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            StorageUploadButton(
              label: '이미지 첨부 (${widget.imageFiles.length}/5)',
              isImage: true,
              disabled: widget.imageFiles.length >= 5,
              onFileSelected: widget.onImageSelected,
            ),
            const SizedBox(width: 12),
            StorageUploadButton(
              label: '파일 첨부 (${widget.documentFiles.length}/5)',
              isImage: false,
              disabled: widget.documentFiles.length >= 5,
              onFileSelected: widget.onDocumentSelected,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.imageFiles.isNotEmpty) _buildImagePreview(),
        if (widget.documentFiles.isNotEmpty) _buildDocumentList(),
      ],
    );
  }

  Widget _buildImagePreview() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.imageFiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, idx) => _buildImageItem(idx),
      ),
    );
  }

  Widget _buildImageItem(int idx) {
    final fileInfo = widget.imageFiles[idx];
    final isHovered = _hoveredImageIndex == idx;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredImageIndex = idx),
      onExit: (_) => setState(() => _hoveredImageIndex = null),
      child: Stack(
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
          _buildImageOverlay(fileInfo, isHovered),
          _buildDeleteButton(idx, isHovered),
        ],
      ),
    );
  }

  Widget _buildImageOverlay(FileInfo fileInfo, bool isHovered) {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: isHovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                fileInfo.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(int idx, bool isHovered) {
    return Positioned(
      top: 2,
      right: 2,
      child: AnimatedOpacity(
        opacity: isHovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () => widget.onImageRemoved(idx),
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
    );
  }

  Widget _buildDocumentList() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('첨부 파일', style: TextStyle(fontWeight: FontWeight.bold)),
          ...widget.documentFiles.asMap().entries.map((entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file, color: Colors.grey),
                title: Text(entry.value.displayName, style: const TextStyle(fontSize: 15)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => widget.onDocumentRemoved(entry.key),
                ),
              )),
        ],
      ),
    );
  }
}
