import 'package:flutter/material.dart';

/// Shell(`WorkAppShell`) 안에서만 사용: 사이드바/앱바 없이 본문 영역만.
/// `Column` + `Expanded` 가 동작하도록 가용 높이를 [SizedBox.height]로 고정합니다.
class EnterpriseScaffold extends StatelessWidget {
  const EnterpriseScaffold({
    required this.title,
    required this.child,
    super.key,
  });

  /// 접근성/향후 확장용 (현재 UI는 셸의 포털 제목을 사용)
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth > 1440 ? 1440 : constraints.maxWidth;
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
