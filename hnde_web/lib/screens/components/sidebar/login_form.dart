import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/register_screen.dart';
import '../../../core/auth_provider.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();

  TextField loginTextField(
      {required TextEditingController controller,
      required String label,
      bool? obscureText}) {
    final hintText = label == '아이디' ? '아이디' : '비밀번호';

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        //아래테두리만 표시
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      style: const TextStyle(fontSize: 12),
      obscureText: obscureText ?? false,
    );
  }

  void _showLoginErrorDialog(BuildContext context) {
    _showToast(context, '이메일 또는 비밀번호를 확인해주세요.');
  }

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 80,
                  child:
                      loginTextField(controller: _idController, label: '아이디'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  child: loginTextField(
                    controller: _pwController,
                    label: '비밀번호',
                    obscureText: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            final authProvider = context.read<AuthProvider>();
            final success = await authProvider.login(_idController.text, _pwController.text);
            if (!success && mounted) {
              _showLoginErrorDialog(context);
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(60, 40),
            maximumSize: const Size(80, 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
            foregroundColor: Colors.white,
          ),
          child: const Text('로그인'),
        ),
        const SizedBox(height: 4),
                 TextButton(
           onPressed: () {
             Navigator.of(context).push(
               MaterialPageRoute(builder: (_) => const RegisterScreen()),
             );
           },
           child: const Text('회원가입', style: TextStyle(color: Colors.white)),
         ),
      ],
    );
  }
}
