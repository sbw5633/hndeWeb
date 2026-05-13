import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/customer_story_submission.dart';
import '../../models/rest_area.dart';

class CustomerStoryPage extends ConsumerWidget {
  const CustomerStoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(customerStoryListProvider);
    final userInfo = ref.watch(currentUserInfoProvider);
    final restAreas = ref.watch(restAreaListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('고객의 이야기')),
      body: userInfo.when(
        data: (user) {
          return restAreas.when(
            data: (restAreaList) {
              return stories.when(
                data: (items) {
                  // 휴게소 관리자인 경우 본인 소속 휴게소로 온 글만 필터링
                  final filteredItems = user?.isRestAreaManager == true && user?.restAreaId != null
                      ? items.where((item) => item.restAreaId == user!.restAreaId).toList()
                      : items;

                  if (filteredItems.isEmpty) {
                    return const Center(child: Text('제출된 이야기가 없습니다.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      // restAreaId로 휴게소 이름 찾기
                      final restArea = restAreaList.firstWhere(
                        (ra) => ra.id == item.restAreaId,
                        orElse: () => RestArea(
                          id: '',
                          name: item.restAreaId ?? '미지정',
                          detail: RestAreaDetail(
                            intro: '',
                            awards: [],
                            stores: [],
                            foods: [],
                            facilities: [],
                            additionalItems: [],
                          ),
                        ),
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.name} | ${restArea.name} | ${DateFormat('yyyy-MM-dd').format(item.createdAt)}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(label: '이름', value: item.name),
                                  _InfoRow(label: '이메일', value: item.email),
                                  if (item.phone != null)
                                    _InfoRow(label: '전화번호', value: item.phone!),
                                  _InfoRow(label: '선택한 사업장', value: restArea.name),
                                  const Divider(),
                                  const Text(
                                    '내용',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.content,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('오류: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('오류: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const Center(child: Text('사용자 정보를 불러올 수 없습니다.')),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
