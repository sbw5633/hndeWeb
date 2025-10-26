import 'package:flutter/material.dart';
import '../../../widgets/file_handler_widget.dart';
import 'dart:typed_data';

/// PDF 처리 진행 페이지
class PDFProcessingPage extends StatefulWidget {
  final Future<Uint8List> Function() processFunction;
  final String fileName;
  final String description;

  const PDFProcessingPage({
    super.key,
    required this.processFunction,
    required this.fileName,
    this.description = 'PDF 처리 중...',
  });

  @override
  State<PDFProcessingPage> createState() => _PDFProcessingPageState();
}

class _PDFProcessingPageState extends State<PDFProcessingPage> {
  bool _isProcessing = true;
  bool _isCompleted = false;
  Uint8List? _resultData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    try {
      final result = await widget.processFunction();
      
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
        _isCompleted = true;
        _resultData = result;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
        _isCompleted = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _download() {
    if (_resultData != null) {
      FileHandlerWidget.downloadPDF(_resultData!, widget.fileName);
    }
  }

  void _goBack() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 처리'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 처리 중
              if (_isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  widget.description,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              
              // 완료
              if (_isCompleted && !_isProcessing) ...[
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  '처리가 완료되었습니다!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download),
                  label: const Text('다운로드'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _goBack,
                  child: const Text('처음으로 돌아가기'),
                ),
              ],
              
              // 에러
              if (_errorMessage != null) ...[
                const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  '처리 중 오류가 발생했습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

