import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firestore_service.dart';

// 사업제안 폼 페이지
class BusinessProposalFormPage extends StatefulWidget {
  const BusinessProposalFormPage({super.key});

  @override
  State<BusinessProposalFormPage> createState() =>
      _BusinessProposalFormPageState();
}

class _BusinessProposalFormPageState extends State<BusinessProposalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _representativeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _proposalTitleController = TextEditingController();
  final _proposalContentController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _isSubmitting = false;
  String? _selectedRestAreaId;

  @override
  void dispose() {
    _companyNameController.dispose();
    _representativeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessTypeController.dispose();
    _proposalTitleController.dispose();
    _proposalContentController.dispose();
    super.dispose();
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
        FirestoreCollections.businessProposals,
        {
          'companyName': _companyNameController.text.trim(),
          'representative': _representativeController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'businessType': _businessTypeController.text.trim(),
          'proposalTitle': _proposalTitleController.text.trim(),
          'proposalContent': _proposalContentController.text.trim(),
          'restAreaId': _selectedRestAreaId,
          'createdAt': Timestamp.now(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사업제안이 성공적으로 전송되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        // 폼 초기화
        _companyNameController.clear();
        _representativeController.clear();
        _emailController.clear();
        _phoneController.clear();
        _businessTypeController.clear();
        _proposalTitleController.clear();
        _proposalContentController.clear();
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
              '사업제안',
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
                      '사업 제안서를 작성해주세요. 작성하신 내용은 검토 후 답변드립니다.',
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
                  // 회사명
                  Text(
                    '회사명 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _companyNameController,
                    decoration: InputDecoration(
                      hintText: '회사명을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '회사명을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // 대표자명
                  Text(
                    '대표자명 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _representativeController,
                    decoration: InputDecoration(
                      hintText: '대표자명을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '대표자명을 입력해주세요';
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
                    '전화번호 *',
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
                      hintText: '전화번호를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '전화번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // 사업 분야
                  Text(
                    '사업 분야 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _businessTypeController,
                    decoration: InputDecoration(
                      hintText: '사업 분야를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '사업 분야를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // 제안 제목
                  Text(
                    '제안 제목 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _proposalTitleController,
                    decoration: InputDecoration(
                      hintText: '제안 제목을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '제안 제목을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // 제안 내용
                  Text(
                    '제안 내용 *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _proposalContentController,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: '사업 제안 내용을 상세히 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '제안 내용을 입력해주세요';
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
                              '제안서 전송하기',
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

