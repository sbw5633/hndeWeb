import 'package:flutter/material.dart';

class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('승인 대기 중')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '관리자 승인 전까지 이용이 제한됩니다.',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: 로그아웃 처리
              },
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
} 