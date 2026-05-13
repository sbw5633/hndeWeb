import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/file_upload_service.dart';
import '../../models/rest_area.dart';
import 'rest_area_detail_edit_tab.dart';

class RestAreaEditPage extends ConsumerStatefulWidget {
  final RestArea? restArea;

  const RestAreaEditPage({super.key, this.restArea});

  @override
  ConsumerState<RestAreaEditPage> createState() => _RestAreaEditPageState();
}

class _RestAreaEditPageState extends ConsumerState<RestAreaEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _imageUrl;
  bool _isLoading = false;
  RestAreaDetail? _detail;

  @override
  void initState() {
    super.initState();
    if (widget.restArea != null) {
      _nameController.text = widget.restArea!.name;
      _descriptionController.text = widget.restArea!.description ?? '';
      _imageUrl = widget.restArea!.imageUrl;
      _detail = widget.restArea!.detail;
    } else {
      _detail = RestAreaDetail(
        intro: '',
        address: null,
        mapAddress: null,
        status: null,
        awards: [],
        stores: [],
        foods: [],
        facilities: [],
        additionalItems: [],
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _imageUrl = uploadService.getViewUrl(result['view_url']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _detail == null) return;

    setState(() => _isLoading = true);
    try {
      // 새로 추가하는 경우 order를 기존 목록의 최대값 + 1로 설정
      int order = widget.restArea?.order ?? 0;
      if (widget.restArea == null) {
        final existingAreas = await ref.read(restAreaListProvider.future);
        if (existingAreas.isNotEmpty) {
          order = existingAreas.map((a) => a.order).reduce((a, b) => a > b ? a : b) + 1;
        }
      }

      final restArea = RestArea(
        id: widget.restArea?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imageUrl: _imageUrl,
        detail: _detail!,
        order: order,
      );

      if (widget.restArea == null) {
        await ref.read(restAreaControllerProvider).add(restArea);
      } else {
        await ref.read(restAreaControllerProvider).update(restArea);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = ref.watch(currentUserInfoProvider);
    
    return userInfo.when(
      data: (user) {
        final isRestAreaManager = user?.isRestAreaManager ?? false;
        final isApproved = user?.isApproved ?? false;
        final canEdit = isApproved && (
            !isRestAreaManager || 
            (isRestAreaManager && widget.restArea != null && 
             user?.restAreaId == widget.restArea!.id));
        
        // 휴게소 관리자가 본인 휴게소가 아닌 경우 접근 불가
        if (isRestAreaManager && widget.restArea != null && 
            user?.restAreaId != widget.restArea!.id) {
          return Scaffold(
            appBar: AppBar(title: const Text('휴게소 수정')),
            body: const Center(
              child: Text('본인 소속 휴게소만 수정할 수 있습니다.'),
            ),
          );
        }
        
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restArea == null ? '휴게소 추가' : '휴게소 수정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
            child: AbsorbPointer(
              absorbing: !canEdit,
              child: Opacity(
                opacity: canEdit ? 1.0 : 0.6,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                      if (!canEdit)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '본인 소속 휴게소만 수정할 수 있습니다.',
                                  style: TextStyle(color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '휴게소 이름 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? '이름을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '간단 설명',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                        onTap: canEdit ? _pickImage : null,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _imageUrl != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _imageUrl!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                        onPressed: canEdit ? () {
                                  setState(() => _imageUrl = null);
                                        } : null,
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 48),
                              SizedBox(height: 8),
                              Text('이미지 선택'),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              if (_detail != null)
                RestAreaDetailEditTab(
                  detail: _detail!,
                  onDetailChanged: (detail) {
                            if (canEdit) {
                    setState(() => _detail = detail);
                            }
                  },
                ),
              const SizedBox(height: 24),
                      if (canEdit)
              FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ],
          ),
        ),
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
          appBar: AppBar(title: const Text('휴게소 수정')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('휴게소 수정')),
          body: const Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
      ),
    );
  }
}

