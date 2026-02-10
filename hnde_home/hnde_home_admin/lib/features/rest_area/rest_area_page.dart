import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'rest_area_list_page.dart';
import 'rest_area_edit_page.dart';
import '../../providers/auth_provider.dart';

class RestAreaPage extends ConsumerWidget {
  const RestAreaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userInfo = ref.watch(currentUserInfoProvider);

    return userInfo.when(
      data: (user) {
        final isRestAreaManager = user?.isRestAreaManager ?? false;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('휴게소 사업 관리'),
            actions: [
              // 관리자만 추가 버튼 표시
              if (!isRestAreaManager)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RestAreaEditPage()),
                  ),
                ),
            ],
          ),
          body: const RestAreaListPage(),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => const Scaffold(
        body: Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
      ),
    );
  }
}

