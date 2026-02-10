import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/file_upload_service.dart';
import '../../models/manufacturing_business.dart';
import '../../models/business_category.dart';
import 'business_category_widgets.dart';

class ManufacturingBusinessPage extends ConsumerStatefulWidget {
  const ManufacturingBusinessPage({super.key});

  @override
  ConsumerState<ManufacturingBusinessPage> createState() =>
      _ManufacturingBusinessPageState();
}

class _ManufacturingBusinessPageState
    extends ConsumerState<ManufacturingBusinessPage> {
  String? _mainImageUrl;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  List<BusinessCategory> _categories = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final business = ref.read(manufacturingBusinessProvider);
    business.whenData((data) {
      if (data != null && !_isInitialized) {
        setState(() {
          _mainImageUrl = data.mainImageUrl;
          _categories = List<BusinessCategory>.from(data.categories)
            ..sort((a, b) => a.order.compareTo(b.order));
          _isInitialized = true;
        });
      }
    });
  }

  Future<void> _pickMainImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final uploadService = FileUploadService();
      final result = await uploadService.uploadFile(pickedFile);
      if (result != null && result['view_url'] != null) {
        setState(() {
          _mainImageUrl = uploadService.getViewUrl(result['view_url']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  void _addCategory() {
    setState(() {
      _categories.add(BusinessCategory(
        id: const Uuid().v4(),
        name: '',
        items: [],
        order: _categories.length,
      ));
    });
  }

  void _removeCategory(int index) {
    setState(() {
      _categories.removeAt(index);
      // 순서 재정렬
      for (int i = 0; i < _categories.length; i++) {
        _categories[i] = BusinessCategory(
          id: _categories[i].id,
          name: _categories[i].name,
          items: _categories[i].items,
          order: i,
        );
      }
    });
  }

  void _updateCategory(int index, BusinessCategory category) {
    setState(() {
      _categories[index] = category;
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final business = ManufacturingBusiness(
        mainImageUrl: _mainImageUrl,
        categories: _categories,
      );
      await ref.read(manufacturingBusinessControllerProvider).save(business);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다.')),
        );
        // 저장 후 provider 새로고침 및 상태 업데이트
        ref.invalidate(manufacturingBusinessProvider);
        final updatedBusiness = await ref.read(manufacturingBusinessProvider.future);
        if (updatedBusiness != null && mounted) {
          setState(() {
            _mainImageUrl = updatedBusiness.mainImageUrl;
            _categories = List<BusinessCategory>.from(updatedBusiness.categories)
              ..sort((a, b) => a.order.compareTo(b.order));
          });
        }
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
    final businessAsync = ref.watch(manufacturingBusinessProvider);
    final userInfo = ref.watch(currentUserInfoProvider);

    // business 데이터 변경 감지
    ref.listen<AsyncValue<ManufacturingBusiness?>>(
      manufacturingBusinessProvider,
      (previous, next) {
        next.whenData((business) {
          if (business != null && mounted) {
            final sortedCategories = List<BusinessCategory>.from(business.categories)
              ..sort((a, b) => a.order.compareTo(b.order));
            
            // 저장 후에는 업데이트하지 않음 (편집 중인 내용 유지)
            // 초기 로드 시에만 업데이트
            if (!_isInitialized) {
              setState(() {
                _mainImageUrl = business.mainImageUrl;
                _categories = sortedCategories;
                _isInitialized = true;
              });
            }
          }
        });
      },
    );

    return businessAsync.when(
      data: (business) {

        return userInfo.when(
          data: (user) {
            final isAdmin = user?.isAdmin ?? false;
            final canEdit = isAdmin;

            return Scaffold(
              appBar: AppBar(
                title: const Text('제조유통사업'),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AbsorbPointer(
                  absorbing: !canEdit,
                  child: Opacity(
                    opacity: canEdit ? 1.0 : 0.6,
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
                                    '메인 관리자만 수정할 수 있습니다.',
                                    style: TextStyle(color: Colors.orange[900]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 메인 이미지
                        const Text(
                          '메인 이미지',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: canEdit && !_isUploadingImage ? _pickMainImage : null,
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator())
                                : _mainImageUrl != null
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              _mainImageUrl!,
                                              width: double.infinity,
                                              height: 200,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.error),
                                            ),
                                          ),
                                          if (canEdit)
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.close,
                                                      color: Colors.white, size: 20),
                                                  onPressed: () {
                                                    setState(() {
                                                      _mainImageUrl = null;
                                                    });
                                                  },
                                                ),
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
                        // 분류 관리
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '분류',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (canEdit)
                              TextButton.icon(
                                onPressed: _addCategory,
                                icon: const Icon(Icons.add),
                                label: const Text('분류 추가'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_categories.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text('등록된 분류가 없습니다.'),
                            ),
                          )
                        else
                          ..._categories.asMap().entries.map((entry) {
                            final index = entry.key;
                            final category = entry.value;
                            return CategoryCard(
                              category: category,
                              onUpdate: (updated) => _updateCategory(index, updated),
                              onDelete: canEdit ? () => _removeCategory(index) : null,
                              canEdit: canEdit,
                            );
                          }),
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
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Scaffold(
            body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('데이터를 불러올 수 없습니다.')),
      ),
    );
  }
}


