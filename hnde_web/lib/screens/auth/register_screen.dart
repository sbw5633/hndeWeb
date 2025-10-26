import 'package:flutter/material.dart';
import 'package:hnde_web/const_value.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/select_info_provider.dart';
import '../../models/user_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  String? _selectedBranchId;
  String? _selectedPositionId;
  String? _selectedRankId;
  
  // 선택된 값들의 이름을 저장할 변수들
  String? _selectedBranchName;
  String? _selectedPositionName;
  
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // SelectInfoProvider에서 데이터 로드
    Future.microtask(() {
      final provider = context.read<SelectInfoProvider>();
      if (!provider.loaded) provider.loadAll();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Firebase Auth로 사용자 생성
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Firestore에 사용자 정보 저장
      final user = AppUser(
        uid: userCredential.user!.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        affiliation: _selectedBranchName ?? '', // branch name 저장
        role: _selectedPositionName ?? '', // position name 저장
        permissionLevel: PermissionLevel.employee, // 기본 권한
        approved: false,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userCredential.user!.uid)
          .set(user.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다. 관리자 승인을 기다려주세요.')),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = '비밀번호가 너무 약합니다.';
          break;
        case 'email-already-in-use':
          errorMessage = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일입니다.';
          break;
        default:
          errorMessage = '회원가입 중 오류가 발생했습니다: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '회원가입 중 오류가 발생했습니다: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectInfo = context.watch<SelectInfoProvider>();
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade600, Colors.purple.shade600],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  elevation: 20,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.grey.shade50],
                      ),
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 로고
                          Container(
                            width: 120,
                            height: 80,
                            child: Image.asset(
                              kLogoVertical,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // 제목
                          Text('회원가입', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                          const SizedBox(height: 8),
                          Text('새 계정을 만들어보세요', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          const SizedBox(height: 32),
                          // 이메일 입력
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: '이메일',
                              prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade400),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '이메일을 입력해주세요.';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return '유효한 이메일을 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // 비밀번호 입력
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: '비밀번호',
                              prefixIcon: Icon(Icons.lock_outlined, color: Colors.blue.shade400),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '비밀번호를 입력해주세요.';
                              }
                              if (value.length < 6) {
                                return '비밀번호는 6자 이상이어야 합니다.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // 이름 입력
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: '이름',
                              prefixIcon: Icon(Icons.person_outlined, color: Colors.blue.shade400),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '이름을 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // 사업소 선택
                          if (selectInfo.loaded) ...[
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: '사업소',
                                prefixIcon: Icon(Icons.business_outlined, color: Colors.blue.shade400),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                ),
                              ),
                              value: _selectedBranchId,
                              items: selectInfo.branches.map<DropdownMenuItem<String>>((branch) {
                                return DropdownMenuItem<String>(
                                  value: branch['id'],
                                  child: Text(branch['name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedBranchId = value;
                                  // 선택된 branch의 이름도 저장
                                  if (value != null) {
                                    final selectedBranch = selectInfo.branches.firstWhere(
                                      (branch) => branch['id'] == value,
                                      orElse: () => {'name': ''},
                                    );
                                    _selectedBranchName = selectedBranch['name'];
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '사업소를 선택해주세요.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // 직책 선택
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: '직책',
                                prefixIcon: Icon(Icons.work_outline, color: Colors.blue.shade400),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                ),
                              ),
                              value: _selectedPositionId,
                              items: selectInfo.positions.map<DropdownMenuItem<String>>((position) {
                                return DropdownMenuItem<String>(
                                  value: position['id'],
                                  child: Text(position['name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPositionId = value;
                                  // 선택된 position의 이름도 저장
                                  if (value != null) {
                                    final selectedPosition = selectInfo.positions.firstWhere(
                                      (position) => position['id'] == value,
                                      orElse: () => {'name': ''},
                                    );
                                    _selectedPositionName = selectedPosition['name'];
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '직책을 선택해주세요.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // 급수 선택
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: '급수',
                                prefixIcon: Icon(Icons.star_outline, color: Colors.blue.shade400),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                ),
                              ),
                              value: _selectedRankId,
                              items: selectInfo.ranks.map<DropdownMenuItem<String>>((rank) {
                                return DropdownMenuItem<String>(
                                  value: rank['id'],
                                  child: Text(rank['name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedRankId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '급수를 선택해주세요.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // 에러 메시지
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade200),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade600),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // 회원가입 버튼
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: Colors.blue.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      '회원가입',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // 로그인 링크
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '이미 계정이 있으신가요? ',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Text(
                                  '로그인',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 