import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/business_proposal_submission.dart';
import '../../models/rest_area.dart';

class BusinessProposalPage extends ConsumerWidget {
  const BusinessProposalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposals = ref.watch(businessProposalListProvider);
    final userInfo = ref.watch(currentUserInfoProvider);
    final restAreas = ref.watch(restAreaListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('사업제안')),
      body: userInfo.when(
        data: (user) {
          return restAreas.when(
            data: (restAreaList) {
              return proposals.when(
                data: (items) {
                  // 휴게소 관리자인 경우 본인 소속 휴게소로 온 글만 필터링
                  final filteredItems = user?.isRestAreaManager == true && user?.restAreaId != null
                      ? items.where((item) => item.restAreaId == user!.restAreaId).toList()
                      : items;

                  if (filteredItems.isEmpty) {
                    return const Center(child: Text('제출된 사업제안이 없습니다.'));
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
                          title: Text(item.proposalTitle),
                          subtitle: Text(
                            '${item.companyName} | ${restArea.name} | ${DateFormat('yyyy-MM-dd').format(item.createdAt)}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(label: '회사명', value: item.companyName),
                                  _InfoRow(label: '대표자', value: item.representative),
                                  _InfoRow(label: '이메일', value: item.email),
                                  _InfoRow(label: '전화번호', value: item.phone),
                                  _InfoRow(label: '사업분야', value: item.businessType),
                                  _InfoRow(label: '선택한 사업장', value: restArea.name),
                                  const Divider(),
                                  const Text(
                                    '제안내용',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.proposalContent,
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
