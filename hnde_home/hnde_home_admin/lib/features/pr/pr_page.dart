import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ci_page.dart';
import 'press_release_page.dart';
import 'customer_event_page.dart';

class PRPage extends ConsumerWidget {
  const PRPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('홍보센터 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuCard(
            icon: Icons.info,
            title: 'CI 소개',
            description: 'CI 의미 및 정의 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CIPage()),
            ),
          ),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.article,
            title: '보도자료',
            description: '보도자료 목록 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PressReleasePage()),
            ),
          ),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.event,
            title: '고객이벤트',
            description: '고객이벤트 목록 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerEventPage()),
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

