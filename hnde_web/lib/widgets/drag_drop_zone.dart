import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'file_handler_widget.dart';

class DragDropZone extends StatefulWidget {
  final void Function(List<FileData>) onFilesDropped;
  final List<String> acceptedTypes;
  final bool isMultiple;
  final Widget child;

  const DragDropZone({
    super.key,
    required this.onFilesDropped,
    required this.acceptedTypes,
    this.isMultiple = true,
    required this.child,
  });

  @override
  State<DragDropZone> createState() => _DragDropZoneState();
}

class _DragDropZoneState extends State<DragDropZone> {
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    
    html.window.onDragOver.listen((event) {
      event.preventDefault();
      if (mounted) {
        setState(() {
          _isDragging = true;
        });
      }
    });

    html.window.onDragLeave.listen((event) {
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
    });

    html.window.onDrop.listen((event) {
      event.preventDefault();
      if (!mounted) return;
      
      setState(() {
        _isDragging = false;
      });

      final dragEvent = event as dynamic;
      final files = dragEvent.dataTransfer?.files;
      
      if (files != null && files.isNotEmpty) {
        _handleFiles(files);
      }
    });
  }

  Future<void> _handleFiles(dynamic fileList) async {
    final fileDataList = <FileData>[];
    
    for (int i = 0; i < fileList.length; i++) {
      try {
        final file = fileList[i];
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();
        
        reader.onLoadEnd.listen((e) {
          completer.complete(Uint8List.fromList(reader.result as List<int>));
        });
        
        reader.readAsArrayBuffer(file);
        final data = await completer.future;
        
        fileDataList.add(FileData(
          data: data,
          fileName: file.name,
        ));
      } catch (e) {
        debugPrint('파일 읽기 오류: $e');
      }
    }
    
    if (mounted) {
      widget.onFilesDropped(fileDataList);
    }
  }

  Future<void> _selectFiles() async {
    final files = await FileHandlerWidget.selectFiles(
      acceptedTypes: widget.acceptedTypes,
      acceptDescription: '파일',
    );
    
    if (mounted && files.isNotEmpty) {
      widget.onFilesDropped(files);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _selectFiles,
      child: Stack(
        children: [
          widget.child,
          
          // 드래그 중일 때 반투명 오버레이
          if (_isDragging)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.withOpacity(0.3),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        size: 64,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '파일을 여기에 놓으세요',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

