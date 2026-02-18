import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import '../models/business_type.dart';

class Footer extends StatelessWidget {
  final Function(String menuId, String? subMenuId)? onMenuTap;

  const Footer({
    super.key,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final currentYear = DateTime.now().year;
    final onMenuTap = this.onMenuTap;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 40 : 80,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1920),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 회사 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'H&DE',
                          style: GoogleFonts.notoSans(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '주식회사 에이치앤디이',
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '서울특별시 강남구 대치동',
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 사업 분야
                  Expanded(
                    child: FutureBuilder<List<BusinessType>>(
                      future: DataService().getBusinessTypeList(),
                      builder: (context, snapshot) {
                        final defaultLinks = [
                          _FooterLink(
                            text: '휴게소사업',
                            onTap: () => onMenuTap?.call('business', 'restarea'),
                          ),
                          const SizedBox(height: 8),
                          _FooterLink(
                            text: '제조유통사업',
                            onTap: () => onMenuTap?.call('business', 'manufacturing'),
                          ),
                          const SizedBox(height: 8),
                          _FooterLink(
                            text: '식음료사업',
                            onTap: () => onMenuTap?.call('business', 'food'),
                          ),
                        ];
                        
                        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '사업 분야',
                                style: GoogleFonts.notoSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...defaultLinks,
                            ],
                          );
                        }
                        
                        final businessTypes = snapshot.data!;
                        final customBusinessTypes = businessTypes.where((bt) {
                          return !bt.name.contains('휴게소') &&
                              !bt.name.contains('제조유통') &&
                              !bt.name.contains('식음료');
                        }).toList();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '사업 분야',
                              style: GoogleFonts.notoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...defaultLinks,
                            ...customBusinessTypes.map((bt) => Column(
                              children: [
                                const SizedBox(height: 8),
                                _FooterLink(
                                  text: bt.name,
                                  onTap: () => onMenuTap?.call('business', bt.id),
                                ),
                              ],
                            )),
                          ],
                        );
                      },
                    ),
                  ),
                  // 회사소개
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '회사소개',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FooterLink(
                          text: 'CEO 인사말',
                          onTap: () => onMenuTap?.call('company', 'ceo'),
                        ),
                        const SizedBox(height: 8),
                        _FooterLink(
                          text: '연혁',
                          onTap: () => onMenuTap?.call('company', 'history'),
                        ),
                        const SizedBox(height: 8),
                        _FooterLink(
                          text: '경영이념 및 비전',
                          onTap: () => onMenuTap?.call('company', 'vision'),
                        ),
                        const SizedBox(height: 8),
                        _FooterLink(
                          text: '찾아오시는 길',
                          onTap: () => onMenuTap?.call('company', 'location'),
                        ),
                      ],
                    ),
                  ),
                  // 커뮤니티
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '커뮤니티',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FooterLink(
                          text: '공지사항',
                          onTap: () => onMenuTap?.call('community', 'notice'),
                        ),
                        const SizedBox(height: 8),
                        _FooterLink(
                          text: '고객의 이야기',
                          onTap: () => onMenuTap?.call('community', 'stories'),
                        ),
                        const SizedBox(height: 8),
                        _FooterLink(
                          text: '사업제안',
                          onTap: () => onMenuTap?.call('community', 'proposal'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              // 모바일 레이아웃
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'H&DE',
                    style: GoogleFonts.notoSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '주식회사 에이치앤디이',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '서울특별시 강남구 대치동',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 40),
            const Divider(
              color: Colors.grey,
              height: 1,
            ),
            const SizedBox(height: 24),
            // 저작권 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Copyright © $currentYear H&DE. All rights reserved.',
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (!isMobile)
                  Row(
                    children: [
                      Text(
                        '개인정보처리방침',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '|',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '이용약관',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (isMobile) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '개인정보처리방침',
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '|',
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '이용약관',
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
        style: GoogleFonts.notoSans(
          fontSize: 14,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}

