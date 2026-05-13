import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/data_service.dart';
import '../models/rest_area.dart';
import '../core/firestore_service.dart';

// 고객의 이야기 폼 페이지
class CustomerStoryFormPage extends StatefulWidget {
  const CustomerStoryFormPage({super.key});

  @override
  State<CustomerStoryFormPage> createState() => _CustomerStoryFormPageState();
}

class _CustomerStoryFormPageState extends State<CustomerStoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _dataService = DataService();
  final _firestoreService = FirestoreService();
  bool _isSubmitting = false;
  List<RestArea> _restAreas = [];
  String? _selectedRestAreaId;
  bool _isLoadingRestAreas = true;

  @override
  void initState() {
    super.initState();
    _loadRestAreas();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadRestAreas() async {
    try {
      final restAreas = await _dataService.getRestAreaList();
      setState(() {
        _restAreas = restAreas;
        _isLoadingRestAreas = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRestAreas = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('휴게소 목록을 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Firestore에 저장
      await _firestoreService.saveDocument(
        FirestoreCollections.customerStories,
        {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'restAreaId': _selectedRestAreaId,
          'createdAt': Timestamp.now(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('고객의 이야기가 성공적으로 전송되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        // 폼 초기화
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _titleController.clear();
        _contentController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전송 중 오류가 발생했습니다: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              '고객의 이야기',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 4,
              color: Colors.orange,
            ),
            const SizedBox(height: 40),
            // 안내 문구
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '고객 여러분의 소중한 이야기를 들려주세요. 작성하신 내용은 휴게소 관리자에게 전달됩니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[900],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 폼
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름
                  Text(
                    '이름 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: '이름을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이름을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // 이메일
                  Text(
                    '이메일 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: '이메일을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력해주세요';
                      }
                      if (!value.contains('@')) {
                        return '올바른 이메일 형식을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // 전화번호
                  Text(
                    '전화번호',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '전화번호를 입력하세요 (선택사항)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 사업소 선택
                  Text(
                    '사업소',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedRestAreaId,
                    decoration: InputDecoration(
                      hintText: '사업소를 선택하세요 (선택사항)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: _isLoadingRestAreas
                        ? [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('로딩 중...'),
                            ),
                          ]
                        : [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('선택 안함'),
                            ),
                            ..._restAreas.map((restArea) {
                              return DropdownMenuItem<String>(
                                value: restArea.id,
                                child: Text(restArea.name),
                              );
                            }),
                          ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRestAreaId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // 제목
                  Text(
                    '제목 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: '제목을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '제목을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // 내용
                  Text(
                    '내용 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contentController,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: '고객의 이야기를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '내용을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),
                  // 제출 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '전송하기',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

