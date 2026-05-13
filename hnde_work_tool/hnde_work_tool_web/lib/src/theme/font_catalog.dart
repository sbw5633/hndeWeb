import 'dart:convert';

import 'package:flutter/services.dart';

class FontCatalog {
  FontCatalog._();

  static const String _assetPath = 'assets/fonts/font_families.json';

  static Future<List<FontCatalogItem>> loadItems() async {
    try {
      final String raw = await rootBundle.loadString(_assetPath);
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        final List<FontCatalogItem> out = <FontCatalogItem>[];
        final Set<String> seen = <String>{};
        for (final Object? e in decoded) {
          if (e is! Map) continue;
          final Map<String, dynamic> m = e.cast<String, dynamic>();
          final String family = (m['family'] as String?)?.trim() ?? '';
          final String label = (m['label'] as String?)?.trim() ?? family;
          if (family.isEmpty) continue;
          if (!seen.add(family)) continue;
          out.add(FontCatalogItem(family: family, label: label.isEmpty ? family : label));
        }
        return out;
      }
    } catch (_) {
      // ignore
    }
    return <FontCatalogItem>[
      const FontCatalogItem(family: 'NotoSansKR', label: '고딕체'),
    ];
  }
}

class FontCatalogItem {
  const FontCatalogItem({required this.family, required this.label});
  final String family;
  final String label;
}

