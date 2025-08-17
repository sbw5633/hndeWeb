import 'package:flutter/material.dart';

import 'storage_upload_button.dart';
import 'package:provider/provider.dart';
import '../../../core/loading_provider.dart';
import '../../../core/select_info_provider.dart';
import '../../../core/page_state_provider.dart';
import '../../../core/auth_provider.dart';
import '../../../models/file_info_model.dart';
import '../../../const_value.dart';

class PostEditorForm extends StatefulWidget {
  final MenuType type; // 'notice' | 'board' | 'dataRequest' 등
  final void Function(
      String title,
      String content,
      List<Map<String, String>> images,
      List<Map<String, String>> files,
      String selectedBranch) onSubmit;
  final AuthProvider authProvider;
  final SelectInfoProvider selectInfoProvider;
  final String? initialTitle;
  final String? initialContent;
  final List<String>? initialImages;
  final List<String>? initialFiles;
  final void Function(VoidCallback submitForm)? onFormReady; // 추가된 콜백
  const PostEditorForm({
    super.key,
    required this.type,
    required this.onSubmit,
    required this.authProvider,
    required this.selectInfoProvider,
    this.initialTitle,
    this.initialContent,
    this.initialImages,
    this.initialFiles,
    this.onFormReady, // 추가된 파라미터
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

  late AuthProvider _authProvider;
  late SelectInfoProvider _selectInfoProvider;

  String? _selectedBranch; // 선택된 사업소

  int? _hoveredImageIndex; // 마우스 오버된 이미지 인덱스

  // Provider 참조 저장
  PageStateProvider? _pageStateProvider;
  List<Map<String, String>> branchOptions = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    _imageFiles = [];
    _documentFiles = [];
    _authProvider = widget.authProvider;
    _selectInfoProvider = widget.selectInfoProvider;

    // Provider 참조 저장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageStateProvider = context.read<PageStateProvider>();
        _pageStateProvider?.setEditing(true);
      }
    });

    // 선택정보(사업소, 직책, 급수) Provider에서 불러오기
    Future.microtask(() {
      if (mounted) {
        if (!_selectInfoProvider.loaded) _selectInfoProvider.loadAll();
      }
    });

    // onFormReady 콜백 호출 (submitForm 메서드 전달)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFormReady?.call(_submit);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    // Provider 호출 제거 - 위젯 해제 중에는 안전하지 않음
    super.dispose();
  }

  // 외부에서 호출할 수 있는 제출 메서드
  void submitForm() {
    _submit();
  }

  // 현재 폼 데이터를 가져오는 메서드
  Map<String, dynamic> getFormData(BuildContext context) {
    return {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'selectedBranch': _selectedBranch,
      'imageFiles': _imageFiles,
      'documentFiles': _documentFiles,
    };
  }

  // 사업소 선택 옵션 생성 메서드
  List<Map<String, String>> _getBranchOptions(BuildContext context) {
    // if (!selectInfo.loaded) return [];
    debugPrint('selectInfo: ${_selectInfoProvider.branches}');
    debugPrint('authProvider: ${_authProvider.appUser?.affiliation}');

    // 전체 관리자는 모든 사업소 선택 가능
    if (_authProvider.isAdmin) {
      return [
        {'id': '전체', 'name': '전체'},
        ..._selectInfoProvider.branches.map((b) => {
              'id': b['id']?.toString() ?? '',
              'name': b['name']?.toString() ?? ''
            }),
      ];
    }

    // 본사 사용자는 전체, 본사만 선택 가능
    if (_authProvider.appUser?.affiliation == '본사') {
      return [
        {'id': '전체', 'name': '전체'},
        {'id': '본사', 'name': '본사'},
      ];
    }

    // 다른 사업장 사용자는 선택 불가 (자동으로 해당 사업장)
    return [];
  }

  // 자동으로 설정될 사업소 결정
  String _getAutoBranch(BuildContext context) {
    if (_authProvider.isAdmin) {
      return _selectedBranch ?? '전체';
    }

    if (_authProvider.appUser?.affiliation == '본사') {
      return _selectedBranch ?? '전체';
    }

    // 다른 사업장 사용자는 자동으로 해당 사업장
    return _authProvider.appUser?.affiliation ?? '';
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoadingProvider>().setLoading(true,
          text: widget.type == MenuType.notice
              ? '공지사항 등록 중...'
              : widget.type == MenuType.board
                  ? '게시글 등록 중...'
                  : widget.type == MenuType.anonymousBoard
                      ? '익명게시글 등록 중...'
                      : widget.type == MenuType.dataRequest
                          ? '자료요청 등록 중...'
                          : '등록 중...');
      try {
        // 파일들을 업로드하고 URL/파일명 목록 생성
        List<Map<String, String>> imageList = [];
        List<Map<String, String>> fileList = [];

        // 이미지 파일들 업로드
        for (final fileInfo in _imageFiles) {
          try {
            final success = await fileInfo.upload();
            if (success) {
              imageList.add(fileInfo.toMap());
              debugPrint('이미지 업로드 성공: ${fileInfo.displayName}');
            } else {
              throw Exception('이미지 업로드 실패: ${fileInfo.displayName}');
            }
          } catch (e) {
            debugPrint('이미지 업로드 실패: $e');
            if (context.mounted) {
              String errorMessage = '이미지 업로드 실패: ${fileInfo.displayName}';
              errorMessage += '\n\nS3 업로드 중 오류가 발생했습니다.';
              errorMessage += '\n네트워크 연결을 확인하고 다시 시도해주세요.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
            // 파일 업로드 실패 시 글 등록 중단
            context.read<LoadingProvider>().setLoading(false);
            return;
          }
        }

        // 문서 파일들 업로드
        for (final fileInfo in _documentFiles) {
          try {
            final success = await fileInfo.upload();
            if (success) {
              fileList.add(fileInfo.toMap());
              debugPrint('파일 업로드 성공: ${fileInfo.displayName}');
            } else {
              throw Exception('파일 업로드 실패: ${fileInfo.displayName}');
            }
          } catch (e) {
            debugPrint('문서 업로드 실패: $e');
            if (context.mounted) {
              String errorMessage = '파일 업로드 실패: ${fileInfo.displayName}';
              errorMessage += '\n\nS3 업로드 중 오류가 발생했습니다.';
              errorMessage += '\n네트워크 연결을 확인하고 다시 시도해주세요.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
            // 파일 업로드 실패 시 글 등록 중단
            context.read<LoadingProvider>().setLoading(false);
            return;
          }
        }

        widget.onSubmit(
            _titleController.text.trim(),
            _contentController.text.trim(),
            imageList,
            fileList,
            _selectedBranch ?? '');
        _pageStateProvider?.setUnsavedChanges(false);
      } catch (e) {
        debugPrint('제출 실패: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('등록 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        context.read<LoadingProvider>().setLoading(false);
      }
    }
  }

  Widget _buildBranchSelector(List branchOptions, String autoBranch) {
    // 사업소 선택 (본사 사용자 또는 관리자만)
    return branchOptions.isNotEmpty
        ? Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IntrinsicWidth(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '사업소'),
                  value: _selectedBranch,
                  items: branchOptions
                      .map<DropdownMenuItem<String>>(
                          (b) => DropdownMenuItem<String>(
                                value: b['name'],
                                child: Text(b['name'] ?? ''),
                              ))
                      .toList(),
                  onChanged: (value) {
                    debugPrint('사업소 선택: $value');
                    setState(() {
                      _selectedBranch = value;
                    });
                    _pageStateProvider?.setUnsavedChanges(true);
                  },
                  validator: (value) => value == null ? '사업소를 선택하세요.' : null,
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(autoBranch,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {

    final _type = widget.type;
    if (_type == MenuType.notice) {
      // 자동으로 설정될 사업소 결정
      _selectedBranch = _getAutoBranch(context);

      // 사업소 선택 옵션 생성
      branchOptions = _getBranchOptions(context);
    }

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사업소 선택 (별도 행)
            _type == MenuType.notice ?
            _buildBranchSelector(branchOptions, _selectedBranch ?? ''): Container(),
            const SizedBox(height: 4),

            // 제목 입력
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '제목을 입력하세요.' : null,
              onChanged: (_) {
                setState(() {});
                _pageStateProvider?.setUnsavedChanges(true);
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),

            // 내용 입력
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: '내용'),
              maxLines: 8,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '내용을 입력하세요.' : null,
              onChanged: (_) {
                setState(() {});
                _pageStateProvider?.setUnsavedChanges(true);
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                StorageUploadButton(
                  label: '이미지 첨부 (${_imageFiles.length}/5)',
                  isImage: true,
                  disabled: _imageFiles.length >= 5,
                  onFileSelected: (fileInfo) async {
                    if (_imageFiles.length < 5) {
                      // 중복 파일 체크
                      final isDuplicate = _imageFiles.any(
                          (file) => file.displayName == fileInfo.displayName);
                      if (!isDuplicate) {
                        // FileInfo를 새로운 FileInfo로 변환
                        final newFileInfo = FileInfo(
                          fileName: fileInfo.fileName,
                          fileExtension: fileInfo.fileExtension,
                          bytes: fileInfo.bytes,
                          isImage: true,
                          originalFile: fileInfo.originalFile,
                        );
                        setState(
                            () => _imageFiles = [..._imageFiles, newFileInfo]);
                      }
                    }
                  },
                ),
                const SizedBox(width: 12),
                StorageUploadButton(
                  label: '파일 첨부 (${_documentFiles.length}/5)',
                  isImage: false,
                  disabled: _documentFiles.length >= 5,
                  onFileSelected: (fileInfo) async {
                    if (_documentFiles.length < 5) {
                      // 중복 파일 체크
                      final isDuplicate = _documentFiles.any(
                          (file) => file.displayName == fileInfo.displayName);
                      if (!isDuplicate) {
                        // FileInfo를 새로운 FileInfo로 변환
                        final newFileInfo = FileInfo(
                          fileName: fileInfo.fileName,
                          fileExtension: fileInfo.fileExtension,
                          bytes: fileInfo.bytes,
                          isImage: false,
                          originalFile: fileInfo.originalFile,
                        );
                        setState(() =>
                            _documentFiles = [..._documentFiles, newFileInfo]);
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
                      onEnter: (_) {
                        setState(() => _hoveredImageIndex = idx);
                      },
                      onExit: (_) {
                        setState(() => _hoveredImageIndex = null);
                      },
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
                                fit: BoxFit.contain,
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
                                onTap: () {
                                  setState(() => _imageFiles.removeAt(idx));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
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
                    const Text('첨부 파일',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._documentFiles.asMap().entries.map((entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file,
                              color: Colors.grey),
                          title: Text(entry.value.displayName,
                              style: const TextStyle(fontSize: 15)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(
                                  () => _documentFiles.removeAt(entry.key));
                            },
                          ),
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
