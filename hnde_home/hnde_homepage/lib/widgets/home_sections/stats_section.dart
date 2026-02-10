import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    final stats = [
      _StatItem(
        value: '30+',
        label: '운영 휴게소',
        icon: Icons.restaurant,
      ),
      _StatItem(
        value: '40+',
        label: '운영 연수',
        icon: Icons.calendar_today,
      ),
      _StatItem(
        value: '100만+',
        label: '연간 방문객',
        icon: Icons.people,
      ),
      _StatItem(
        value: '1등급',
        label: '운영서비스 평가',
        icon: Icons.star,
      ),
    ];

    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? 40 : 80,
        right: isMobile ? 40 : 80,
        top: 80,
        bottom: 80,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[900]!,
            Colors.blue[700]!,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = isMobile ? 2 : (isTablet ? 2 : 4);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.2,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              return _StatCard(stat: stats[index]);
            },
          );
        },
      ),
    );
  }
}

class _StatItem {
  final String value;
  final String label;
  final IconData icon;

  _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            stat.icon,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            stat.value,
            style: GoogleFonts.notoSans(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stat.label,
            style: GoogleFonts.notoSans(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

