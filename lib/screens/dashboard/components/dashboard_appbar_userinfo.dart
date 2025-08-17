import 'package:flutter/material.dart';

class DashboardAppBarUserInfo extends StatelessWidget {
  final bool loggedIn;
  final String? name;
  final String? position;
  final String? branch;
  final void Function(String id, String pw)? onLogin;
  final VoidCallback? onRegister;
  final VoidCallback? onLogout;
  const DashboardAppBarUserInfo({
    super.key,
    required this.loggedIn,
    this.name,
    this.position,
    this.branch,
    this.onLogin,
    this.onRegister,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/images/logo.horizontal.png', width: 48, height: 48),
        const SizedBox(width: 16),
        Expanded(
          child: loggedIn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(position ?? '', style: const TextStyle(fontSize: 13)),
                    Text(branch ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    if (onLogout != null)
                      TextButton(onPressed: onLogout, child: const Text('로그아웃')),
                  ],
                )
              : _LoginForm(onLogin: onLogin, onRegister: onRegister),
        ),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  final void Function(String id, String pw)? onLogin;
  final VoidCallback? onRegister;
  const _LoginForm({this.onLogin, this.onRegister});
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _idController,
            decoration: const InputDecoration(hintText: '아이디'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _pwController,
            decoration: const InputDecoration(hintText: '비밀번호'),
            obscureText: true,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => widget.onLogin?.call(_idController.text, _pwController.text),
          child: const Text('로그인'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: widget.onRegister,
          child: const Text('회원가입'),
        ),
      ],
    );
  }
} 