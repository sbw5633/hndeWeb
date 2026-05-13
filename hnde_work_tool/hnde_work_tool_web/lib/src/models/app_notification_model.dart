import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.branchNames,
    required this.targetUids,
    required this.readAt,
    required this.payload,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Timestamp? createdAt;
  final List<String> branchNames;
  final List<String> targetUids;
  final Timestamp? readAt;
  final Map<String, dynamic> payload;

  bool get isRead => readAt != null;

  factory AppNotificationModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    final Map<String, dynamic> payload = (d['payload'] is Map)
        ? (d['payload'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final List<String> branches = (d['branchNames'] is List)
        ? (d['branchNames'] as List)
            .map((dynamic e) => e.toString().trim())
            .where((String e) => e.isNotEmpty)
            .toList()
        : <String>[];
    final List<String> targets = (d['targetUids'] is List)
        ? (d['targetUids'] as List)
            .map((dynamic e) => e.toString().trim())
            .where((String e) => e.isNotEmpty)
            .toList()
        : <String>[];
    return AppNotificationModel(
      id: doc.id,
      type: (d['type'] as String?)?.trim() ?? 'unknown',
      title: (d['title'] as String?)?.trim() ?? '',
      body: (d['body'] as String?)?.trim() ?? '',
      createdAt: d['createdAt'] as Timestamp?,
      branchNames: branches,
      targetUids: targets,
      readAt: d['readAt'] as Timestamp?,
      payload: payload,
    );
  }
}

