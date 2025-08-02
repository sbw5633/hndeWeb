import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'dart:async';
import '../../../models/file_info_model.dart';

/// 파일 선택 버튼 (이미지/파일)
/// onFileSelected: 선택된 파일의 FileInfo를 콜백으로 전달
class StorageUploadButton extends StatefulWidget {
  final String label;
  final bool isImage;
  final void Function(FileInfo fileInfo) onFileSelected;
  final bool disabled;

  const StorageUploadButton({
    super.key,
    required this.label,
    required this.onFileSelected,
    this.isImage = true,
    this.disabled = false,
  });

  @override
  State<StorageUploadButton> createState() => _StorageUploadButtonState();
}

class _StorageUploadButtonState extends State<StorageUploadButton> {
  String? _error;

  Future<void> _pickAndUpload() async {
    try {
      List<FileInfo> fileInfos = [];
      if (widget.isImage) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked == null) {
          return;
        }
        final fileInfo = await FileInfo.fromXFile(picked);
        if (fileInfo != null) {
          fileInfos.add(fileInfo);
        }
      } else {
        final uploadInput = html.FileUploadInputElement();
        uploadInput.multiple = true;
        uploadInput.accept = '.pdf,.doc,.docx,.hwp,.zip,.ppt,.pptx,.xls,.xlsx,.txt';
        final completer = Completer<List<html.File>>();
        html.document.body!.append(uploadInput);
        bool handled = false;
        void handleDone([_]) {
          if (!handled) {
            handled = true;
            uploadInput.remove();
            if (!completer.isCompleted) {
              completer.complete([]);
            }
          }
        }
        uploadInput.onChange.listen((e) {
          if (!handled) {
            handled = true;
            final selected = uploadInput.files;
            uploadInput.remove();
            if (selected != null && selected.isNotEmpty) {
              completer.complete([for (var i = 0; i < selected.length; i++) selected[i]]);
            } else {
              completer.complete([]);
            }
          }
        });
        uploadInput.onBlur.listen(handleDone);
        uploadInput.click();
        final files = await completer.future;
        if (files.isEmpty) {
          return;
        }
        for (final file in files) {
          final fileInfo = await FileInfo.fromHtmlFile(file);
          if (fileInfo != null) {
            fileInfos.add(fileInfo);
          }
        }
      }
      for (final fileInfo in fileInfos) {
        widget.onFileSelected(fileInfo);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: widget.disabled ? null : _pickAndUpload,
          icon: Icon(widget.isImage ? Icons.add_photo_alternate : Icons.attach_file),
          label: Text(widget.label),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
} 