import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/file_info_model.dart';
import '../../../models/board_post_model.dart';
import '../../../models/user_model.dart';
import '../../components/common/storage_upload_button.dart';

class DataRequestSubmitDialog extends StatefulWidget {
  final BoardPost post;
  final String branchName;
  final AppUser currentUser;
  
  const DataRequestSubmitDialog({
    super.key,
    required this.post,
    required this.branchName,
    required this.currentUser,
  });

  @override
  State<DataRequestSubmitDialog> createState() => _DataRequestSubmitDialogState();
}

class _DataRequestSubmitDialogState extends State<DataRequestSubmitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  List<FileInfo> _uploadedFiles = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// 자료요청 회신 제출 처리: 파일 업로드 후 Firestore에 responses 병합 저장, 성공 시 다이얼로그 닫기
  Future<void> _submitResponse() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      // 파일 업로드 (기존 방식 사용)
      List<Map<String, String>> uploadedFileUrls = [];
      for (final fileInfo in _uploadedFiles) {
        try {
          final success = await fileInfo.upload();
          if (success) {
            uploadedFileUrls.add(fileInfo.toMap());
          } else {
            throw Exception('파일 업로드 실패: ${fileInfo.displayName}');
          }
        } catch (e) {
          throw Exception('파일 업로드 실패: ${fileInfo.displayName} - $e');
        }
      }

      // 회신 데이터 생성
      final responseData = {
        'status': 'submitted',
        'submittedAt': DateTime.now().toIso8601String(),
        'submittedBy': widget.currentUser.uid,
        'submittedByName': widget.currentUser.name,
        'files': uploadedFileUrls,
        'message': _messageController.text.trim(),
      };

      // Firebase에 회신 데이터 업데이트
      final updatedResponses = Map<String, dynamic>.from(widget.post.responses);
      updatedResponses[widget.branchName] = responseData;
      
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id)
            .update({
          'responses': updatedResponses,
        }).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Firebase 업데이트 타임아웃 (10초)');
          },
        );
      } catch (firestoreError) {
        // 업데이트 실패 시 set으로 시도
        try {
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.post.id)
              .set({
            'responses': updatedResponses,
          }, SetOptions(merge: true)).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Firebase set(merge) 타임아웃 (10초)');
            },
          );
        } catch (setError) {
          throw Exception('Firebase 업데이트 실패: $setError');
        }
      }
      
      if (mounted) {
        // 성공 메시지를 먼저 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.branchName} 자료가 성공적으로 제출되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        // 상태 리셋
        setState(() {
          _isSubmitting = false;
        });
        // 그 다음 다이얼로그 닫기
        Navigator.of(context).pop(true); // 성공 시 true 반환
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('자료 제출에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// 다이얼로그 UI: 요청내용 미리보기, 파일첨부, 메시지 입력, 제출/취소 버튼
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Icon(Icons.upload_file, color: Colors.blue.shade600, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.branchName} 자료 제출',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 요청 내용 미리보기
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '요청 내용',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.post.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 파일 첨부
              Text(
                '첨부 파일',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              StorageUploadButton(
                label: '파일 첨부 (${_uploadedFiles.length}/10)',
                isImage: false,
                disabled: _uploadedFiles.length >= 10,
                onFileSelected: (fileInfo) {
                  setState(() {
                    _uploadedFiles.add(fileInfo);
                  });
                },
              ),
              const SizedBox(height: 12),

              // 첨부된 파일 목록
              if (_uploadedFiles.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _uploadedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _uploadedFiles[index];
                      return ListTile(
                        leading: Icon(
                          Icons.attach_file,
                          color: Colors.blue.shade600,
                        ),
                        title: Text(
                          file.displayName,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${(file.bytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              _uploadedFiles.removeAt(index);
                            });
                          },
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                        ),
                        dense: true,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 회신 메시지
              Text(
                '회신 메시지',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '자료 제출과 관련된 메시지를 입력해주세요 (선택사항)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
                validator: (value) {
                  // 파일이나 메시지 중 하나는 있어야 함
                  if (_uploadedFiles.isEmpty && (value == null || value.trim().isEmpty)) {
                    return '파일을 첨부하거나 메시지를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // 버튼들
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitResponse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('제출하기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
