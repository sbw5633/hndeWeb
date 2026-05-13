import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../src/app/app_shell.dart';
import '../../src/features/common/loading_widget.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _keepSignedIn = true;
  bool _loading = false;
  String? _error;

  String _friendlyAuthError(FirebaseAuthException e) {
    final String code = e.code.trim();
    switch (code) {
      case 'invalid-credential':
        // 웹에서 이메일/비번 로그인 실패 시 자주 이 코드로 옵니다.
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'user-not-found':
        return '해당 이메일로 가입된 계정이 없습니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다. 관리자에게 문의해 주세요.';
      case 'too-many-requests':
        return '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      case 'network-request-failed':
        return '네트워크 오류로 로그인에 실패했습니다. 인터넷 연결을 확인해 주세요.';
      case 'operation-not-allowed':
        return '현재 로그인 방식이 비활성화되어 있습니다. 관리자에게 문의해 주세요.';
      case 'account-exists-with-different-credential':
        return '동일 이메일의 다른 로그인 방식 계정이 있습니다. 다른 방식으로 로그인해 주세요.';
      case 'popup-closed-by-user':
        return '로그인이 취소되었습니다.';
      case 'popup-blocked':
        return '브라우저에서 팝업이 차단되었습니다. 팝업 허용 후 다시 시도해 주세요.';
      default:
        // Firebase에서 제공하는 영어 문구는 사용자에게 불친절한 경우가 많아 기본 메시지를 제공합니다.
        return '로그인에 실패했습니다. 입력 정보를 확인해 주세요.';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      try {
        final UserCredential cred =
            await FirebaseAuth.instance.signInWithPopup(provider);
        if (!mounted) {
          return;
        }
        if (cred.user == null) {
          setState(() {
            _loading = false;
            _error = 'Google 로그인에 실패했습니다. 다시 시도해 주세요.';
          });
          return;
        }
      } on FirebaseAuthException catch (e) {
        final String code = e.code.trim();
        if (code == 'popup-blocked' ||
            code == 'web-context-cancelled' ||
            code == 'cancelled-popup-request') {
          try {
            await FirebaseAuth.instance.signInWithRedirect(provider);
            return;
          } on FirebaseAuthException catch (redirectAuthEx) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = _friendlyAuthError(redirectAuthEx);
              });
            }
            return;
          } catch (redirectErr) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = 'Google 로그인을 시작할 수 없습니다. $redirectErr';
              });
            }
            return;
          }
        }
        if (mounted) {
          setState(() {
            _loading = false;
            _error = _friendlyAuthError(e);
          });
        }
        return;
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Google 로그인 오류: $e';
          });
        }
        return;
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
      return;
    }

    try {
      late final UserCredential userCredential;

      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null || !mounted) {
        setState(() => _loading = false);
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null || !mounted) {
        setState(() => _loading = false);
        return;
      }

      // 프로필 유무에 따른 화면 전환은 main.dart의 AuthGate가 담당
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
      });
    } catch (e) {
      setState(() {
        _error = 'Google 로그인 오류: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
      });
    } catch (_) {
      setState(() {
        _error = '알 수 없는 오류가 발생했습니다.';
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
    return Scaffold(
      backgroundColor: AppShell.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 18,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: SelectionArea(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: const <Widget>[
                        Icon(
                          Icons.apartment_rounded,
                          color: AppShell.deepBlue,
                          size: 26,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'HNDE 업무 지원 툴',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        hintText: 'admin@example.com',
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이메일을 입력해 주세요.';
                        }
                        if (!value.contains('@')) {
                          return '유효한 이메일 주소를 입력해 주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해 주세요.';
                        }
                        if (value.length < 6) {
                          return '비밀번호는 6자 이상이어야 합니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Checkbox(
                          value: _keepSignedIn,
                          onChanged: (bool? value) {
                            setState(() {
                              _keepSignedIn = value ?? true;
                            });
                          },
                        ),
                        const Text('로그인 상태 유지'),
                      ],
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: LoadingWidget(size: 18, duration: Duration(milliseconds: 1000)),
                              )
                            : const Text('로그인'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(child: Divider(color: Colors.grey.shade600)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '또는',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _signInWithGoogle,
                        icon: Image.network(
                          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 22),
                        ),
                        label: const Text('Google로 로그인'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                    if (kIsWeb) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        '웹: 먼저 Google 팝업으로 로그인합니다. 팝업이 막히면 전체 페이지로 이동하는 방식으로 다시 시도합니다.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        const Text(
                          '계정이 없으신가요?',
                          style: TextStyle(fontSize: 12),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            '회원가입',
                            style: TextStyle(fontSize: 12),
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
    );
  }
}

