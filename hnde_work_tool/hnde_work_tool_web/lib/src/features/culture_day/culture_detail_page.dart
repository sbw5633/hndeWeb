import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/culture_day_event_item.dart';
import '../../repositories/culture_day_repository.dart';

/// Firestore에 올라온 **문화의 날 행사 1건** 상세.
///
/// - 우선 `extra`로 넘어온 JSON을 사용하고,
/// - 없으면 `month` 쿼리 + `contentId`로 번들에서 해당 행사를 찾습니다.
class CultureDetailPage extends StatefulWidget {
  const CultureDetailPage({
    super.key,
    required this.contentId,
    this.monthKey,
    this.preview,
  });

  /// 행사 id (`CultureDayEventItem.id`)
  final String contentId;
  /// 목록에서 넘긴 `yyyy-MM` (URL 쿼리 `month` 와 동일)
  final String? monthKey;
  /// [CultureDayEventItem.toJson()] 맵
  final Object? preview;

  @override
  State<CultureDetailPage> createState() => _CultureDetailPageState();
}

class _CultureDetailPageState extends State<CultureDetailPage> {
  final CultureDayRepository _repo = CultureDayRepository();

  CultureDayEventItem? _fromPreview() {
    final Object? p = widget.preview;
    if (p is Map<String, dynamic>) {
      return CultureDayEventItem.tryFromMap(p);
    }
    if (p is Map) {
      return CultureDayEventItem.tryFromMap(
        Map<String, dynamic>.from(p),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final CultureDayEventItem? instant = _fromPreview();
    if (instant != null && instant.id == widget.contentId) {
      return _scaffoldFor(context, instant);
    }

    final String? month = widget.monthKey?.trim();
    if (month == null || month.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('상세'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '행사를 다시 불러오려면 목록에서 열어 주세요.\n'
              '(URL에 month=yyyy-MM 쿼리가 필요합니다.)',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _repo.watchBundleDoc(month),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
      ) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('상세'),
            ),
            body: Center(child: Text('${snap.error}')),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final Map<String, dynamic>? data = snap.data?.data();
        final List<CultureDayEventItem> items =
            CultureDayRepository.parseItems(data);
        CultureDayEventItem? found;
        for (final CultureDayEventItem e in items) {
          if (e.id == widget.contentId) {
            found = e;
            break;
          }
        }
        if (found == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('상세'),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '해당 행사를 번들에서 찾지 못했습니다.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _scaffoldFor(context, found);
      },
    );
  }

  Widget _scaffoldFor(BuildContext context, CultureDayEventItem e) {
    final String? img = e.imageUrl?.trim();
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: ColoredBox(
                color: Colors.grey.shade400,
                child: img != null && img.isNotEmpty
                    ? Image.network(
                        img,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.event, size: 64, color: Colors.white),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.event, size: 64, color: Colors.white),
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    e.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (e.region != null || e.venue != null)
                    Text(
                      '${e.region ?? ''}${e.region != null && e.venue != null ? ' · ' : ''}${e.venue ?? ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (e.startDate != null || e.endDate != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '기간: ${e.startDate ?? '-'} ~ ${e.endDate ?? '-'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (e.tags != null && e.tags!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final String t in e.tags!)
                          Chip(
                            label: Text(t),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    '소개',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    (e.summary != null && e.summary!.trim().isNotEmpty)
                        ? e.summary!.trim()
                        : '요약이 없습니다.',
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                  if (e.detailUrl != null && e.detailUrl!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    SelectableText(
                      '링크: ${e.detailUrl}',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
