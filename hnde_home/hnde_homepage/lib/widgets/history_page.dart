import 'package:flutter/material.dart';
import '../models/history.dart';

enum HistoryPeriod {
  recent,      // 2020년~
  decade2010,  // 2010~2020
  decade2000,  // 2000~2010
  before2000,  // 2000년 이전
}

class HistoryPage extends StatefulWidget {
  final List<HistoryItem> historyItems;

  const HistoryPage({
    super.key,
    required this.historyItems,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryPeriod _selectedPeriod = HistoryPeriod.recent;
  bool _hasInitialized = false;

  @override
  void didUpdateWidget(HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 데이터가 변경되면 초기 탭 재선택
    if (oldWidget.historyItems != widget.historyItems) {
      _selectInitialPeriod();
    }
  }

  @override
  void initState() {
    super.initState();
    // 첫 빌드 후 초기 탭 선택
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasInitialized) {
        _hasInitialized = true;
        _selectInitialPeriod();
      }
    });
  }

  void _selectInitialPeriod() {
    HistoryPeriod newPeriod;
    
    if (widget.historyItems.isEmpty) {
      newPeriod = HistoryPeriod.recent;
    } else {
      // 각 기간별로 데이터가 있는지 확인 (최신순으로)
      final hasRecent = widget.historyItems.any((item) {
        final year = int.tryParse(item.year) ?? 0;
        return year >= 2020;
      });
      if (hasRecent) {
        newPeriod = HistoryPeriod.recent;
      } else {
        final hasDecade2010 = widget.historyItems.any((item) {
          final year = int.tryParse(item.year) ?? 0;
          return year >= 2010 && year < 2020;
        });
        if (hasDecade2010) {
          newPeriod = HistoryPeriod.decade2010;
        } else {
          final hasDecade2000 = widget.historyItems.any((item) {
            final year = int.tryParse(item.year) ?? 0;
            return year >= 2000 && year < 2010;
          });
          if (hasDecade2000) {
            newPeriod = HistoryPeriod.decade2000;
          } else {
            final hasBefore2000 = widget.historyItems.any((item) {
              final year = int.tryParse(item.year) ?? 0;
              return year < 2000;
            });
            if (hasBefore2000) {
              newPeriod = HistoryPeriod.before2000;
            } else {
              newPeriod = HistoryPeriod.recent;
            }
          }
        }
      }
    }

    if (newPeriod != _selectedPeriod) {
      setState(() {
        _selectedPeriod = newPeriod;
      });
    }
  }

  List<HistoryItem> _getFilteredItems() {
    return widget.historyItems.where((item) {
      final year = int.tryParse(item.year) ?? 0;
      
      switch (_selectedPeriod) {
        case HistoryPeriod.recent:
          return year >= 2020;
        case HistoryPeriod.decade2010:
          return year >= 2010 && year < 2020;
        case HistoryPeriod.decade2000:
          return year >= 2000 && year < 2010;
        case HistoryPeriod.before2000:
          return year < 2000;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.historyItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Text(
            '등록된 연혁이 없습니다.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    final filteredItems = _getFilteredItems();
    final groupedHistory = HistoryData.groupByYear(filteredItems);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: const EdgeInsets.only(left: 80, right: 80, top: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            '연혁',
            style: TextStyle(
              fontSize: isMobile ? 24 : 32,
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
          const SizedBox(height: 32),
          // 탭
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabButton(
                  '2020년~',
                  HistoryPeriod.recent,
                  isMobile,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  '2010~2020',
                  HistoryPeriod.decade2010,
                  isMobile,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  '2000~2010',
                  HistoryPeriod.decade2000,
                  isMobile,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  '2000년 이전',
                  HistoryPeriod.before2000,
                  isMobile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // 연도별 연혁 표시 (외부 스크롤만 사용)
          if (groupedHistory.isEmpty)
            Center(
              child: Text(
                '해당 기간의 연혁이 없습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: groupedHistory.entries.map((entry) {
                final year = entry.key;
                final items = entry.value;
                return _YearSection(year: year, items: items);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, HistoryPeriod period, bool isMobile) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue[900]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}

class _YearSection extends StatelessWidget {
  final String year;
  final List<HistoryItem> items;

  const _YearSection({
    required this.year,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 연도 표시 (월이 있는 경우 더 넓게)
          Container(
            width: isMobile ? 100 : 140,
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              year,
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
          ),
          // 구분선
          Container(
            width: 2,
            margin: EdgeInsets.only(right: isMobile ? 16 : 24),
            color: Colors.grey[300],
          ),
          // 내용 리스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < items.length - 1 ? 16 : 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 월 표시 (있는 경우)
                      if (item.month != null && item.month!.isNotEmpty) ...[
                        Container(
                          width: isMobile ? 50 : 60,
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${item.month}월',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // 점 표시
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 8, right: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // 내용
                      Expanded(
                        child: Text(
                          item.content,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.grey[800],
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
