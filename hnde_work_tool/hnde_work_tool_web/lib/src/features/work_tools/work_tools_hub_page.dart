import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/enterprise_scaffold.dart';

const Color _navy = Color(0xFF1E3A8A);
const double _cardW = 280;
const double _cardH = 100;

/// 회사정보 허브와 동일: `/work-tools`에서 그룹별 카드로 각 도구 페이지로 이동 (이중 사이드바 없음)
class WorkToolsHubPage extends StatelessWidget {
  const WorkToolsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return EnterpriseScaffold(
      title: '업무 도구',
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '업무 도구',
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
              '아래에서 사용할 도구를 선택하세요.',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 28),
            _Group(
              title: 'PDF',
              subtitle: '문서 병합·분할',
              children: <Widget>[
                _ToolCard(
                  icon: Icons.merge_type_rounded,
                  title: 'PDF 합치기',
                  subtitle: '여러 PDF를 하나로 합칩니다.',
                  onTap: () => context.go('/work-tools/pdf-merge'),
                ),
                _ToolCard(
                  icon: Icons.call_split_rounded,
                  title: 'PDF 분할',
                  subtitle: 'PDF를 페이지 단위로 나눕니다.',
                  onTap: () => context.go('/work-tools/pdf-split'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Group(
              title: '파일',
              subtitle: '일괄 이름·정리',
              children: <Widget>[
                _ToolCard(
                  icon: Icons.drive_file_rename_outline_rounded,
                  title: '파일명 편집',
                  subtitle: '규칙에 따라 파일 이름을 바꿉니다.',
                  onTap: () => context.go('/work-tools/file-rename'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Group(
              title: '이미지',
              subtitle: '편집·콜라주·압축',
              children: <Widget>[
                _ToolCard(
                  icon: Icons.tune_rounded,
                  title: '이미지 편집',
                  subtitle: '자르기·회전 등 기본 편집.',
                  onTap: () => context.go('/work-tools/image-edit'),
                ),
                _ToolCard(
                  icon: Icons.grid_view_rounded,
                  title: '이미지 콜라주',
                  subtitle: '여러 이미지를 한 장으로 배치.',
                  onTap: () => context.go('/work-tools/image-collage'),
                ),
                _ToolCard(
                  icon: Icons.compress_rounded,
                  title: '이미지 압축',
                  subtitle: '용량을 줄입니다.',
                  onTap: () => context.go('/work-tools/image-compress'),
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

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: children,
        ),
      ],
    );
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({
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
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
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
