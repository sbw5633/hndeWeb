import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/firestore_service.dart';
import '../../models/business_type.dart';
import 'business_type_edit_page.dart';
import 'dynamic_business_page.dart';

class BusinessTypeListPage extends ConsumerStatefulWidget {
  const BusinessTypeListPage({super.key});

  @override
  ConsumerState<BusinessTypeListPage> createState() =>
      _BusinessTypeListPageState();
}

class _BusinessTypeListPageState extends ConsumerState<BusinessTypeListPage> {
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    // 페이지 로드 시 데이터가 없으면 자동으로 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitialize();
    });
  }

  Future<void> _checkAndInitialize() async {
    if (_isInitializing) return;
    
    final businessTypesAsync = ref.read(businessTypeListProvider);
    businessTypesAsync.whenData((items) {
      if (items.isEmpty && !_isInitializing) {
        _isInitializing = true;
        _initializeDefaultData(context, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final businessTypes = ref.watch(businessTypeListProvider);
    final userInfo = ref.watch(currentUserInfoProvider);

    return userInfo.when(
      data: (user) {
        final isAdmin = user?.isAdmin ?? false;

        if (!isAdmin) {
          return const Center(
            child: Text('관리자만 접근할 수 있습니다.'),
          );
        }

        return businessTypes.when(
          data: (items) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('주요사업 관리'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BusinessTypeEditPage(),
                      ),
                    ),
                  ),
                ],
              ),
              body: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('등록된 사업이 없습니다.'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('초기 데이터 추가'),
                            onPressed: () => _initializeDefaultData(context, ref),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      buildDefaultDragHandles: false,
                      itemCount: items.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        setState(() {
                          final item = items[oldIndex];
                          items.removeAt(oldIndex);
                          items.insert(newIndex, item);
                          // 순서 업데이트
                          for (int i = 0; i < items.length; i++) {
                            final updatedItem = BusinessType(
                              id: items[i].id,
                              name: items[i].name,
                              layoutType: items[i].layoutType,
                              order: i,
                              iconName: items[i].iconName,
                              colorHex: items[i].colorHex,
                              description: items[i].description,
                            );
                            ref
                                .read(businessTypeControllerProvider)
                                .update(updatedItem);
                          }
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _BusinessTypeListItem(
                          key: ValueKey(item.id),
                          item: item,
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BusinessTypeEditPage(
                                businessType: item,
                              ),
                            ),
                          ),
                          onDelete: () => _showDeleteDialog(context, ref, item),
                          onTap: () => _navigateToBusinessPage(context, item),
                        );
                      },
                    ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('오류: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    BusinessType item,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('${item.name}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(businessTypeControllerProvider).delete(item.id);
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _navigateToBusinessPage(BuildContext context, BusinessType item) {
    // 사업명에 따라 다른 페이지로 이동
    if (item.name.contains('휴게소')) {
      context.go('/rest-areas');
    } else if (item.name.contains('제조유통')) {
      context.go('/manufacturing-business');
    } else if (item.name.contains('식음료')) {
      context.go('/food-beverage-business');
    } else {
      // 기타 사업의 경우 레이아웃에 따라 동적 페이지 열기
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DynamicBusinessPage(businessType: item),
        ),
      );
    }
  }

  Future<void> _initializeDefaultData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      // Firestore에서 직접 확인 (중복 방지)
      final service = FirestoreService();
      final existingData = await service.getCollection(
        FirestoreCollections.businessTypes,
      );
      
      if (existingData.isNotEmpty) {
        _isInitializing = false;
        return;
      }

      // 초기 데이터 생성
      final defaultBusinessTypes = [
        BusinessType(
          id: 'rest_area_business',
          name: '휴게소사업',
          layoutType: 'layout1',
          order: 0,
          iconName: 'restaurant',
          colorHex: '#2196F3', // Blue
          description: '고객 만족을 최우선으로 하는 휴게소 운영',
        ),
        BusinessType(
          id: 'manufacturing_business',
          name: '제조유통사업',
          layoutType: 'layout1',
          order: 1,
          iconName: 'factory',
          colorHex: '#4CAF50', // Green
          description: '품질과 신뢰를 바탕으로 한 제조 및 유통',
        ),
        BusinessType(
          id: 'food_beverage_business',
          name: '식음료사업',
          layoutType: 'layout2',
          order: 2,
          iconName: 'local_dining',
          colorHex: '#FF9800', // Orange
          description: '고품질 식음료 제품 개발 및 공급',
        ),
      ];

      // 각 사업 타입 추가 (고정 ID 사용)
      for (final businessType in defaultBusinessTypes) {
        await ref.read(businessTypeControllerProvider).add(businessType);
      }

      _isInitializing = false;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초기 데이터가 자동으로 추가되었습니다.')),
        );
      }
    } catch (e) {
      _isInitializing = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초기 데이터 추가 실패: $e')),
        );
      }
    }
  }
}

class _BusinessTypeListItem extends StatelessWidget {
  final BusinessType item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _BusinessTypeListItem({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: 0,
          child: Icon(Icons.drag_handle, color: Colors.grey[600]),
        ),
        title: Text(item.name),
        subtitle: Text('레이아웃: ${item.layoutType}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: onTap,
              tooltip: '사업 페이지로 이동',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

