import 'package:flutter/material.dart';
import '../../../widgets/tool_page_layout.dart';
import '../../../widgets/file_handler_widget.dart';
import '../models/tool_definition.dart';

/// 범용 도구 페이지 - 도구 설정에 따라 동적으로 작동
class BaseToolPage extends StatefulWidget {
  final ToolConfig config;

  const BaseToolPage({
    super.key,
    required this.config,
  });

  @override
  State<BaseToolPage> createState() => _BaseToolPageState();
}

class _BaseToolPageState extends State<BaseToolPage> {
  final List<FileData> _selectedFiles = [];
  bool _isProcessing = false;

  Future<void> _selectFiles() async {
    final files = await FileHandlerWidget.selectFiles(
      acceptedTypes: widget.config.acceptedTypes,
      acceptDescription: widget.config.title,
      maxFiles: widget.config.maxFiles,
    );

    setState(() {
      _selectedFiles.addAll(files);
    });
  }

  Future<void> _processFiles() async {
    if (widget.config.minFiles != null && _selectedFiles.length < widget.config.minFiles!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최소 ${widget.config.minFiles}개 이상의 파일이 필요합니다.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // TODO: 실제 처리 로직 구현
      await Future.delayed(const Duration(seconds: 2));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.config.title} 완료!')),
      );

      setState(() {
        _selectedFiles.clear();
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPageLayout(
      icon: widget.config.icon,
      title: widget.config.title,
      description: widget.config.description,
      color: widget.config.color,
      isLoading: _isProcessing,
      actions: [
        ElevatedButton.icon(
          onPressed: _selectFiles,
          icon: const Icon(Icons.folder_open),
          label: const Text('파일 선택'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(_selectedFiles[index].fileName),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _selectedFiles.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_selectedFiles.isEmpty)
              const Center(
                child: Text(
                  '파일을 선택해주세요',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_selectedFiles.isNotEmpty)
              ElevatedButton(
                onPressed: _isProcessing ? null : _processFiles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.config.color,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  '처리하기',
                  style: TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

