import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/data_service.dart';
import '../../models/notice.dart';
import '../../models/press_release.dart';
import '../../models/location.dart';
import '../../models/business_type.dart';

class MinimalHomeContent extends StatelessWidget {
  final Function(String menuId, String? subMenuId) onMenuTap;

  const MinimalHomeContent({
    super.key,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final horizontalPadding = (screenWidth * 0.1).clamp(16.0, 80.0);
    final dataService = DataService();
    
    return Container(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: 60,
        bottom: 80,
      ),
      child: Column(
        children: [
          // 주요 사업 분야 (간단히)
          _BusinessQuickLinks(
            dataService: dataService,
            isMobile: isMobile,
            onMenuTap: onMenuTap,
          ),
          const SizedBox(height: 80),
          // 최신 소식
          _LatestNews(
            dataService: dataService,
            isMobile: isMobile,
            onMenuTap: onMenuTap,
          ),
          const SizedBox(height: 80),
          // 연락처 정보
          _ContactInfo(
            dataService: dataService,
            isMobile: isMobile,
            onMenuTap: onMenuTap,
          ),
        ],
      ),
    );
  }
}

// 주요 사업 분야 빠른 링크
class _BusinessQuickLinks extends StatelessWidget {
  final DataService dataService;
  final bool isMobile;
  final Function(String menuId, String? subMenuId) onMenuTap;

  const _BusinessQuickLinks({
    required this.dataService,
    required this.isMobile,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BusinessType>>(
      future: dataService.getBusinessTypeList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final businessTypes = snapshot.data ?? [];
        
        // 기존 하드코딩된 사업 목록 (fallback)
        if (businessTypes.isEmpty) {
          return FutureBuilder(
            future: dataService.getRestAreaList(),
            builder: (context, restAreaSnapshot) {
              final restAreas = restAreaSnapshot.data ?? [];
              final hasRestAreas = restAreas.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '주요 사업',
                    style: GoogleFonts.notoSans(
                      fontSize: isMobile ? 28 : 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 3,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 40),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useColumn = constraints.maxWidth < 600;
                      
                      if (useColumn) {
                        return Column(
                          children: [
                            _BusinessLinkCard(
                              title: '휴게소사업',
                              subtitle: hasRestAreas ? '${restAreas.length}개 운영' : '운영 중',
                              icon: Icons.restaurant,
                              color: Colors.blue,
                              onTap: () => onMenuTap('business', 'restarea'),
                            ),
                            const SizedBox(height: 20),
                            _BusinessLinkCard(
                              title: '제조유통사업',
                              subtitle: '품질과 신뢰',
                              icon: Icons.factory,
                              color: Colors.green,
                              onTap: () => onMenuTap('business', 'manufacturing'),
                            ),
                            const SizedBox(height: 20),
                            _BusinessLinkCard(
                              title: '식음료사업',
                              subtitle: '고품질 제품',
                              icon: Icons.local_dining,
                              color: Colors.orange,
                              onTap: () => onMenuTap('business', 'food'),
                            ),
                          ],
                        );
                      }
                      
                      return Row(
                        children: [
                          Expanded(
                            child: _BusinessLinkCard(
                              title: '휴게소사업',
                              subtitle: hasRestAreas ? '${restAreas.length}개 운영' : '운영 중',
                              icon: Icons.restaurant,
                              color: Colors.blue,
                              onTap: () => onMenuTap('business', 'restarea'),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _BusinessLinkCard(
                              title: '제조유통사업',
                              subtitle: '품질과 신뢰',
                              icon: Icons.factory,
                              color: Colors.green,
                              onTap: () => onMenuTap('business', 'manufacturing'),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _BusinessLinkCard(
                              title: '식음료사업',
                              subtitle: '고품질 제품',
                              icon: Icons.local_dining,
                              color: Colors.orange,
                              onTap: () => onMenuTap('business', 'food'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '주요 사업',
              style: GoogleFonts.notoSans(
                fontSize: isMobile ? 28 : 36,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 3,
              color: Colors.orange,
            ),
            const SizedBox(height: 40),
            LayoutBuilder(
              builder: (context, constraints) {
                // 폭이 600px 미만이면 Column으로 배치
                final useColumn = constraints.maxWidth < 600;
                
                if (useColumn) {
                  return Column(
                    children: businessTypes.map((businessType) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: SizedBox(
                          width: double.infinity, // 전체 너비 사용
                          child: _BusinessLinkCard(
                            title: businessType.name,
                            subtitle: businessType.description ?? '',
                            icon: _getIcon(businessType.iconName),
                            color: _getColor(businessType.colorHex),
                            onTap: () => _navigateToBusiness(businessType),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }
                
                return Row(
                  children: businessTypes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final businessType = entry.value;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index < businessTypes.length - 1 ? 20 : 0,
                        ),
                        child: _BusinessLinkCard(
                          title: businessType.name,
                          subtitle: businessType.description ?? '',
                          icon: _getIcon(businessType.iconName),
                          color: _getColor(businessType.colorHex),
                          onTap: () => _navigateToBusiness(businessType),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getIcon(String? iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'factory':
        return Icons.factory;
      case 'local_dining':
        return Icons.local_dining;
      default:
        return Icons.business;
    }
  }

  Color _getColor(String? colorHex) {
    if (colorHex == null) return Colors.blue;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  void _navigateToBusiness(BusinessType businessType) {
    // 사업명에 따라 다른 메뉴로 이동
    if (businessType.name.contains('휴게소')) {
      onMenuTap('business', 'restarea');
    } else if (businessType.name.contains('제조유통')) {
      onMenuTap('business', 'manufacturing');
    } else if (businessType.name.contains('식음료')) {
      onMenuTap('business', 'food');
    } else {
      // 기타 사업의 경우 기본적으로 business 메뉴로 이동
      onMenuTap('business', null);
    }
  }
}

class _BusinessLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BusinessLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220, // 고정 높이로 사이즈 통일
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 20),
            // 제목: 너비에 맞게 축소
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            // 내용: 1줄만 표시하고 ellipsis
            Text(
              subtitle,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// 최신 소식
class _LatestNews extends StatelessWidget {
  final DataService dataService;
  final bool isMobile;
  final Function(String menuId, String? subMenuId) onMenuTap;

  const _LatestNews({
    required this.dataService,
    required this.isMobile,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        dataService.getNoticeList(limit: 3),
        dataService.getPressReleaseList(limit: 3),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final notices = snapshot.data?[0] as List<Notice>? ?? [];
        final pressReleases = snapshot.data?[1] as List<PressRelease>? ?? [];

        final allNews = <_NewsItem>[];
        allNews.addAll(notices.map((n) => _NewsItem(
              title: n.title,
              date: n.date,
              type: '공지사항',
              menuId: 'community',
              subMenuId: 'notice',
            )));
        allNews.addAll(pressReleases.map((p) => _NewsItem(
              title: p.title,
              date: p.date,
              type: '보도자료',
              menuId: 'pr',
              subMenuId: 'press',
            )));

        allNews.sort((a, b) => b.date.compareTo(a.date));
        final displayNews = allNews.take(5).toList();

        if (displayNews.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '최신 소식',
              style: GoogleFonts.notoSans(
                fontSize: isMobile ? 28 : 36,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 3,
              color: Colors.orange,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: displayNews.asMap().entries.map((entry) {
                  final index = entry.key;
                  final news = entry.value;
                  final isLast = index == displayNews.length - 1;
                  return Container(
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                    ),
                    child: InkWell(
                      onTap: () => onMenuTap(news.menuId, news.subMenuId),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: news.type == '공지사항'
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                news.type,
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: news.type == '공지사항'
                                      ? Colors.blue[700]
                                      : Colors.orange[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                news.title,
                                style: GoogleFonts.notoSans(
                                  fontSize: 15,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              DateFormat('yyyy.MM.dd').format(news.date),
                              style: GoogleFonts.notoSans(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NewsItem {
  final String title;
  final DateTime date;
  final String type;
  final String menuId;
  final String subMenuId;

  _NewsItem({
    required this.title,
    required this.date,
    required this.type,
    required this.menuId,
    required this.subMenuId,
  });
}

// 연락처 정보
class _ContactInfo extends StatelessWidget {
  final DataService dataService;
  final bool isMobile;
  final Function(String menuId, String? subMenuId) onMenuTap;

  const _ContactInfo({
    required this.dataService,
    required this.isMobile,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocationInfo?>(
      future: dataService.getLocation(),
      builder: (context, snapshot) {
        final location = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '찾아오시는 길',
                      style: GoogleFonts.notoSans(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (location != null) ...[
                      _InfoRow(
                        icon: Icons.location_on,
                        text: location.address,
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.phone,
                        text: location.phone,
                      ),
                    ] else ...[
                      _InfoRow(
                        icon: Icons.location_on,
                        text: '서울특별시 강남구 대치동',
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.phone,
                        text: '02-1234-5678',
                      ),
                    ],
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 40),
                ElevatedButton(
                  onPressed: () => onMenuTap('company', 'location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '자세히 보기',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.notoSans(
              fontSize: 15,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }
}

