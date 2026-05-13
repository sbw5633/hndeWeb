import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/company_info.dart';

class AboutSection extends StatelessWidget {
  final CompanyInfo companyInfo;

  const AboutSection({
    super.key,
    required this.companyInfo,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: 80,
      ),
      color: Colors.grey[50],
      child: Column(
        children: [
          Text(
            '회사 소개',
            style: GoogleFonts.notoSans(
              fontSize: isMobile ? 32 : 48,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 4,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 60),
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _InfoCard(
                    title: '회사 소개',
                    content: companyInfo.description,
                    icon: Icons.business,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _InfoCard(
                    title: '비전',
                    content: companyInfo.vision,
                    icon: Icons.visibility,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _InfoCard(
                    title: '미션',
                    content: companyInfo.mission,
                    icon: Icons.flag,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _InfoCard(
                  title: '회사 소개',
                  content: companyInfo.description,
                  icon: Icons.business,
                ),
                const SizedBox(height: 24),
                _InfoCard(
                  title: '비전',
                  content: companyInfo.vision,
                  icon: Icons.visibility,
                ),
                const SizedBox(height: 24),
                _InfoCard(
                  title: '미션',
                  content: companyInfo.mission,
                  icon: Icons.flag,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.notoSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: GoogleFonts.notoSans(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
