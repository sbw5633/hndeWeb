import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'cloudinary_upload_button.dart';
import '../../../models/file_info_model.dart';
import '../../../services/firebase/storage_service.dart';
import 'package:provider/provider.dart';
import '../../../core/loading_provider.dart';

class PostEditorForm extends StatefulWidget {
  final String type; // 'notice' | 'board' | 'dataRequest' 등
  final void Function(String title, String content, List<String> images, List<String> files) onSubmit;
  final String? initialTitle;
  final String? initialContent;
  final List<String>? initialImages;
  final List<String>? initialFiles;
  const PostEditorForm({
    super.key,
    required this.type,
    required this.onSubmit,
    this.initialTitle,
    this.initialContent,
    this.initialImages,
    this.initialFiles,
  });

  @override
  State<PostEditorForm> createState() => _PostEditorFormState();
}

class _PostEditorFormState extends State<PostEditorForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<FileInfo> _imageFiles = [];
  List<FileInfo> _documentFiles = [];
  final ImagePicker _picker = ImagePicker();
  int? _hoveredImageIndex; // 마우스 오버된 이미지 인덱스

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    // 초기값은 URL 문자열이므로 FileInfo로 변환할 수 없으므로 빈 리스트로 시작
    _imageFiles = [];
    _documentFiles = [];
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoadingProvider>().setLoading(true, text: widget.type == 'notice' ? '공지사항 등록 중...' : widget.type == 'board' ? '게시글 등록 중...' : '등록 중...');
      try {
        // 파일들을 Cloudinary에 업로드하고 URL 목록 생성
        List<String> imageUrls = [];
        List<String> fileUrls = [];
        // 이미지 파일들 업로드
        for (final fileInfo in _imageFiles) {
          try {
            final url = await StorageService.uploadFileToCloudinary(fileInfo.originalFile);
            if (url != null) {
              imageUrls.add(url);
            }
          } catch (e) {
            print('이미지 업로드 실패: $e');
          }
        }
        // 문서 파일들 업로드
        for (final fileInfo in _documentFiles) {
          try {
            final url = await StorageService.uploadFileToCloudinary(fileInfo.originalFile);
            if (url != null) {
              fileUrls.add(url);
            }
          } catch (e) {
            print('문서 업로드 실패: $e');
          }
        }
        widget.onSubmit(_titleController.text.trim(), _contentController.text.trim(), imageUrls, fileUrls);
      } catch (e) {
        print('제출 실패: $e');
      } finally {
        context.read<LoadingProvider>().setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요.' : null,
              onChanged: (_) => setState(() {}),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: '내용'),
              maxLines: 8,
              validator: (v) => (v == null || v.trim().isEmpty) ? '내용을 입력하세요.' : null,
              onChanged: (_) => setState(() {}),
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CloudinaryUploadButton(
                  label: '이미지 첨부 (${_imageFiles.length}/5)',
                  isImage: true,
                  disabled: _imageFiles.length >= 5,
                  onFileSelected: (fileInfo) {
                    if (_imageFiles.length < 5) {
                      // 중복 파일 체크
                      final isDuplicate = _imageFiles.any((file) => 
                        file.displayName == fileInfo.displayName);
                      if (!isDuplicate) {
                        setState(() => _imageFiles = [..._imageFiles, fileInfo]);
                      }
                    }
                  },
                ),
                const SizedBox(width: 12),
                CloudinaryUploadButton(
                  label: '파일 첨부 (${_documentFiles.length}/5)',
                  isImage: false,
                  disabled: _documentFiles.length >= 5,
                  onFileSelected: (fileInfo) {
                    if (_documentFiles.length < 5) {
                      // 중복 파일 체크
                      final isDuplicate = _documentFiles.any((file) => 
                        file.displayName == fileInfo.displayName);
                      if (!isDuplicate) {
                        setState(() => _documentFiles = [..._documentFiles, fileInfo]);
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_imageFiles.isNotEmpty)
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, idx) {
                    final fileInfo = _imageFiles[idx];
                    final isHovered = _hoveredImageIndex == idx;
                    
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hoveredImageIndex = idx),
                      onExit: (_) => setState(() => _hoveredImageIndex = null),
                      child: Stack(
                        children: [
                          // 이미지 컨테이너
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
                                fit: BoxFit.contain, // 전체 이미지가 보이도록 변경
                              ),
                            ),
                          ),
                          // 파일명 오버레이 (마우스 오버 시 표시)
                          Positioned.fill(
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
                          ),
                          // 삭제 버튼
                          Positioned(
                            top: 2,
                            right: 2,
                            child: AnimatedOpacity(
                              opacity: isHovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                onTap: () => setState(() => _imageFiles.removeAt(idx)),
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
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_documentFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('첨부 파일', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._documentFiles.asMap().entries.map((entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file, color: Colors.grey),
                          title: Text(entry.value.displayName, style: const TextStyle(fontSize: 15)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _documentFiles.removeAt(entry.key)),
                          ),
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(widget.type == 'notice' ? '공지사항 등록' : widget.type == 'board' ? '게시글 등록' : '등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 