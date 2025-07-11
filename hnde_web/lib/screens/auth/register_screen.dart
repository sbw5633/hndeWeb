import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: '이름'),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: '소속(지점/본사)'),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              child: const Text('회원가입'),
            ),
          ],
        ),
      ),
    );
  }
} 