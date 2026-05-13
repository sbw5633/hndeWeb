import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../src/app/app_shell.dart';
import '../../src/constants/firestore_paths.dart';
import '../../src/features/common/loading_widget.dart';
import '../../src/models/branch_model.dart';
import '../../src/services/initial_data_seeder.dart';

String? _validateBirthdayMmdd(String raw) {
  final String v = raw.trim();
  final RegExp re = RegExp(r'^\d{2}/\d{2}$');
  if (!re.hasMatch(v)) {
    return '생일은 MM/DD 형식(예: 08/15)으로 입력해 주세요.';
  }
  final int mm = int.tryParse(v.substring(0, 2)) ?? -1;
  final int dd = int.tryParse(v.substring(3, 5)) ?? -1;
  if (mm < 1 || mm > 12) {
    return '월(MM)은 01~12 범위여야 합니다.';
  }
  const List<int> daysInMonth = <int>[31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  final int maxDay = daysInMonth[mm - 1];
  if (dd < 1 || dd > maxDay) {
    return '일(DD)은 01~${maxDay.toString().padLeft(2, '0')} 범위여야 합니다.';
  }
  return null;
}

class _BirthdayMmddFormatter extends TextInputFormatter {
  const _BirthdayMmddFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 숫자만 추출
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final String d = digits.length > 4 ? digits.substring(0, 4) : digits;

    String formatted;
    if (d.length <= 2) {
      formatted = d;
    } else {
      formatted = '${d.substring(0, 2)}/${d.substring(2)}';
    }

    // 커서 위치 보정 (2자리 넘어서면 slash 1칸 추가)
    final int rawCursor = newValue.selection.extentOffset.clamp(0, newValue.text.length);
    final int digitsBeforeCursor = newValue.text
        .substring(0, rawCursor)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length
        .clamp(0, 4);
    final int slash = digitsBeforeCursor > 2 ? 1 : 0;
    final int nextCursor = (digitsBeforeCursor + slash).clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: nextCursor),
      composing: TextRange.empty,
    );
  }
}

String _branchListLoadHint(Object? error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore에서 사업소 목록 읽기가 거부되었습니다. '
            '관리자에게 public/data/branches(또는 해당 경로) 읽기 규칙 확인을 요청하세요.';
      case 'unavailable':
      case 'deadline-exceeded':
        return '일시적으로 연결할 수 없습니다. 네트워크를 확인한 뒤 다시 시도하세요.';
      case 'failed-precondition':
        return '쿼리에 필요한 인덱스가 없을 수 있습니다. Firebase 콘솔 오류 링크로 인덱스를 생성하세요.';
      default:
        break;
    }
  }
  return '사업소 목록을 불러오지 못했습니다. 네트워크를 확인하거나 관리자에게 문의하세요.';
}

/// 드롭다운 value: `name` 우선, 비어 있으면 문서 id.
String _signupBranchDropdownValue(BranchModel b) {
  final String n = b.name.trim();
  return n.isEmpty ? b.id : n;
}

String _friendlySignupAuthError(FirebaseAuthException e) {
  switch (e.code.trim()) {
    case 'email-already-in-use':
      return '이미 사용 중인 이메일입니다. 로그인하거나 다른 이메일을 사용해 주세요.';
    case 'invalid-email':
      return '이메일 형식이 올바르지 않습니다.';
    case 'weak-password':
      return '비밀번호가 너무 약합니다. 더 길고 복잡한 비밀번호를 사용해 주세요.';
    case 'operation-not-allowed':
      return '이메일 가입이 비활성화되어 있습니다. 관리자에게 문의해 주세요.';
    case 'network-request-failed':
      return '네트워크 오류입니다. 연결을 확인한 뒤 다시 시도해 주세요.';
    case 'too-many-requests':
      return '시도 횟수가 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    default:
      return '계정을 만들 수 없습니다. 입력 정보를 확인해 주세요.';
  }
}

enum _SignupStep {
  /// 이메일·비밀번호만 (Firestore 미조회)
  credentials,
  /// 로그인된 뒤 사업소 등 프로필 입력 + DB 저장
  profile,
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    this.isSocialSignup = false,
    this.socialEmail = '',
  });

  final bool isSocialSignup;
  final String socialEmail;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final FocusNode _birthdayFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  String _branch = '선택없음';
  bool _loading = false;
  String? _error;
  bool _canSubmit = false;

  _SignupStep _step = _SignupStep.credentials;

  /// 사업소 목록은 로그인 후에만 조회합니다(규칙상 `isSignedIn()` 필요).
  /// 항상 `artifacts/${FirestorePaths.appId}/public/data/branches` 만 사용합니다(다른 appId 미러 없음).
  Future<QuerySnapshot<Map<String, dynamic>>>? _branchesFuture;

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchBranchesForSignup() async {
    final QuerySnapshot<Map<String, dynamic>> primary =
        await FirestorePaths.publicBranchesCol().get();
    if (primary.docs.isNotEmpty) {
      return primary;
    }
    await InitialDataSeeder.ensureMinimumHeadquartersBranchIfEmpty();
    return FirestorePaths.publicBranchesCol().get();
  }

  @override
  void initState() {
    super.initState();
    if (widget.isSocialSignup) {
      _step = _SignupStep.profile;
      _branchesFuture = _fetchBranchesForSignup();
    } else {
      _step = _SignupStep.credentials;
      _branchesFuture = null;
    }
    _emailController = TextEditingController(text: widget.socialEmail);

    _nameController.addListener(_syncCanSubmit);
    _positionController.addListener(_syncCanSubmit);
    _birthdayController.addListener(_syncCanSubmit);
    _phoneController.addListener(_syncCanSubmit);
    _passwordController.addListener(_syncCanSubmit);
    _passwordConfirmController.addListener(_syncCanSubmit);

    _syncCanSubmit();
  }

  /// 회원가입 화면을 로그인에서 `push`한 경우 → `pop`으로 복귀.
  /// 소셜 로그인 직후 프로필 미완성으로 `AuthGate` 루트에만 뜬 경우 → `pop` 불가이므로 `signOut`으로 로그인 화면으로.
  Future<void> _exitWithoutSaving() async {
    if (_loading) {
      return;
    }
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        // ignore
      }
    }
    if (!mounted) {
      return;
    }
    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  void _syncCanSubmit() {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String passwordConfirm = _passwordConfirmController.text;

    final bool profileFilled = _nameController.text.trim().isNotEmpty &&
        _branch.trim().isNotEmpty &&
        _branch.trim() != '선택없음' &&
        _positionController.text.trim().isNotEmpty &&
        _birthdayController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty;

    bool enabled = false;
    if (widget.isSocialSignup) {
      enabled = !_loading && profileFilled;
    } else if (_step == _SignupStep.credentials) {
      enabled = !_loading &&
          email.isNotEmpty &&
          email.contains('@') &&
          password.length >= 6 &&
          passwordConfirm.isNotEmpty &&
          password == passwordConfirm;
    } else {
      enabled = !_loading && profileFilled;
    }

    if (enabled != _canSubmit) {
      setState(() {
        _canSubmit = enabled;
      });
    }
  }

  Future<void> _backToCredentialsFromProfile() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // ignore
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _step = _SignupStep.credentials;
      _branchesFuture = null;
      _branch = '선택없음';
    });
    _syncCanSubmit();
  }

  Future<void> _submitCredentials() async {
    if (widget.isSocialSignup || _step != _SignupStep.credentials) {
      return;
    }
    final String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '이메일을 확인해 주세요.');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 합니다.');
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() => _error = '비밀번호 확인이 일치하지 않습니다.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _step = _SignupStep.profile;
        _branchesFuture = _fetchBranchesForSignup();
        _branch = '선택없음';
      });
      _syncCanSubmit();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _friendlySignupAuthError(e);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '계정을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    _positionController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _birthdayFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (_step != _SignupStep.profile && !widget.isSocialSignup) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _error = '모든 칸을 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = '로그인 세션이 만료되었습니다. 다시 로그인해 주세요.';
          _loading = false;
        });
        return;
      }
      final String uid = user.uid;

      final DocumentReference<Map<String, dynamic>> docRef = FirebaseFirestore.instance
          .collection('artifacts')
          .doc(FirestorePaths.appId)
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('main');

      await docRef.set(<String, dynamic>{
        'uid': uid,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'branch': _branch,
        'position': _positionController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'phone': _phoneController.text.trim(),
        'joinedAt': null,
        'leavedAt': null,
        'employmentStatus': 'active', // active|leave|retired
        'mainAdmin': false,
        'roleIdx': 1,
        'hqViewerMode': true,
        'branchName': _branch,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // users/{uid} 문서도 만들어두면 관리자 설정 화면에서 목록 조회가 쉬워집니다.
      await FirestorePaths.usersCol().doc(uid).set(<String, dynamic>{
        'uid': uid,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'displayName': _nameController.text.trim(),
        'branch': _branch,
        'branchName': _branch,
        'joinedAt': null,
        'leavedAt': null,
        'employmentStatus': 'active',
        'mainAdmin': false,
        'roleIdx': 1,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.code == 'permission-denied'
            ? '프로필 저장 권한이 없습니다. 관리자에게 Firestore 규칙을 확인해 달라고 요청하세요.'
            : '저장에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 18,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: SelectionArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  (widget.isSocialSignup || _step == _SignupStep.profile)
                                      ? '회원가입 (2/2)'
                                      : '회원가입 (1/2)',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.isSocialSignup ||
                                    _step == _SignupStep.profile)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      widget.isSocialSignup
                                          ? 'Google 계정으로 로그인되었습니다. 아래는 이메일 가입 2단계와 동일합니다. '
                                              '성명·사업소·직책·생일·연락처를 입력해 주세요. 사업소 목록은 로그인된 뒤에만 불러옵니다.'
                                          : '성명·사업소·직책·생일·연락처를 입력해 주세요. 사업소 목록은 로그인된 뒤에만 불러옵니다.',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  )
                                else if (_step == _SignupStep.credentials)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      '이메일·비밀번호로 계정만 만든 뒤, 다음 화면에서 사업소 등 정보를 입력합니다.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.isSocialSignup)
                            TextButton.icon(
                              onPressed: _loading ? null : _exitWithoutSaving,
                              icon: Icon(Icons.logout_rounded, size: 18, color: Colors.grey.shade700),
                              label: Text(
                                '로그아웃',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!widget.isSocialSignup && _step == _SignupStep.credentials) ...<Widget>[
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: '이메일',
                            hintText: 'you@example.com',
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
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
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
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _passwordConfirmController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: '비밀번호 확인',
                                ),
                                validator: (String? value) {
                                  final String v = value ?? '';
                                  if (v.isEmpty) {
                                    return '비밀번호 확인을 입력해 주세요.';
                                  }
                                  if (v != _passwordController.text) {
                                    return '비밀번호가 일치하지 않습니다.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else ...<Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: '이메일',
                                  filled: widget.isSocialSignup,
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
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: '성명',
                                ),
                                maxLength: 10,
                                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                buildCounter: (
                                  BuildContext context, {
                                  required int currentLength,
                                  required bool isFocused,
                                  required int? maxLength,
                                }) =>
                                    null,
                                validator: (String? value) {
                                  final String v = (value ?? '').trim();
                                  if (v.isEmpty) {
                                    return '성명을 입력해 주세요.';
                                  }
                                  if (v.length > 10) {
                                    return '성명은 10자 이내로 입력해 주세요.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (widget.isSocialSignup || _step == _SignupStep.profile) ...<Widget>[
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _branchesFuture == null
                                ? const Center(
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: LoadingWidget(
                                        size: 24,
                                        duration: Duration(milliseconds: 1000),
                                      ),
                                    ),
                                  )
                                : FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              future: _branchesFuture,
                              builder: (
                                BuildContext context,
                                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
                              ) {
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: LoadingWidget(
                                        size: 24,
                                        duration: Duration(milliseconds: 1000),
                                      ),
                                    ),
                                  );
                                }
                                if (snap.hasError) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      DropdownButtonFormField<String>(
                                        value: '선택없음',
                                        decoration: const InputDecoration(
                                          labelText: '사업소',
                                        ),
                                        items: const <DropdownMenuItem<String>>[
                                          DropdownMenuItem<String>(
                                            value: '선택없음',
                                            child: Text('선택없음'),
                                          ),
                                        ],
                                        onChanged: (String? value) {
                                          setState(() {
                                            _branch = value ?? '선택없음';
                                            _syncCanSubmit();
                                          });
                                        },
                                        validator: (String? value) {
                                          if (value == null ||
                                              value.trim().isEmpty ||
                                              value == '선택없음') {
                                            return '사업소를 선택해 주세요.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _branchListLoadHint(snap.error),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                      if (kDebugMode && snap.error != null) ...<Widget>[
                                        const SizedBox(height: 4),
                                        SelectableText(
                                          snap.error.toString(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                }

                                final List<BranchModel> branches =
                                    (snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                                        .map(BranchModel.fromDoc)
                                        .toList()
                                      ..sort(
                                        (BranchModel a, BranchModel b) =>
                                            _signupBranchDropdownValue(a).compareTo(
                                          _signupBranchDropdownValue(b),
                                        ),
                                      );

                                if (branches.isEmpty) {
                                  if (_branch != '선택없음') {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (!mounted) {
                                        return;
                                      }
                                      setState(() {
                                        _branch = '선택없음';
                                        _syncCanSubmit();
                                      });
                                    });
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      DropdownButtonFormField<String>(
                                        value: '선택없음',
                                        decoration: const InputDecoration(
                                          labelText: '사업소',
                                        ),
                                        items: const <DropdownMenuItem<String>>[
                                          DropdownMenuItem<String>(
                                            value: '선택없음',
                                            child: Text('선택없음'),
                                          ),
                                        ],
                                        onChanged: (String? value) {
                                          setState(() {
                                            _branch = value ?? '선택없음';
                                            _syncCanSubmit();
                                          });
                                        },
                                        validator: (String? value) {
                                          if (value == null ||
                                              value.trim().isEmpty ||
                                              value == '선택없음') {
                                            return '사업소를 선택해 주세요.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '조회 경로: artifacts/${FirestorePaths.appId}/public/data/branches\n'
                                        '문서가 없거나, `FIRESTORE_APP_ID`가 실제 사업소가 있는 앱 id와 다를 수 있습니다. '
                                        '관리자 설정에서 사업소를 등록했는지 확인하세요.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                final String currentValue = branches.any(
                                        (BranchModel b) =>
                                            _signupBranchDropdownValue(b) == _branch)
                                    ? _branch
                                    : _signupBranchDropdownValue(branches.first);

                                if (_branch != currentValue) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (!mounted) {
                                      return;
                                    }
                                    setState(() {
                                      _branch = currentValue;
                                      _syncCanSubmit();
                                    });
                                  });
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    DropdownButtonFormField<String>(
                                      value: currentValue,
                                      decoration: const InputDecoration(
                                        labelText: '사업소',
                                      ),
                                      items: branches
                                          .map(
                                            (BranchModel b) => DropdownMenuItem<String>(
                                              value: _signupBranchDropdownValue(b),
                                              child: Text(_signupBranchDropdownValue(b)),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (String? value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _branch = value;
                                          _syncCanSubmit();
                                        });
                                      },
                                      validator: (String? value) {
                                        if (value == null ||
                                            value.trim().isEmpty ||
                                            value == '선택없음') {
                                          return '사업소를 선택해 주세요.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _positionController,
                              decoration: const InputDecoration(
                                labelText: '직책',
                              ),
                              maxLength: 10,
                              maxLengthEnforcement: MaxLengthEnforcement.enforced,
                              buildCounter: (
                                BuildContext context, {
                                required int currentLength,
                                required bool isFocused,
                                required int? maxLength,
                              }) =>
                                  null,
                              validator: (String? value) {
                                final String v = (value ?? '').trim();
                                if (v.isEmpty) {
                                  return '직책을 입력해 주세요.';
                                }
                                if (v.length > 10) {
                                  return '직책은 10자 이내로 입력해 주세요.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _birthdayController,
                              focusNode: _birthdayFocus,
                              decoration: const InputDecoration(
                                labelText: '생일 (MM/DD)',
                                hintText: '08/15',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: const <TextInputFormatter>[
                                _BirthdayMmddFormatter(),
                              ],
                              onChanged: (String v) {
                                // 숫자 4개 입력 완료 시 다음 칸(연락처)로 이동
                                final String digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                                if (digits.length >= 4) {
                                  FocusScope.of(context).requestFocus(_phoneFocus);
                                }
                              },
                              validator: (String? value) {
                                final String v = (value ?? '').trim();
                                if (v.isEmpty) {
                                  return '생일을 입력해 주세요.';
                                }
                                return _validateBirthdayMmdd(v);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: '연락처',
                                hintText: '010-0000-0000',
                              ),
                              focusNode: _phoneFocus,
                              keyboardType: TextInputType.phone,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                              validator: (String? value) {
                                final String v = (value ?? '').trim();
                                if (v.isEmpty) {
                                  return '연락처를 입력해 주세요.';
                                }
                                if (v.replaceAll(RegExp(r'[^0-9]'), '').length != v.length) {
                                  return '연락처는 숫자만 입력해 주세요.';
                                }
                                if (v.length != 11) {
                                  return '연락처는 숫자 11자리로 입력해 주세요.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '입사일자는 관리자에 의해 별도 등록됩니다.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      ],
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: _loading ? null : _exitWithoutSaving,
                            child: const Text('취소'),
                          ),
                          if (!widget.isSocialSignup && _step == _SignupStep.profile) ...<Widget>[
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: _loading ? null : _backToCredentialsFromProfile,
                              child: const Text('이전'),
                            ),
                          ],
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: (_loading || !_canSubmit)
                                ? null
                                : (widget.isSocialSignup || _step == _SignupStep.profile
                                    ? _submitProfile
                                    : _submitCredentials),
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: LoadingWidget(size: 18, duration: Duration(milliseconds: 1000)),
                                  )
                                : Text(
                                    widget.isSocialSignup
                                        ? '저장 후 시작'
                                        : (_step == _SignupStep.credentials ? '다음' : '가입 완료'),
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
    );
  }
}

