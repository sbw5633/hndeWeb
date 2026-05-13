import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 회사정보 허브(`/company-info`)로 돌아가기
class CompanyInfoBackBar extends StatelessWidget {
  const CompanyInfoBackBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go('/company-info'),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          label: const Text('회사정보'),
        ),
      ),
    );
  }
}
