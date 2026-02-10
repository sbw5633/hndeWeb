import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company_info.dart';

class FooterSection extends StatelessWidget {
  final CompanyInfo companyInfo;

  const FooterSection({
    super.key,
    required this.companyInfo,
  });

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: const EdgeInsets.only(left: 80, right: 80, top: 60, bottom: 60),
      color: Colors.blue[900],
      child: Column(
        children: [
          if (!isMobile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyInfo.name,
                        style: GoogleFonts.roboto(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        companyInfo.description,
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '연락처 정보',
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ContactItem(
                        icon: Icons.location_on,
                        text: companyInfo.contact['address']!,
                      ),
                      const SizedBox(height: 12),
                      _ContactItem(
                        icon: Icons.phone,
                        text: companyInfo.contact['phone']!,
                      ),
                      const SizedBox(height: 12),
                      _ContactItem(
                        icon: Icons.email,
                        text: companyInfo.contact['email']!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '빠른 링크',
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FooterLink(
                        text: '회사 소개',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _FooterLink(
                        text: '사업 분야',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _FooterLink(
                        text: '프로젝트',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _FooterLink(
                        text: '공지사항',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyInfo.name,
                  style: GoogleFonts.roboto(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '연락처 정보',
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _ContactItem(
                  icon: Icons.location_on,
                  text: companyInfo.contact['address']!,
                ),
                const SizedBox(height: 12),
                _ContactItem(
                  icon: Icons.phone,
                  text: companyInfo.contact['phone']!,
                ),
                const SizedBox(height: 12),
                _ContactItem(
                  icon: Icons.email,
                  text: companyInfo.contact['email']!,
                ),
              ],
            ),
          const SizedBox(height: 40),
          Divider(
            color: Colors.white.withOpacity(0.2),
            thickness: 1,
          ),
          const SizedBox(height: 24),
          Text(
            '© 2024 ${companyInfo.name}. All rights reserved.',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.white70,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _FooterLink({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
    );
  }
}
