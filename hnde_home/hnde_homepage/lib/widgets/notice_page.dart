import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notice.dart';

class NoticePage extends StatefulWidget {
  final List<Notice> notices;

  const NoticePage({
    super.key,
    required this.notices,
  });

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrowVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateArrowVisibility();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrowVisibility() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    setState(() {
      _showLeftArrow = currentScroll > 0;
      _showRightArrow = currentScroll < maxScroll - 10;
    });
  }

  void _scrollLeft() {
    if (!_scrollController.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 96; // 패딩 제외한 전체 너비
    _scrollController.animateTo(
      (_scrollController.offset - cardWidth - 24)
          .clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    if (!_scrollController.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 96; // 패딩 제외한 전체 너비
    _scrollController.animateTo(
      (_scrollController.offset + cardWidth + 24)
          .clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 96; // 패딩(48*2) 제외한 전체 너비

    // 중요 공지와 일반 공지 분리
    final importantNotices =
        widget.notices.where((n) => n.isImportant).toList();
    final normalNotices = widget.notices.where((n) => !n.isImportant).toList();

    // 3개씩 묶음으로 나누기
    final chunks = <List<Notice>>[];
    final allNotices = [...importantNotices, ...normalNotices];
    for (int i = 0; i < allNotices.length; i += 3) {
      chunks.add(allNotices.sublist(
        i,
        i + 3 > allNotices.length ? allNotices.length : i + 3,
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              '공지사항',
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
            // 공지사항 목록 (좌우 스크롤)
            if (widget.notices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Text('등록된 공지사항이 없습니다.'),
                ),
              )
            else
              SizedBox(
                height: 200 * 3 + 48, // 카드 높이 * 3 + 간격
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: chunks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final chunk = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index < chunks.length - 1 ? 24 : 0,
                            ),
                            child: SizedBox(
                              width: cardWidth, // 한 줄에 카드 1개
                              child: Column(
                                children:
                                    chunk.asMap().entries.map((chunkEntry) {
                                  final chunkIndex = chunkEntry.key;
                                  final notice = chunkEntry.value;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: chunkIndex < chunk.length - 1
                                          ? 24
                                          : 0,
                                    ),
                                    child: SizedBox(
                                      width: cardWidth,
                                      height: 200,
                                      child: _NoticeCard(notice: notice),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // 좌측 화살표
                    if (_showLeftArrow)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.chevron_left, size: 32),
                              onPressed: _scrollLeft,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    // 우측 화살표
                    if (_showRightArrow)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.chevron_right, size: 32),
                              onPressed: _scrollRight,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;

  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: notice.isImportant ? Colors.orange[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notice.isImportant ? Colors.orange : Colors.grey[300]!,
          width: notice.isImportant ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // 상세 페이지로 이동 (나중에 구현)
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (notice.isImportant)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '중요',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (notice.isImportant) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notice.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: notice.isImportant
                                ? Colors.orange[900]
                                : Colors.blue[900],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notice.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // 날짜 및 작성자
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('yyyy.MM.dd').format(notice.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (notice.author != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      notice.author!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

