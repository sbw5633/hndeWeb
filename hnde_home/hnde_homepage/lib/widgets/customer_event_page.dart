import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_event.dart';

class CustomerEventPage extends StatefulWidget {
  final List<CustomerEvent> events;

  const CustomerEventPage({
    super.key,
    required this.events,
  });

  @override
  State<CustomerEventPage> createState() => _CustomerEventPageState();
}

class _CustomerEventPageState extends State<CustomerEventPage> {
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _pastScrollController = ScrollController();
  bool _showActiveLeftArrow = false;
  bool _showActiveRightArrow = true;
  bool _showPastLeftArrow = false;
  bool _showPastRightArrow = true;
  bool _isPastEventsExpanded = false; // 지난 이벤트 펼침/접힘 상태

  @override
  void initState() {
    super.initState();
    _activeScrollController.addListener(() => _updateActiveArrowVisibility());
    _pastScrollController.addListener(() => _updatePastArrowVisibility());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateActiveArrowVisibility();
      _updatePastArrowVisibility();
    });
  }

  @override
  void dispose() {
    _activeScrollController.dispose();
    _pastScrollController.dispose();
    super.dispose();
  }

  void _updateActiveArrowVisibility() {
    if (!_activeScrollController.hasClients) return;
    final maxScroll = _activeScrollController.position.maxScrollExtent;
    final currentScroll = _activeScrollController.position.pixels;
    setState(() {
      _showActiveLeftArrow = currentScroll > 0;
      _showActiveRightArrow = currentScroll < maxScroll - 10;
    });
  }

  void _updatePastArrowVisibility() {
    if (!_pastScrollController.hasClients) return;
    final maxScroll = _pastScrollController.position.maxScrollExtent;
    final currentScroll = _pastScrollController.position.pixels;
    setState(() {
      _showPastLeftArrow = currentScroll > 0;
      _showPastRightArrow = currentScroll < maxScroll - 10;
    });
  }

  void _scrollLeft(ScrollController controller) {
    if (!controller.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 96; // 패딩 제외한 전체 너비
    controller.animateTo(
      (controller.offset - cardWidth - 24)
          .clamp(0.0, controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight(ScrollController controller) {
    if (!controller.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 96; // 패딩 제외한 전체 너비
    controller.animateTo(
      (controller.offset + cardWidth + 24)
          .clamp(0.0, controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeEvents = widget.events.where((e) => e.isActive).toList();
    final pastEvents = widget.events.where((e) => !e.isActive).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 96; // 패딩 제외한 전체 너비

    // 진행중인 이벤트를 3개씩 묶음으로 나누기
    final activeChunks = <List<CustomerEvent>>[];
    for (int i = 0; i < activeEvents.length; i += 3) {
      activeChunks.add(activeEvents.sublist(
        i,
        i + 3 > activeEvents.length ? activeEvents.length : i + 3,
      ));
    }

    // 지난 이벤트를 3개씩 묶음으로 나누기
    final pastChunks = <List<CustomerEvent>>[];
    for (int i = 0; i < pastEvents.length; i += 3) {
      pastChunks.add(pastEvents.sublist(
        i,
        i + 3 > pastEvents.length ? pastEvents.length : i + 3,
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
              '고객이벤트',
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
            // 진행중인 이벤트
            if (activeEvents.isNotEmpty) ...[
              Text(
                '진행중인 이벤트',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 240 * 3 + 48, // 카드 높이 * 3 + 간격
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _activeScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: activeChunks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final chunk = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index < activeChunks.length - 1 ? 24 : 0,
                            ),
                            child: SizedBox(
                              width: cardWidth, // 한 줄에 카드 1개
                              child: Column(
                                children:
                                    chunk.asMap().entries.map((chunkEntry) {
                                  final chunkIndex = chunkEntry.key;
                                  final event = chunkEntry.value;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: chunkIndex < chunk.length - 1
                                          ? 24
                                          : 0,
                                    ),
                                    child: SizedBox(
                                      width: cardWidth,
                                      height: 240,
                                      child: _EventCard(
                                          event: event, isActive: true),
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
                    if (_showActiveLeftArrow)
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
                              onPressed: () =>
                                  _scrollLeft(_activeScrollController),
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    // 우측 화살표
                    if (_showActiveRightArrow)
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
                              onPressed: () =>
                                  _scrollRight(_activeScrollController),
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
            // 지난 이벤트
            if (pastEvents.isNotEmpty) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    _isPastEventsExpanded = !_isPastEventsExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '지난 이벤트',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      Icon(
                        _isPastEventsExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isPastEventsExpanded
                    ? Column(
                        children: [
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 240 * 3 + 48, // 카드 높이 * 3 + 간격
                            child: Stack(
                              children: [
                                SingleChildScrollView(
                                  controller: _pastScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children:
                                        pastChunks.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final chunk = entry.value;
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right: index < pastChunks.length - 1
                                              ? 24
                                              : 0,
                                        ),
                                        child: SizedBox(
                                          width: cardWidth, // 한 줄에 카드 1개
                                          child: Column(
                                            children: chunk
                                                .asMap()
                                                .entries
                                                .map((chunkEntry) {
                                              final chunkIndex = chunkEntry.key;
                                              final event = chunkEntry.value;
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: chunkIndex <
                                                          chunk.length - 1
                                                      ? 24
                                                      : 0,
                                                ),
                                                child: SizedBox(
                                                  width: cardWidth,
                                                  height: 240,
                                                  child: _EventCard(
                                                      event: event,
                                                      isActive: false),
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
                                if (_showPastLeftArrow)
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
                                          icon: const Icon(Icons.chevron_left,
                                              size: 32),
                                          onPressed: () => _scrollLeft(
                                              _pastScrollController),
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ),
                                // 우측 화살표
                                if (_showPastRightArrow)
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
                                          icon: const Icon(Icons.chevron_right,
                                              size: 32),
                                          onPressed: () => _scrollRight(
                                              _pastScrollController),
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
            if (widget.events.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Text('등록된 이벤트가 없습니다.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CustomerEvent event;
  final bool isActive;

  const _EventCard({
    required this.event,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.orange : Colors.grey[300]!,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isActive ? 0.08 : 0.03),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일 이미지
              if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    event.imageUrl!,
                    width: 150,
                    height: 208,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 150,
                        height: 208,
                        color: Colors.grey[200],
                        child: const Icon(Icons.event, size: 40),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 150,
                  height: 208,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event, size: 40),
                ),
              const SizedBox(width: 16),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '진행중',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (isActive) const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                event.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.blue[900]
                                      : Colors.grey[700],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.content,
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
                    // 날짜
                    Row(
                      children: [
                        Icon(Icons.date_range,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${DateFormat('yyyy.MM.dd').format(event.startDate)} ~ ${DateFormat('yyyy.MM.dd').format(event.endDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
