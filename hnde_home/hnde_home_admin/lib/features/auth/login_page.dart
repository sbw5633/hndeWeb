import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../core/firestore_service.dart';
import '../../core/firebase.dart';

class AuthScaffold extends StatelessWidget {
  final Widget child;
  const AuthScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _rememberEmail = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final rememberEmail = prefs.getBool('remember_email') ?? false;
      
      if (savedEmail != null && rememberEmail) {
        setState(() {
          emailController.text = savedEmail;
          _rememberEmail = true;
        });
      }
    } catch (e) {
      print('저장된 이메일 로드 오류: $e');
    }
  }

  Future<void> _saveEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberEmail) {
        await prefs.setString('saved_email', emailController.text);
        await prefs.setBool('remember_email', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.setBool('remember_email', false);
      }
    } catch (e) {
      print('이메일 저장 오류: $e');
    }
  }

  Future<void> _handleLogin() async {
    if (!formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      await ref
          .read(authControllerProvider)
          .signIn(emailController.text, passwordController.text);
      
      // 로그인 성공 시 아이디 저장
      await _saveEmail();
      
      // 사용자 정보 확인
      final userInfo = await ref.read(currentUserInfoProvider.future);
      
      if (mounted) {
        // 승인되지 않은 경우 메시지 표시
        if (userInfo != null && !userInfo.isApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('관리자 승인이 필요합니다. 관리자에게 문의해주세요.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    
    try {
      await ref.read(authControllerProvider).signInWithGoogle();
      
      if (mounted) {
        // Firestore에서 계정 확인 (휴게소 관리자 또는 메인관리자)
        final email = firebaseAuth.currentUser?.email ?? '';
        final firestoreService = FirestoreService();
        final emailPrefix = email.replaceAll('.', '_').replaceAll('@', '_at_');
        
        final restAreaData = await firestoreService.getDocument(
          FirestoreCollections.restAreaManagers,
          emailPrefix,
        );
        final adminData = await firestoreService.getDocument(
          FirestoreCollections.admins,
          emailPrefix,
        );
        
        // rest_area_managers에도 없고 admins(메인관리자)에도 없을 때만 계정생성으로
        if (restAreaData == null && adminData == null) {
          context.go('/account-creation', extra: {
            'email': email,
            'isGoogleAccount': true,
          });
          return;
        }
        
        // 메인관리자(admins에 있음) 또는 휴게소 관리자 → 메인으로 이동
        final userInfo = await ref.read(currentUserInfoProvider.future);
        
        if (userInfo != null && !userInfo.isApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('관리자 승인이 필요합니다. 관리자에게 문의해주세요.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구글 로그인 실패: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('HNDE Admin',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: '이메일'),
              validator: (v) => (v == null || v.isEmpty) ? '이메일을 입력하세요' : null,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _rememberEmail,
                  onChanged: (value) {
                    setState(() {
                      _rememberEmail = value ?? false;
                    });
                  },
                ),
                const Text('아이디 저장'),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('로그인'),
            ),
            const SizedBox(height: 12),
            // 구글 로그인 버튼
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleLogin,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('구글로 로그인'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // 계정 생성 버튼
            OutlinedButton(
              onPressed: _isLoading ? null : _showCreateManagerDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('계정 생성'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateManagerDialog() async {
    final restAreaNameController = TextEditingController();
    final restAreaIdController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('휴게소 관리자 계정 생성'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: restAreaNameController,
                decoration: const InputDecoration(
                  labelText: '휴게소 이름',
                  hintText: '예: 서울만남의광장',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: restAreaIdController,
                decoration: const InputDecoration(
                  labelText: '관리자 ID',
                  hintText: '예: mannam (이메일 형식이 아닌 ID만 입력)',
                  helperText: '이메일 형식이 아닌 ID만 입력하세요. @hnde.co.kr이 자동으로 추가됩니다.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              if (restAreaNameController.text.isEmpty ||
                  restAreaIdController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 필드를 입력해주세요')),
                );
                return;
              }

              try {
                // 관리자 ID에서 @가 포함되어 있으면 @ 이전 부분만 사용
                final managerId = restAreaIdController.text.trim();
                final cleanId = managerId.contains('@') 
                    ? managerId.split('@')[0] 
                    : managerId;
                
                if (cleanId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('관리자 ID를 올바르게 입력해주세요')),
                  );
                  return;
                }
                
                final email = '$cleanId@hnde.co.kr';
                final password = passwordController.text;

                // Firebase Auth에 계정 생성
                await firebaseAuth.createUserWithEmailAndPassword(
                  email: email,
                  password: password,
                );

                // Firestore에 사용자 정보 저장
                final firestoreService = FirestoreService();
                await firestoreService.saveDocument(
                  'rest_area_managers',
                  {
                    'restAreaName': restAreaNameController.text.trim(),
                    'restAreaId': cleanId,
                    'email': email,
                    'role': 'rest_area_manager',
                    'isApproved': false, // 승인 필요
                    'isGoogleAccount': false,
                    'createdAt': DateTime.now().toIso8601String(),
                  },
                  docId: cleanId,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('계정이 생성되었습니다: $email'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('계정 생성 실패: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );

    restAreaNameController.dispose();
    restAreaIdController.dispose();
    passwordController.dispose();
  }
}
