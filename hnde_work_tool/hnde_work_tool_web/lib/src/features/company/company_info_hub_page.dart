import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/enterprise_scaffold.dart';

const Color _navy = Color(0xFF1E3A8A);
const double _cardW = 280;
const double _cardH = 100;

/// 조직도·사규집을 각각 버튼으로 진입 (탭/토글 없음)
class CompanyInfoHubPage extends StatelessWidget {
  const CompanyInfoHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: '회사정보',
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '회사정보',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _navy,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '아래에서 보실 자료를 선택하세요.',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              children: <Widget>[
                _InfoCard(
                  icon: Icons.account_tree_outlined,
                  title: '조직도',
                  subtitle: '조직도 PDF를 봅니다.',
                  onTap: () => context.go('/company-org'),
                ),
                _InfoCard(
                  icon: Icons.menu_book_outlined,
                  title: '사규집',
                  subtitle: '규정·지침 PDF를 나누어 봅니다.',
                  onTap: () => context.go('/company-rules'),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatefulWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cardW,
      height: _cardH,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: _hover ? 6 : 2,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          onHover: (bool v) => setState(() => _hover = v),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Icon(widget.icon, color: _navy, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
