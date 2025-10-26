import 'package:flutter/material.dart';
import 'package:hnde_web/const_value.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_provider.dart';
import '../../widgets/toast.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _showLoginErrorDialog(BuildContext context) {
    showToast(context, '이메일 또는 비밀번호를 확인해주세요.');
  }

  @override
  Widget build(BuildContext context) {
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(24),
              child: Card(
                elevation: 20,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 로고
                      Container(
                        width: 150,
                        height: 80,
                        child: Image.asset(
                          kLogoVertical,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // 제목
                      Text('로그인', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                      const SizedBox(height: 32),
                      
                      // 이메일 입력
                      TextField(
                        controller: _idController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: '이메일',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 비밀번호 입력
                      TextField(
                        controller: _pwController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: Icon(Icons.lock_outlined, color: Colors.blue.shade400),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // 로그인 버튼 (사이드바와 동일한 로직)
                      ElevatedButton(
                        onPressed: () async {
                          final authProvider = context.read<AuthProvider>();
                          print('로그인 시도: ${_idController.text}');
                          final success = await authProvider.login(_idController.text, _pwController.text);
                          print('로그인 결과: $success');
                          if (success && mounted) {
                            // 로그인 성공 시 메인 화면으로 이동
                            print('로그인 성공 - 메인 화면으로 이동');
                            context.go('/');
                          } else if (!success && mounted) {
                            _showLoginErrorDialog(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('로그인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 16),
                      
                      // 회원가입 링크
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Text('회원가입', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                      ),
                    ],
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