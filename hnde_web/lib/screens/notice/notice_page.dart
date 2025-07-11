import 'package:flutter/material.dart';
import 'write_notice_page.dart';

class NoticePage extends StatelessWidget {
  const NoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '공지사항 쓰기',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WriteNoticePage()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: const [
          ListTile(
            title: Text('6월 전체공지'),
            subtitle: Text('전 직원 대상 필독 공지입니다.'),
            trailing: Icon(Icons.chevron_right),
          ),
          ListTile(
            title: Text('연차 사용 안내'),
            subtitle: Text('연차 신청 및 사용 방법 안내.'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
} 