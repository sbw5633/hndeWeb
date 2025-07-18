import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'dart:async';
import '../../../models/file_info_model.dart';

/// 파일 선택 버튼 (이미지/파일)
/// onFileSelected: 선택된 파일의 FileInfo를 콜백으로 전달
class CloudinaryUploadButton extends StatefulWidget {
  final String label;
  final bool isImage;
  final void Function(FileInfo fileInfo) onFileSelected;
  final bool disabled;

  const CloudinaryUploadButton({
    super.key,
    required this.label,
    required this.onFileSelected,
    this.isImage = true,
    this.disabled = false,
  });

  @override
  State<CloudinaryUploadButton> createState() => _CloudinaryUploadButtonState();
}

class _CloudinaryUploadButtonState extends State<CloudinaryUploadButton> {
  bool _uploading = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    setState(() {
      debugPrint('pickAndUpload');
      _uploading = true;
      _error = null;
    });
    
    try {
      List<FileInfo> fileInfos = [];
      
      if (widget.isImage) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked == null) {
          // 파일 선택 취소 시 정상적으로 처리
          setState(() {
            _uploading = false;
          });
          return;
        }
        final fileInfo = await FileInfo.fromXFile(picked);
        if (fileInfo != null) {
          fileInfos.add(fileInfo);
        }
      } else {
        final uploadInput = html.FileUploadInputElement();
        uploadInput.multiple = true; // 여러 파일 선택 가능
        // 이미지 확장자 제외, 문서/압축 등만 허용
        uploadInput.accept = '.pdf,.doc,.docx,.hwp,.zip,.ppt,.pptx,.xls,.xlsx,.txt';
        final completer = Completer<List<html.File>>();
        
        uploadInput.onChange.listen((e) {
          final selected = uploadInput.files;
          if (selected != null && selected.isNotEmpty) {
            completer.complete(selected.toList());
          } else {
            completer.complete([]);
          }
        });
        
        uploadInput.click();
        final files = await completer.future;
        
        if (files.isEmpty) {
          // 파일 선택 취소 시 정상적으로 처리
          setState(() {
            _uploading = false;
          });
          return;
        }
        
        // 여러 파일 처리
        for (final file in files) {
          final fileInfo = await FileInfo.fromHtmlFile(file);
          if (fileInfo != null) {
            fileInfos.add(fileInfo);
          }
        }
      }
      
      // 선택된 파일들을 콜백으로 전달
      for (final fileInfo in fileInfos) {
        widget.onFileSelected(fileInfo);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: (_uploading || widget.disabled) ? null : _pickAndUpload,
          icon: Icon(widget.isImage ? Icons.add_photo_alternate : Icons.attach_file),
          label: Text(widget.label),
        ),
        // if (_uploading)
        //   Padding(
        //     padding: const EdgeInsets.only(top: 8.0),
        //     child: Container(width: double.infinity, child: const LinearProgressIndicator()),
        //   ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
} 