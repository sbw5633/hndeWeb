import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notice_page.dart';
import 'customer_story_page.dart';
import 'business_proposal_page.dart';

class CommunityPage extends ConsumerWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('커뮤니티 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuCard(
            icon: Icons.notifications,
            title: '공지사항',
            description: '공지사항 목록 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoticePage()),
            ),
          ),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.people,
            title: '고객의 이야기',
            description: '고객이 제출한 이야기 조회',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerStoryPage()),
            ),
          ),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.business,
            title: '사업제안',
            description: '사업제안서 조회',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusinessProposalPage()),
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

