import 'package:flutter/material.dart';

/// Shell(`WorkAppShell`) 안에서만 사용: 사이드바/앱바 없이 본문 영역만.
/// `Column` + `Expanded` 가 동작하도록 가용 높이를 [SizedBox.height]로 고정합니다.
class EnterpriseScaffold extends StatelessWidget {
  const EnterpriseScaffold({
    required this.title,
    required this.child,
    this.useFullWidth = false,
    super.key,
  });

  /// 접근성/향후 확장용 (현재 UI는 셸의 포털 제목을 사용)
  final String title;
  final Widget child;

  /// `true`이면 본문이 브라우저 가로 전체를 씁니다(기본은 1440px 상한).
  final bool useFullWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = useFullWidth
            ? constraints.maxWidth
            : (constraints.maxWidth > 1440 ? 1440 : constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: w,
            height: constraints.maxHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SelectionArea(
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
