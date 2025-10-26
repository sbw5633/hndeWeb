import 'package:flutter/material.dart';

/// 공통 도구 페이지 레이아웃
class ToolPageLayout extends StatelessWidget {
  final String title;
  final String description;
  final Color color;
  final List<Widget> actions;
  final Widget content;
  final bool isLoading;

  const ToolPageLayout({
    super.key,
    required this.title,
    required this.description,
    required this.color,
    this.actions = const [],
    required this.content,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 컨텐츠 (메인뷰가 위쪽)
              Expanded(child: content),
              
              // 액션 버튼들 (하단)
              if (actions.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
              ],
            ],
          ),
          
          // 로딩 오버레이
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

/// 파일 리스트를 보여주는 공통 위젯
class FileListWidget extends StatelessWidget {
  final List<String> fileNames;
  final Function(int) onRemove;

  const FileListWidget({
    super.key,
    required this.fileNames,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (fileNames.isEmpty) {
      return Center(
        child: Text(
          '파일을 선택해주세요',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: fileNames.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(fileNames[index]),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => onRemove(index),
            ),
          ),
        );
      },
    );
  }
}

