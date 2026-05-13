import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ProjectItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final DateTime completedDate;
  final List<String> tags;
  ProjectItem(
      {required this.id,
      required this.title,
      required this.description,
      required this.category,
      required this.location,
      required this.completedDate,
      required this.tags});
  factory ProjectItem.fromMap(Map<String, dynamic> m) => ProjectItem(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        category: m['category'] as String,
        location: m['location'] as String,
        completedDate: DateTime.parse(m['completed_date'] as String),
        tags: (m['tags'] as List<dynamic>).map((e) => e.toString()).toList(),
      );
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'completed_date': completedDate.toIso8601String(),
        'tags': tags,
      };
}

final projectListProvider =
    AsyncNotifierProvider<ProjectListController, List<ProjectItem>>(
        ProjectListController.new);

class ProjectListController extends AsyncNotifier<List<ProjectItem>> {
  @override
  Future<List<ProjectItem>> build() async {
    final data = await Supabase.instance.client
        .from('projects')
        .select()
        .order('completed_date', ascending: false);
    return (data as List<dynamic>)
        .map((e) => ProjectItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(ProjectItem item) async {
    final id = const Uuid().v4();
    await Supabase.instance.client.from('projects').insert({
      'id': id,
      'title': item.title,
      'description': item.description,
      'category': item.category,
      'location': item.location,
      'completed_date': item.completedDate.toIso8601String(),
      'tags': item.tags,
    });
    state = AsyncData(await build());
  }

  Future<void> updateItem(ProjectItem item) async {
    await Supabase.instance.client
        .from('projects')
        .update(item.toMap())
        .eq('id', item.id);
    state = AsyncData(await build());
  }

  Future<void> remove(String id) async {
    await Supabase.instance.client.from('projects').delete().eq('id', id);
    state = AsyncData(await build());
  }
}
