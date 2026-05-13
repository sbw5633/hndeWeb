import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class NewsItem {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String category;
  NewsItem(
      {required this.id,
      required this.title,
      required this.content,
      required this.date,
      required this.category});
  factory NewsItem.fromMap(Map<String, dynamic> m) => NewsItem(
        id: m['id'] as String,
        title: m['title'] as String,
        content: m['content'] as String,
        date: DateTime.parse(m['date'] as String),
        category: m['category'] as String,
      );
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date.toIso8601String(),
        'category': category,
      };
}

final newsListProvider =
    AsyncNotifierProvider<NewsListController, List<NewsItem>>(
        NewsListController.new);

class NewsListController extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    final data = await Supabase.instance.client
        .from('news')
        .select()
        .order('date', ascending: false);
    return (data as List<dynamic>)
        .map((e) => NewsItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(NewsItem item) async {
    final id = const Uuid().v4();
    await Supabase.instance.client.from('news').insert({
      'id': id,
      'title': item.title,
      'content': item.content,
      'date': item.date.toIso8601String(),
      'category': item.category,
    });
    state = AsyncData(await build());
  }

  Future<void> updateItem(NewsItem item) async {
    await Supabase.instance.client
        .from('news')
        .update(item.toMap())
        .eq('id', item.id);
    state = AsyncData(await build());
  }

  Future<void> remove(String id) async {
    await Supabase.instance.client.from('news').delete().eq('id', id);
    state = AsyncData(await build());
  }
}
