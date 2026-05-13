import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/culture_day_event_item.dart';
import '../../repositories/culture_day_repository.dart';
import '../common/enterprise_scaffold.dart';

/// 문화의 날: **Firestore에 구조화되어 올라온 행사 번들만** 표시합니다.
/// (TourAPI 직접 호출 없음 — 수집은 관리자 AI/n8n 파이프라인이 담당)
class CultureListPage extends StatefulWidget {
  const CultureListPage({super.key});

  @override
  State<CultureListPage> createState() => _CultureListPageState();
}

class _CultureListPageState extends State<CultureListPage> {
  final CultureDayRepository _repo = CultureDayRepository();
  late String _monthKey;

  static String _monthKeyFromDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _monthKey = _monthKeyFromDate(DateTime.now());
  }

  List<String> _monthChoices() {
    final DateTime now = DateTime.now();
    final List<String> keys = <String>[];
    for (int i = -6; i <= 12; i++) {
      final DateTime m = DateTime(now.year, now.month + i, 1);
      keys.add(_monthKeyFromDate(m));
    }
    return keys.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const EnterpriseScaffold(
        title: '문화의 날 정보',
        child: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return EnterpriseScaffold(
      title: '문화의 날 정보',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: <Widget>[
                const Text(
                  '표시 월',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _monthKey,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String k in _monthChoices())
                        DropdownMenuItem<String>(
                          value: k,
                          child: Text(k),
                        ),
                    ],
                    onChanged: (String? v) {
                      if (v == null) {
                        return;
                      }
                      setState(() => _monthKey = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '이 화면은 Firestore `culture_day_bundles/$_monthKey` 데이터만 보여 줍니다. '
              '데이터가 없으면 관리자 설정 → 문화의 날(AI)에서 수집을 요청하세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _repo.watchBundleDoc(_monthKey),
              builder: (
                BuildContext context,
                AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
              ) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '불러오기 실패\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final Map<String, dynamic>? data = snap.data?.data();
                if (data == null || !snap.data!.exists) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '$_monthKey 월에 게시된 행사 번들이 없습니다.\n'
                        '관리자가 AI 수집 후 `culture_day_bundles/$_monthKey` 문서를 채우면 여기에 표시됩니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.35,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  );
                }
                final List<CultureDayEventItem> items =
                    CultureDayRepository.parseItems(data);
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '번들 문서는 있으나 `items`(또는 `events`) 배열이 비어 있습니다.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 248,
                  ),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int i) {
                    final CultureDayEventItem e = items[i];
                    return _EventCard(
                      item: e,
                      onTap: () => context.push(
                        '/culture-day/detail/${Uri.encodeComponent(e.id)}'
                        '?month=${Uri.encodeComponent(_monthKey)}',
                        extra: e.toJson(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item, required this.onTap});

  final CultureDayEventItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? img = item.imageUrl?.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (img != null && img.isNotEmpty)
                Image.network(
                  img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade400,
                    alignment: Alignment.center,
                    child: const Icon(Icons.event, size: 48, color: Colors.white),
                  ),
                )
              else
                Container(
                  color: Colors.grey.shade400,
                  alignment: Alignment.center,
                  child: const Icon(Icons.event, size: 48, color: Colors.white),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (item.startDate != null || item.endDate != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '${item.startDate ?? '-'} ~ ${item.endDate ?? '-'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
