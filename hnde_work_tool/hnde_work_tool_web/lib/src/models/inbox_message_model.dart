import 'package:cloud_firestore/cloud_firestore.dart';

class InboxMessageModel {
  const InboxMessageModel({
    required this.id,
    required this.senderUid,
    required this.receiverUid,
    required this.body,
    this.read = false,
    this.createdAt,
    this.senderDisplay = '',
  });

  final String id;
  final String senderUid;
  final String receiverUid;
  final String body;
  final bool read;
  final Timestamp? createdAt;
  final String senderDisplay;

  factory InboxMessageModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    return InboxMessageModel(
      id: doc.id,
      senderUid: d['senderUid'] as String? ?? '',
      receiverUid: d['receiverUid'] as String? ?? '',
      body: d['body'] as String? ?? '',
      read: d['read'] as bool? ?? false,
      createdAt: d['createdAt'] as Timestamp?,
      senderDisplay: d['senderDisplay'] as String? ?? '',
    );
  }

  Map<String, dynamic> toCreateMap() {
    return <String, dynamic>{
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'body': body,
      'read': read,
      'createdAt': FieldValue.serverTimestamp(),
      'senderDisplay': senderDisplay,
    };
  }
}
