import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/data_service.dart';
import '../../models/notice.dart';
import '../../models/press_release.dart';

class NewsPreviewSection extends StatelessWidget {
  const NewsPreviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? 40 : 80,
        right: isMobile ? 40 : 80,
        top: 80,
        bottom: 80,
      ),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            '새소식',
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
            future: Future.wait([
              dataService.getNoticeList(limit: 3),
              dataService.getPressReleaseList(limit: 3),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final notices = snapshot.data?[0] as List<Notice>? ?? [];
              final pressReleases = snapshot.data?[1] as List<PressRelease>? ?? [];

              final allNews = <_NewsItem>[];
              allNews.addAll(notices.map((n) => _NewsItem(
                    title: n.title,
                    date: n.date,
                    type: '공지사항',
                    color: Colors.blue,
                  )));
              allNews.addAll(pressReleases.map((p) => _NewsItem(
                    title: p.title,
                    date: p.date,
                    type: '보도자료',
                    color: Colors.orange,
                  )));

              allNews.sort((a, b) => b.date.compareTo(a.date));
              final displayNews = allNews.take(6).toList();

              if (displayNews.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(48),
                  child: Text(
                    '새소식이 없습니다.',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = isMobile ? 1 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: isMobile ? 2.5 : 1.5,
                    ),
                    itemCount: displayNews.length,
                    itemBuilder: (context, index) {
                      return _NewsCard(news: displayNews[index]);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NewsItem {
  final String title;
  final DateTime date;
  final String type;
  final Color color;

  _NewsItem({
    required this.title,
    required this.date,
    required this.type,
    required this.color,
  });
}

class _NewsCard extends StatelessWidget {
  final _NewsItem news;

  const _NewsCard({required this.news});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: news.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      news.type,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: news.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  news.title,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('yyyy.MM.dd').format(news.date),
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

