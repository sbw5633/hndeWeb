import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/kakao_api_config.dart';
import '../../services/kakao_local_service.dart';

/// 카카오 주소 검색 다이얼로그 — 선택 시 [KakaoAddressPick] 반환
Future<KakaoAddressPick?> showKakaoAddressSearchDialog(BuildContext context) {
  return showDialog<KakaoAddressPick>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) => const _AddressSearchDialog(),
  );
}

class _AddressSearchDialog extends StatefulWidget {
  const _AddressSearchDialog();

  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  final TextEditingController _query = TextEditingController();
  final KakaoLocalService _api = KakaoLocalService();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<KakaoAddressPick> _results = <KakaoAddressPick>[];
  Offset _dragOffset = Offset.zero;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch();
    });
  }

  Future<void> _runSearch() async {
    final String q = _query.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = <KakaoAddressPick>[];
        _error = null;
      });
      return;
    }
    if (!KakaoApiConfig.canSearchLocal) {
      setState(() {
        _error =
            '지도 검색을 사용하려면 R2_WORKER_URL_PROD 또는 KAKAO_REST_API_KEY 가 필요합니다. env.worker / env.kakao 를 확인하세요.';
        _results = <KakaoAddressPick>[];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<KakaoAddressPick> list = await _api.searchAddress(q);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = list;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$e';
        _results = <KakaoAddressPick>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      clipBehavior: Clip.antiAlias,
      child: Transform.translate(
        offset: _dragOffset,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Material(
            color: theme.colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (DragUpdateDetails d) {
                      setState(() {
                        _dragOffset += d.delta;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.drag_indicator,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '주소 검색 (제목 줄을 드래그해 이동)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '닫기',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _query,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '장소·건물·주소 검색',
                          hintText: '예: 스타벅스 강남역 / 송도과학로 32',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _scheduleSearch(),
                        onSubmitted: (_) => _runSearch(),
                      ),
                      const SizedBox(height: 8),
                      if (_error != null)
                        SelectableText(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 340,
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _results.isEmpty
                                ? Center(
                                    child: SelectableText(
                                      _query.text.trim().length < 2
                                          ? '두 글자 이상 입력하세요.'
                                          : '검색 결과가 없습니다.',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _results.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder:
                                        (BuildContext context, int i) {
                                      final KakaoAddressPick p = _results[i];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  SelectableText(
                                                    p.placeName.trim().isEmpty
                                                        ? p.displayLine
                                                        : p.placeName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (p.addressLine.trim().isNotEmpty &&
                                                      p.addressLine.trim() != p.placeName.trim())
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: SelectableText(
                                                        p.addressLine,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  SelectableText(
                                                    '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors
                                                          .grey.shade700,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(p),
                                              child: const Text('선택'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
