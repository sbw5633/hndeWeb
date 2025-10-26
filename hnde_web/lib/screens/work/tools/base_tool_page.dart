import 'package:flutter/material.dart';
import '../../../widgets/file_handler_widget.dart';
import '../../../widgets/drag_drop_zone.dart';
import '../../../widgets/file_preview_card.dart';
import '../models/tool_definition.dart';
import '../pdf_tools/pdf_processing_page.dart';
import 'dart:typed_data';

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

    // 처리 페이지로 이동
    final filesCopy = List<FileData>.from(_selectedFiles);
    final fileName = '${widget.config.title}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PDFProcessingPage(
          processFunction: () => _executeProcessing(filesCopy),
          fileName: fileName,
          description: '${widget.config.title} 처리 중...',
        )),
    );
  }

  Future<Uint8List> _executeProcessing(List<FileData> files) async {
    // TODO: 실제 처리 로직 구현
    await Future.delayed(const Duration(seconds: 2));
    return Uint8List(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.title),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: DragDropZone(
                    onFilesDropped: (files) {
                      setState(() {
                        _selectedFiles.addAll(files);
                      });
                    },
                    acceptedTypes: widget.config.acceptedTypes,
                    isMultiple: true,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _selectedFiles.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_file,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '파일을 드래그앤드롭하거나 클릭하여 선택',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                                childAspectRatio: 0.7,
                              ),
                              itemCount: _selectedFiles.length,
                              itemBuilder: (context, index) {
                                return FilePreviewCard(
                                  file: _selectedFiles[index],
                                  onRemove: () {
                                    setState(() {
                                      _selectedFiles.removeAt(index);
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedFiles.isNotEmpty)
                  ElevatedButton(
                    onPressed: _processFiles,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.config.color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      widget.config.title,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
          
          // 로딩 오버레이
          if (_isProcessing)
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

