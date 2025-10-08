import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/auth_provider.dart';
import '../../../models/board_post_model.dart';
import '../../../utils/file_download_utils.dart';
import 'data_request_submit_dialog.dart';

class DataRequestResponseSection extends StatefulWidget {
  final BoardPost post;
  final Function(String)? onResponseDeleted;
  
  const DataRequestResponseSection({
    super.key,
    required this.post,
    this.onResponseDeleted,
  });

  @override
  State<DataRequestResponseSection> createState() => _DataRequestResponseSectionState();
}

class _DataRequestResponseSectionState extends State<DataRequestResponseSection> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.appUser;
    
    if (currentUser == null) return const SizedBox();
    
    // 요청된 사업소 목록 가져오기
    final selectedBranches = widget.post.extra['selectedBranches'] as List<dynamic>? ?? [];
    if (selectedBranches.isEmpty) return const SizedBox();
    
    // 현재 사용자가 요청한 사업소인지 확인
    final isRequester = currentUser.affiliation == widget.post.targetGroup.split(',').first;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.business, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              '사업소별 제출 현황',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...selectedBranches.map((branch) {
          final branchName = branch.toString();
          final response = widget.post.responses[branchName] as Map<String, dynamic>?;
          final isSubmitted = response != null;
          final canSubmit = !isRequester && currentUser.affiliation == branchName;
          
          return _buildBranchResponseCard(
            branchName: branchName,
            response: response,
            isSubmitted: isSubmitted,
            canSubmit: canSubmit,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBranchResponseCard({
    required String branchName,
    required Map<String, dynamic>? response,
    required bool isSubmitted,
    required bool canSubmit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사업소명과 모든 정보를 한 줄에 표시
          Row(
            children: [
              Icon(
                Icons.business,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              
              // 사업소명
              Expanded(
                flex: 2,
                child: Text(
                  branchName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              if (isSubmitted) ...[
                // 첨부파일명
                Expanded(
                  flex: 3,
                  child: _buildFileInfo(response!, branchName),
                ),
                
                // 제출자
                Expanded(
                  flex: 2,
                  child: Text(
                    response['submittedByName'] ?? '알 수 없음',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // 제출시간
                Expanded(
                  flex: 2,
                  child: Text(
                    response['submittedAt'] != null 
                        ? _formatDateTime(response['submittedAt'])
                        : '알 수 없음',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // 삭제 버튼 (본인이 제출한 경우만)
                if (_canDeleteResponse(response)) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(branchName),
                    icon: Icon(Icons.delete, color: Colors.red.shade600, size: 18),
                    tooltip: '제출 삭제',
                  ),
                ],
              ] else ...[
                // 제출 전 상태 (우측 정렬)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Colors.orange.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '제출전',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          // 회신 메시지 (제출 완료 시에만)
          if (isSubmitted && response!['message'] != null && (response!['message'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.message, color: Colors.grey.shade600, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '회신 메시지:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    response!['message'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (canSubmit && !isSubmitted) ...[
            const SizedBox(height: 12),
            _buildSubmitButton(branchName),
          ],
        ],
      ),
    );
  }

  /// 파일 정보 위젯 (한 줄에 표시용)
  Widget _buildFileInfo(Map<String, dynamic> response, String branchName) {
    final files = response['files'] as List<dynamic>? ?? [];
    
    if (files.isEmpty) {
      return Text(
        '파일 없음',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      );
    }
    
    return InkWell(
      onTap: () {
        if (files.length == 1) {
          // 단일 파일인 경우 바로 다운로드
          final file = files.first;
          final fileName = file['name'] ?? file['url']?.split('/').last ?? '파일';
          final fileUrl = file['url'] ?? '';
          
          FileDownloadUtils.downloadFile(
            context: context,
            url: fileUrl,
            fileName: fileName,
          );
        } else {
          // 다중 파일인 경우 다이얼로그 표시
          _showFileListDialog(files, branchName);
        }
      },
      child: Row(
        children: [
          Icon(Icons.attach_file, color: Colors.blue.shade600, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              files.length == 1 
                  ? (files.first['name'] ?? files.first['url']?.split('/').last ?? '파일')
                  : '${files.length}개 파일',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade600,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 파일 목록 다이얼로그 표시
  void _showFileListDialog(List<dynamic> files, String branchName) {
    showDialog(
      context: context,
      barrierDismissible: true, // 외부 터치로 닫기 가능
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Text('${branchName} 첨부파일'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5, // 화면 너비의 50%
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 전체 다운로드 버튼
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _downloadAllFiles(files);
                  },
                  icon: Icon(Icons.download, color: Colors.white),
                  label: Text('전체 다운로드 (${files.length}개)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              // 파일 목록
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final fileName = file['name'] ?? file['url']?.split('/').last ?? '파일';
                    final fileUrl = file['url'] ?? '';
                    
                    return ListTile(
                      leading: Icon(
                        _getFileIcon(fileName),
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                      title: Text(
                        fileName,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        Icons.download,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        FileDownloadUtils.downloadFile(
                          context: context,
                          url: fileUrl,
                          fileName: fileName,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 파일 확장자에 따른 아이콘 반환
  IconData _getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// 모든 파일 다운로드
  void _downloadAllFiles(List<dynamic> files) {
    for (final file in files) {
      final fileName = file['name'] ?? file['url']?.split('/').last ?? '파일';
      final fileUrl = file['url'] ?? '';
      
      if (fileUrl.isNotEmpty) {
        FileDownloadUtils.downloadFile(
          context: context,
          url: fileUrl,
          fileName: fileName,
        );
      }
    }
  }

  Widget _buildSubmitButton(String branchName) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showSubmitDialog(branchName),
        icon: const Icon(Icons.upload_file, size: 18),
        label: const Text('자료 제출하기'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _showSubmitDialog(String branchName) {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.appUser;
    
    if (currentUser == null) return;
    
    showDialog(
      context: context,
      builder: (context) => DataRequestSubmitDialog(
        post: widget.post,
        branchName: branchName,
        currentUser: currentUser,
      ),
    ).then((result) {
      // 제출 성공 시 상위 콜백을 통해 부모 위젯에서 새로고침 처리
      if (result == true) {
        if (widget.onResponseDeleted != null) {
          widget.onResponseDeleted!(branchName);
        }
      }
    });
  }

  /// 삭제 권한 확인 (본인이 제출한 경우만)
  bool _canDeleteResponse(Map<String, dynamic> response) {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.appUser;
    
    if (currentUser == null) return false;
    
    final submittedBy = response['submittedBy'] as String?;
    return submittedBy == currentUser.uid;
  }

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmation(String branchName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('제출 삭제'),
        content: Text('${branchName}의 제출 자료를 삭제하시겠습니까?\n\n삭제된 자료는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteResponse(branchName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 제출 자료 삭제
  Future<void> _deleteResponse(String branchName) async {
    try {
      final updatedResponses = Map<String, dynamic>.from(widget.post.responses);
      updatedResponses.remove(branchName);

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .update({
        'responses': updatedResponses,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${branchName}의 제출 자료가 삭제되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // 부모 위젯에 삭제 완료 알림 (상태 업데이트)
        if (widget.onResponseDeleted != null) {
          widget.onResponseDeleted!(branchName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('제출 삭제에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }
}
