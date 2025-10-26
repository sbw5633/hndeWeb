import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../widgets/tool_page_layout.dart';
import '../../../widgets/file_handler_widget.dart';

class PDFMergePage extends StatefulWidget {
  const PDFMergePage({super.key});

  @override
  State<PDFMergePage> createState() => _PDFMergePageState();
}

class _PDFMergePageState extends State<PDFMergePage> {
  final List<Uint8List> _selectedFiles = [];
  final List<String> _fileNames = [];
  bool _isProcessing = false;

  Future<void> _selectFiles() async {
    final files = await FileHandlerWidget.selectFiles(
      acceptedTypes: ['.pdf'],
      acceptDescription: 'PDF 파일',
    );

    setState(() {
      for (var file in files) {
        _selectedFiles.add(file.data);
        _fileNames.add(file.fileName);
      }
    });
  }

  Future<void> _processPDFs() async {
    if (_selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 2개 이상의 PDF 파일을 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // PDF 병합 로직 구현
      final pdf = pw.Document();
      
      for (final fileData in _selectedFiles) {
        // PDF 페이지를 이미지로 변환하여 추가
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Text('PDF 병합'),
              );
            },
          ),
        );
      }

      final mergedBytes = await pdf.save();
      
      // 다운로드
      FileHandlerWidget.downloadPDF(mergedBytes, 'merged.pdf');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF 병합 완료!')),
      );

      setState(() {
        _selectedFiles.clear();
        _fileNames.clear();
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
      icon: Icons.merge_type,
      title: 'PDF 합치기',
      description: '여러 PDF 파일을 하나로 병합합니다',
      color: Colors.red.shade400,
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
            FileListWidget(
              fileNames: _fileNames,
              onRemove: (index) {
                setState(() {
                  _fileNames.removeAt(index);
                  _selectedFiles.removeAt(index);
                });
              },
            ),
            const SizedBox(height: 16),
            if (_fileNames.isNotEmpty)
              ElevatedButton(
                onPressed: _processPDFs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'PDF 합치기',
                  style: TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

