import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../repositories/work_firestore_repository.dart';
import '../common/loading_widget.dart';
import '../common/message_alert.dart';
import '../../services/r2_storage_service.dart';

class FileTransferUploader extends StatefulWidget {
  const FileTransferUploader({super.key});

  @override
  State<FileTransferUploader> createState() => _FileTransferUploaderState();
}

class _FileTransferUploaderState extends State<FileTransferUploader> {
  bool _uploading = false;
  late final WorkFirestoreRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
  }

  Future<void> _pickAndUpload() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final PlatformFile file = result.files.first;

    setState(() {
      _uploading = true;
    });

    try {
      final R2StorageService storage = R2StorageService();
      final R2UploadResult uploadResult = await storage.uploadFile(file);

      final String fileType = _detectFileType(file.extension);
      final String? uid = FirebaseAuth.instance.currentUser?.uid;

      await FirestorePaths.transfersCol().add(<String, dynamic>{
        'senderId': uid,
        'receiverId': null,
        'fileUrl': uploadResult.fileUrl,
        'fileKey': uploadResult.fileKey,
        'fileName': file.name,
        'fileType': fileType,
        'createdAt': FieldValue.serverTimestamp(),
        if (uid != null) 'uploadedByUid': uid,
      });

      await _repo.recordR2Upload(
        fileKey: uploadResult.fileKey,
        fileUrl: uploadResult.fileUrl,
        source: '파일 전송',
        sourcePath: '파일 전송 (대용량)',
      );

      if (mounted) {
        showMessageAlert(context, message: '파일 업로드가 완료되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        showMessageAlert(context, message: '업로드 실패: $e', title: '업로드 실패');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ElevatedButton.icon(
          onPressed: _uploading ? null : _pickAndUpload,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('파일 업로드'),
        ),
        if (_uploading) ...<Widget>[
          const SizedBox(height: 12),
          const Center(
            child: LoadingWidget(size: 48, duration: Duration(milliseconds: 1500)),
          ),
        ],
      ],
    );
  }
}

String _detectFileType(String? extension) {
  final String ext = (extension ?? '').toLowerCase();
  switch (ext) {
    case 'pdf':
      return 'pdf';
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'webp':
      return 'image';
    case 'hwp':
      return 'hwp';
    case 'xlsx':
    case 'xls':
      return 'xlsx';
    case 'ppt':
    case 'pptx':
      return 'pptx';
    case 'zip':
    case '7z':
      return 'zip';
    default:
      return 'etc';
  }
}

