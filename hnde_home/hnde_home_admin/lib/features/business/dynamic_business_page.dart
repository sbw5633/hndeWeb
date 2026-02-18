import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/file_upload_service.dart';
import '../../models/business_category.dart';
import '../../models/business_type.dart';
import '../../models/manufacturing_business.dart';
import '../../models/food_beverage_business.dart';
import 'business_category_widgets.dart';

/// 동적 사업 페이지 (레이아웃 타입에 따라 다른 구조 사용)
class DynamicBusinessPage extends ConsumerStatefulWidget {
  final BusinessType businessType;

  const DynamicBusinessPage({
    super.key,
    required this.businessType,
  });

  @override
  ConsumerState<DynamicBusinessPage> createState() =>
      _DynamicBusinessPageState();
}

class _DynamicBusinessPageState extends ConsumerState<DynamicBusinessPage> {
  String? _mainImageUrl;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  List<BusinessCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    // 초기 데이터는 비어있는 상태로 시작 (새로 추가한 사업이므로)
    _categories = [];
    _mainImageUrl = null;
    // 기존 데이터가 있으면 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }

  Future<void> _loadExistingData() async {
    try {
      final dataAsync = ref.read(dynamicBusinessDataProvider(widget.businessType.id));
      dataAsync.when(
        data: (data) {
          if (data != null && mounted) {
            final layoutType = data['layoutType'] as String? ?? widget.businessType.layoutType;
            
            if (layoutType == 'layout1') {
              // 제조유통사업 스타일
              final business = ManufacturingBusiness.fromFirestore(data);
              setState(() {
                _mainImageUrl = business.mainImageUrl;
                _categories = business.categories;
              });
            } else {
              // 식음료사업 스타일
              final business = FoodBeverageBusiness.fromFirestore(data);
              setState(() {
                _mainImageUrl = business.mainImageUrl;
                _categories = business.categories;
              });
            }
          }
        },
        loading: () {},
        error: (_, __) {},
      );
    } catch (e) {
      print('데이터 로드 오류: $e');
    }
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

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      // 동적 사업 데이터를 businessType.id를 docId로 사용하여 저장
      final controller = ref.read(dynamicBusinessDataControllerProvider);
      
      // 레이아웃 타입에 따라 다른 모델로 변환
      Map<String, dynamic> businessData;
      if (widget.businessType.layoutType == 'layout1') {
        // 제조유통사업 스타일 (ManufacturingBusiness)
        final business = ManufacturingBusiness(
          mainImageUrl: _mainImageUrl,
          categories: _categories,
        );
        businessData = business.toFirestore();
      } else {
        // 식음료사업 스타일 (FoodBeverageBusiness)
        final business = FoodBeverageBusiness(
          mainImageUrl: _mainImageUrl,
          categories: _categories,
        );
        businessData = business.toFirestore();
      }

      // businessType.id를 docId로 사용하여 저장
      await controller.save(
        widget.businessType.id,
        widget.businessType.layoutType,
        businessData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다.')),
        );
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
        final isAdmin = user?.isAdmin ?? false;
        final canEdit = isAdmin;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.businessType.name),
            actions: [
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _isLoading ? null : _save,
                ),
            ],
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
                            const Expanded(
                              child: Text(
                                '메인 관리자만 수정할 수 있습니다.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // 메인 이미지
                    const Text(
                      '메인 이미지',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_mainImageUrl != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _mainImageUrl!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (canEdit)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white),
                                onPressed: () {
                                  setState(() => _mainImageUrl = null);
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      )
                    else if (canEdit)
                      GestureDetector(
                        onTap: _isUploadingImage ? null : _pickMainImage,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: _isUploadingImage
                              ? const Center(child: CircularProgressIndicator())
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 48),
                                      SizedBox(height: 8),
                                      Text('이미지 추가'),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    // 분류 관리
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '분류',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (canEdit)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('분류 추가'),
                            onPressed: _addCategory,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._categories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      return CategoryCard(
                        key: ValueKey(category.id),
                        category: category,
                        onUpdate: (updated) {
                          setState(() {
                            _categories[index] = updated;
                          });
                        },
                        onDelete: () => _removeCategory(index),
                        canEdit: canEdit,
                      );
                    }),
                    if (_categories.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: const Center(
                          child: Text(
                            '등록된 분류가 없습니다.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
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
  }
}

