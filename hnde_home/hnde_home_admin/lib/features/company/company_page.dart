import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'ceo_greeting_page.dart';
import 'history_page.dart';
import 'vision_page.dart';
import 'location_page.dart';

class CompanyPage extends ConsumerWidget {
  const CompanyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('회사소개 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuCard(
            icon: Icons.person,
            title: 'CEO 인사말',
            description: 'CEO 인사말 내용 및 이미지 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CEOGreetingPage(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.history,
            title: '연혁',
            description: '회사 연혁 추가 및 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HistoryPage(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.visibility,
            title: '경영이념 및 비전',
            description: '경영이념 및 비전 내용 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VisionPage(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.location_on,
            title: '찾아오시는 길',
            description: '회사 위치 및 연락처 정보 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LocationPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
