import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/data_service.dart';
import '../../models/rest_area.dart';

class BusinessHighlightsSection extends StatelessWidget {
  const BusinessHighlightsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? 40 : 80,
        right: isMobile ? 40 : 80,
        top: 80,
        bottom: 80,
      ),
      color: Colors.grey[50],
      child: Column(
        children: [
          Text(
            '주요 사업 분야',
            style: GoogleFonts.notoSans(
              fontSize: isMobile ? 32 : 48,
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
          const SizedBox(height: 60),
          FutureBuilder(
            future: dataService.getRestAreaList(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final restAreas = snapshot.data ?? [];
              final displayAreas = restAreas.take(3).toList();

              if (displayAreas.isEmpty) {
                // 더미 데이터 표시
                return _buildBusinessCards([
                  _BusinessItem(
                    title: '휴게소사업',
                    description: '고객 만족을 최우선으로 하는 휴게소 운영',
                    icon: Icons.restaurant,
                    color: Colors.blue,
                  ),
                  _BusinessItem(
                    title: '제조유통사업',
                    description: '품질과 신뢰를 바탕으로 한 제조 및 유통',
                    icon: Icons.factory,
                    color: Colors.green,
                  ),
                  _BusinessItem(
                    title: '식음료사업',
                    description: '고품질 식음료 제품 개발 및 공급',
                    icon: Icons.local_dining,
                    color: Colors.orange,
                  ),
                ], isMobile, isTablet);
              }

              return _buildRestAreaCards(displayAreas, isMobile, isTablet);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCards(
      List<_BusinessItem> items, bool isMobile, bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.1,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _BusinessCard(item: items[index]);
          },
        );
      },
    );
  }

  Widget _buildRestAreaCards(
      List<RestArea> restAreas, bool isMobile, bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.1,
          ),
          itemCount: restAreas.length,
          itemBuilder: (context, index) {
            return _RestAreaCard(restArea: restAreas[index]);
          },
        );
      },
    );
  }
}

class _BusinessItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _BusinessItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _BusinessCard extends StatelessWidget {
  final _BusinessItem item;

  const _BusinessCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 48,
              color: item.color,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            item.title,
            style: GoogleFonts.notoSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestAreaCard extends StatelessWidget {
  final RestArea restArea;

  const _RestAreaCard({required this.restArea});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 이미지
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: restArea.imageUrl != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.network(
                        restArea.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.restaurant, size: 48),
                          );
                        },
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.restaurant, size: 48),
                    ),
            ),
          ),
          // 텍스트
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    restArea.name,
                    style: GoogleFonts.notoSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (restArea.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      restArea.description!,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

