import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class FileSelectorWidget extends StatefulWidget {
  final List<String> acceptedTypes;
  final bool multiple;
  final String? buttonText;
  final Function(List<Uint8List>, List<String>) onFilesSelected;

  const FileSelectorWidget({
    super.key,
    required this.acceptedTypes,
    this.multiple = false,
    this.buttonText,
    required this.onFilesSelected,
  });

  @override
  State<FileSelectorWidget> createState() => _FileSelectorWidgetState();
}

class _FileSelectorWidgetState extends State<FileSelectorWidget> {
  void _selectFiles() {
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement()
      ..accept = widget.acceptedTypes.join(',')
      ..multiple = widget.multiple;

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files!;
      final fileDataList = <Uint8List>[];
      final fileNameList = <String>[];
      
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final reader = html.FileReader();
        
        reader.onLoadEnd.listen((event) {
          fileDataList.add(Uint8List.fromList(reader.result as List<int>));
          
          if (fileDataList.length == files.length) {
            widget.onFilesSelected(fileDataList, fileNameList);
          }
        });
        
        reader.readAsArrayBuffer(file);
        fileNameList.add(file.name);
      }
    });

    uploadInput.click();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _selectFiles,
      icon: const Icon(Icons.folder_open),
      label: Text(widget.buttonText ?? '파일 선택'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}

