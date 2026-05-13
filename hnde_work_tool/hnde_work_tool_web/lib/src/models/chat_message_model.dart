import 'package:cloud_firestore/cloud_firestore.dart';

/// `conversations/{conversationId}/messages/{messageId}`
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUid,
    required this.body,
    this.senderDisplay = '',
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderUid;
  final String senderDisplay;
  final String body;
  final Timestamp? createdAt;

  factory ChatMessageModel.fromDoc(
    String conversationId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    return ChatMessageModel(
      id: doc.id,
      conversationId: conversationId,
      senderUid: d['senderUid'] as String? ?? '',
      senderDisplay: d['senderDisplay'] as String? ?? '',
      body: d['body'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'senderUid': senderUid,
      'senderDisplay': senderDisplay,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'id': id,
      'senderUid': senderUid,
      'senderDisplay': senderDisplay,
      'body': body,
      'createdAtMs': createdAt?.millisecondsSinceEpoch,
    };
  }

  static ChatMessageModel fromCacheMap(
    String conversationId,
    Map<String, dynamic> m,
  ) {
    final int? ms = (m['createdAtMs'] as num?)?.toInt();
    return ChatMessageModel(
      id: (m['id'] as String?) ?? '',
      conversationId: conversationId,
      senderUid: (m['senderUid'] as String?) ?? '',
      senderDisplay: (m['senderDisplay'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      createdAt: ms == null ? null : Timestamp.fromMillisecondsSinceEpoch(ms),
    );
  }
}
