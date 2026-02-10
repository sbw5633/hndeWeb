import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/data_service.dart';
import '../../models/notice.dart';
import '../../models/press_release.dart';
import '../../models/location.dart';

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
    final dataService = DataService();

    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? 40 : 80,
        right: isMobile ? 40 : 80,
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
    return FutureBuilder(
      future: dataService.getRestAreaList(),
      builder: (context, snapshot) {
        final restAreas = snapshot.data ?? [];
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
            Row(
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
            ),
          ],
        );
      },
    );
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
            Text(
              title,
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: Colors.grey[600],
              ),
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
    return FutureBuilder(
      future: dataService.getLocation(),
      builder: (context, snapshot) {
        final location = snapshot.data as LocationInfo?;

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

