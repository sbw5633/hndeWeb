import 'package:flutter/material.dart';
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
        approved: false,
        isMainAdmin: false,
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
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: const Color(0xFF4DA3D2),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 이메일 입력
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
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
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
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
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: '사업소',
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: '직책',
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: '급수',
                    border: OutlineInputBorder(),
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
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
              ],
              
              // 에러 메시지
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 회원가입 버튼
              ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4DA3D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 