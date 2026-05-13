import 'package:flutter/material.dart';
import '../models/food_beverage_business.dart';
import '../models/business_category.dart';

class FoodBeverageBusinessPage extends StatelessWidget {
  final FoodBeverageBusiness? data;
  final String? title; // 동적 제목 지원

  const FoodBeverageBusinessPage({
    super.key,
    this.data,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final displayData = data ?? FoodBeverageBusiness.getDummyData();
    final pageTitle = title ?? '식음료사업'; // 동적 제목 또는 기본값
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              pageTitle,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 4,
              color: Colors.orange,
            ),
            const SizedBox(height: 40),
            // 메인 이미지 (있는 경우에만 표시)
            if (displayData.mainImageUrl != null && displayData.mainImageUrl!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 300,
                  maxHeight: 600,
                ),
                margin: const EdgeInsets.only(bottom: 40),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    displayData.mainImageUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.image,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            // 분류별 표시
            if (displayData.categories.isNotEmpty)
              ...displayData.categories
                  .where((cat) => cat.name.isNotEmpty && cat.items.isNotEmpty)
                  .map((category) => _CategorySection(category: category)),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final BusinessCategory category;

  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    final sortedItems = List<CategoryItem>.from(category.items)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 분류 제목
        Text(
          category.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 24),
        // 항목들
        ...sortedItems.map((item) => _CategoryItemCard(item: item)),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _CategoryItemCard extends StatelessWidget {
  final CategoryItem item;

  const _CategoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 좌측 이미지
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.imageUrl!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
          // 우측 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 구분 (가장 위)
                if (item.type != null && item.type!.isNotEmpty)
                  Text(
                    item.type!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (item.type != null && item.type!.isNotEmpty) const SizedBox(height: 8),
                // 제목
                if (item.title != null && item.title!.isNotEmpty)
                  Text(
                    item.title!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                if (item.title != null && item.title!.isNotEmpty) const SizedBox(height: 12),
                // 구분선
                if ((item.title != null && item.title!.isNotEmpty) ||
                    (item.content != null && item.content!.isNotEmpty))
                  Divider(color: Colors.grey[300]),
                if ((item.title != null && item.title!.isNotEmpty) ||
                    (item.content != null && item.content!.isNotEmpty))
                  const SizedBox(height: 12),
                // 내용
                if (item.content != null && item.content!.isNotEmpty)
                  Text(
                    item.content!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.6,
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
