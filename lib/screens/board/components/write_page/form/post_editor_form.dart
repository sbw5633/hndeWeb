import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/select_info_provider.dart';
import '../../../../../core/page_state_provider.dart';
import '../../../../../core/auth_provider.dart';
import '../../../../../models/file_info_model.dart';
import '../../../../../const_value.dart';
import '../widgets/post_content_field.dart';
import '../widgets/post_file_upload_section.dart';
import '../widgets/post_form_submit.dart';
import '../widgets/post_title_field.dart';
import '../widgets/post_form_data_request_header.dart';

class PostEditorForm extends StatefulWidget {
  final MenuType type;
  final void Function(
      String title,
      String content,
      List<Map<String, String>> images,
      List<Map<String, String>> files,
      String selectedBranch,
      Map<String, dynamic>? extraData) onSubmit;
  final AuthProvider authProvider;
  final SelectInfoProvider selectInfoProvider;
  final String? initialTitle;
  final String? initialContent;
  final List<String>? initialImages;
  final List<String>? initialFiles;
  final void Function(VoidCallback submitForm)? onFormReady;

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
    this.onFormReady,
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
  String? _selectedBranch;
  List<String> _selectedBranches = [];
  PageStateProvider? _pageStateProvider;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageStateProvider = context.read<PageStateProvider>();
        _pageStateProvider?.setEditing(true);
        widget.onFormReady?.call(_submit);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() async {
    final selectedBranch = widget.type == MenuType.dataRequest 
        ? _selectedBranches.join(', ') 
        : _selectedBranch ?? '';
        
    Map<String, dynamic> extraData = {};
    if (widget.type == MenuType.dataRequest) {
      extraData['requestedBranches'] = _selectedBranches;
      extraData['requestType'] = 'dataRequest';
    }
        
    await PostFormSubmit.submitForm(
      context: context,
      formKey: _formKey,
      type: widget.type,
      titleController: _titleController,
      contentController: _contentController,
      imageFiles: _imageFiles,
      documentFiles: _documentFiles,
      selectedBranch: selectedBranch,
      extraData: extraData,
      onSubmit: widget.onSubmit,
      onSuccess: () {
        _pageStateProvider?.setUnsavedChanges(false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.type == MenuType.dataRequest)
              PostFormDataRequestHeader(
                selectedBranches: _selectedBranches,
                onBranchesChanged: (branches) {
                  setState(() {
                    _selectedBranches = branches;
                  });
                  _pageStateProvider?.setUnsavedChanges(true);
                },
              ),
            PostTitleField(
              controller: _titleController,
              onContentChanged: (_) => _pageStateProvider?.setUnsavedChanges(true),
            ),
            const SizedBox(height: 16),
            PostContentField(
              controller: _contentController,
              onContentChanged: (_) => _pageStateProvider?.setUnsavedChanges(true),
            ),
            const SizedBox(height: 16),
            PostFileUploadSection(
              imageFiles: _imageFiles,
              documentFiles: _documentFiles,
              onImageSelected: (fileInfo) async {
                if (_imageFiles.length < 5) {
                  final isDuplicate = _imageFiles.any(
                      (file) => file.displayName == fileInfo.displayName);
                  if (!isDuplicate) {
                    final newFileInfo = FileInfo(
                      fileName: fileInfo.fileName,
                      fileExtension: fileInfo.fileExtension,
                      bytes: fileInfo.bytes,
                      isImage: true,
                      originalFile: fileInfo.originalFile,
                    );
                    setState(() => _imageFiles = [..._imageFiles, newFileInfo]);
                  }
                }
              },
              onDocumentSelected: (fileInfo) async {
                if (_documentFiles.length < 5) {
                  final isDuplicate = _documentFiles.any(
                      (file) => file.displayName == fileInfo.displayName);
                  if (!isDuplicate) {
                    final newFileInfo = FileInfo(
                      fileName: fileInfo.fileName,
                      fileExtension: fileInfo.fileExtension,
                      bytes: fileInfo.bytes,
                      isImage: false,
                      originalFile: fileInfo.originalFile,
                    );
                    setState(() => _documentFiles = [..._documentFiles, newFileInfo]);
                  }
                }
              },
              onImageRemoved: (idx) {
                setState(() => _imageFiles.removeAt(idx));
              },
              onDocumentRemoved: (idx) {
                setState(() => _documentFiles.removeAt(idx));
              },
            ),
          ],
        ),
      ),
    );
  }
}
