import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/company_provider.dart';
import '../../models/history_item.dart';
import 'history_edit_dialog.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyList = ref.watch(historyListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('연혁 관리'),
        actions: [
          // 임시 일괄 입력 버튼
          TextButton.icon(
            onPressed: () => _showBulkImportDialog(context, ref),
            icon: const Icon(Icons.upload_file, color: Colors.orange),
            label: const Text('일괄 입력', style: TextStyle(color: Colors.orange)),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: historyList.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('등록된 연혁이 없습니다.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    item.month != null && item.month!.isNotEmpty
                        ? '${item.year}년 ${item.month}월'
                        : '${item.year}년',
                  ),
                  subtitle: Text(item.content),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditDialog(context, ref, item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _showDeleteDialog(context, ref, item),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류: $err')),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => HistoryEditDialog(
        onSave: (item) async {
          await ref.read(historyControllerProvider).add(item);
          // 다이얼로그는 HistoryEditDialog 내부에서 닫음
          // 다이얼로그가 닫힌 후 스낵바 표시
          if (context.mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('저장되었습니다.')),
                );
              }
            });
          }
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, HistoryItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => HistoryEditDialog(
        initialItem: item,
        onSave: (item) async {
          await ref.read(historyControllerProvider).update(item);
          // 다이얼로그는 HistoryEditDialog 내부에서 닫음
          // 다이얼로그가 닫힌 후 스낵바 표시
          if (context.mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('저장되었습니다.')),
                );
              }
            });
          }
        },
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, HistoryItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(
          '${item.month != null && item.month!.isNotEmpty ? "${item.year}년 ${item.month}월" : "${item.year}년"}: ${item.content}\n\n삭제하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(historyControllerProvider).delete(item.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('연혁 일괄 입력'),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '연혁 텍스트를 붙여넣으세요.\n형식: \'86. 10. 15    내용',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '연혁 텍스트를 붙여넣으세요...',
                    ),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isImporting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: isImporting
                  ? null
                  : () async {
                      setState(() => isImporting = true);
                      try {
                        final items = _parseHistoryText(textController.text);
                        final controller = ref.read(historyControllerProvider);
                        
                        int successCount = 0;
                        for (var item in items) {
                          try {
                            await controller.add(item);
                            successCount++;
                          } catch (e) {
                            print('항목 저장 실패: $e');
                          }
                        }
                        
                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$successCount개 항목이 추가되었습니다.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('오류: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setState(() => isImporting = false);
                        }
                      }
                    },
              child: isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('일괄 입력'),
            ),
          ],
        ),
      ),
    );
  }

  List<HistoryItem> _parseHistoryText(String text) {
    final List<HistoryItem> items = [];
    final lines = text.split('\n');
    
    String? currentYear;
    String? currentMonth;
    List<String> currentContentLines = [];
    
    for (var line in lines) {
      final originalLine = line;
      line = line.trim();
      if (line.isEmpty) continue;
      
      // 연도 패턴 찾기: '86. 10. 15, •'86. 10. 15, '24. 4. 17 등
      // 패턴: (• 또는 · 선택) + ' 또는 ' 선택 + 숫자2-4자 + . + 공백 + 숫자1-2자 + . + 공백 + 숫자1-2자
      final yearPattern = RegExp(r"[•·]?\s*['']?(\d{2,4})\.\s*(\d{1,2})\.\s*(\d{1,2})");
      final yearMatch = yearPattern.firstMatch(line);
      
      if (yearMatch != null) {
        // 이전 항목 저장
        if (currentYear != null && currentContentLines.isNotEmpty) {
          final content = currentContentLines.join(' ').trim();
          if (content.isNotEmpty) {
            items.add(HistoryItem(
              id: const Uuid().v4(),
              year: currentYear,
              month: currentMonth,
              content: content,
            ));
          }
        }
        
        // 새 항목 시작
        String yearStr = yearMatch.group(1)!;
        String monthStr = yearMatch.group(2)!;
        
        // 연도 변환 ('86 → 1986, '24 → 2024)
        int year;
        if (yearStr.length == 2) {
          year = int.parse(yearStr);
          if (year >= 0 && year <= 23) {
            year = 2000 + year; // 2000년대
          } else {
            year = 1900 + year; // 1900년대
          }
        } else {
          year = int.parse(yearStr);
        }
        
        currentYear = year.toString();
        currentMonth = monthStr;
        
        // 날짜 이후의 내용 추출
        final contentStart = yearMatch.end;
        final content = line.substring(contentStart).trim();
        currentContentLines = content.isNotEmpty ? [content] : [];
      } else if (currentYear != null) {
        // 연속된 내용 줄 처리
        // 들여쓰기된 줄이나 일반 텍스트 줄
        if (line.startsWith('•') || line.startsWith('·') || line.startsWith('')) {
          // 불릿으로 시작하지만 날짜가 없는 경우 (이전 항목의 연속 내용)
          final cleanedLine = line.replaceFirst(RegExp(r'^[•·]\s*'), '').trim();
          if (cleanedLine.isNotEmpty) {
            currentContentLines.add(cleanedLine);
          }
        } else if (originalLine.trim().isNotEmpty) {
          // 일반 내용 줄 (들여쓰기 포함)
          final trimmedLine = line.trim();
          if (trimmedLine.isNotEmpty) {
            // 들여쓰기가 있으면 공백으로 구분, 없으면 그냥 추가
            if (trimmedLine.length < 50 && !trimmedLine.contains(':')) {
              // 짧은 줄이면 이전 내용에 추가
              if (currentContentLines.isNotEmpty) {
                currentContentLines[currentContentLines.length - 1] += ' ' + trimmedLine;
              } else {
                currentContentLines.add(trimmedLine);
              }
            } else {
              currentContentLines.add(trimmedLine);
            }
          }
        }
      }
    }
    
    // 마지막 항목 저장
    if (currentYear != null && currentContentLines.isNotEmpty) {
      final content = currentContentLines.join(' ').trim();
      if (content.isNotEmpty) {
        items.add(HistoryItem(
          id: const Uuid().v4(),
          year: currentYear,
          month: currentMonth,
          content: content,
        ));
      }
    }
    
    return items;
  }
}

