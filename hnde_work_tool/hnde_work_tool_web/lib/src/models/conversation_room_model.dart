import 'package:cloud_firestore/cloud_firestore.dart';

String? _trimmedNonEmpty(String? v) {
  final String t = (v ?? '').trim();
  return t.isEmpty ? null : t;
}

/// 1:1 또는 그룹 대화방 메타 (`conversations/{id}`)
class ConversationRoomModel {
  const ConversationRoomModel({
    required this.id,
    required this.type,
    required this.participantUids,
    this.groupTitle,
    this.groupPhotoUrl,
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.lastMessageSenderUid = '',
    this.memberReadAt,
    this.memberUnreadCount,
    this.updatedAt,
  });

  static const String typeDirect = 'direct';
  static const String typeGroup = 'group';

  final String id;
  /// `direct` | `group`
  final String type;
  final List<String> participantUids;
  final String? groupTitle;
  /// 그룹방 대표 이미지 URL(개설자 지정, 선택)
  final String? groupPhotoUrl;
  final String lastMessagePreview;
  final Timestamp? lastMessageAt;
  final String lastMessageSenderUid;
  final Map<String, Timestamp>? memberReadAt;
  final Map<String, int>? memberUnreadCount;
  final Timestamp? updatedAt;

  factory ConversationRoomModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data() ?? <String, dynamic>{};
    final List<dynamic>? pu = d['participantUids'] as List<dynamic>?;
    final Map<String, dynamic>? mra =
        d['memberReadAt'] as Map<String, dynamic>?;
    final Map<String, Timestamp>? readMap = mra == null
        ? null
        : mra.map(
            (String k, dynamic v) => MapEntry<String, Timestamp>(
              k,
              v is Timestamp ? v : Timestamp.now(),
            ),
          );
    final Map<String, dynamic>? muc =
        d['memberUnreadCount'] as Map<String, dynamic>?;
    final Map<String, int>? unreadMap = muc == null
        ? null
        : muc.map(
            (String k, dynamic v) => MapEntry<String, int>(
              k,
              (v as num?)?.toInt() ?? 0,
            ),
          );
    return ConversationRoomModel(
      id: doc.id,
      type: d['type'] as String? ?? typeDirect,
      participantUids: pu == null
          ? <String>[]
          : pu.map((dynamic e) => e.toString()).toList(),
      groupTitle: d['groupTitle'] as String?,
      groupPhotoUrl: _trimmedNonEmpty(d['groupPhotoUrl'] as String?),
      lastMessagePreview: d['lastMessagePreview'] as String? ?? '',
      lastMessageAt: d['lastMessageAt'] as Timestamp?,
      lastMessageSenderUid: d['lastMessageSenderUid'] as String? ?? '',
      memberReadAt: readMap,
      memberUnreadCount: unreadMap,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'type': type,
      'participantUids': participantUids,
      'groupTitle': groupTitle,
      'groupPhotoUrl': groupPhotoUrl,
      'lastMessagePreview': lastMessagePreview,
      'lastMessageAtMs': lastMessageAt?.millisecondsSinceEpoch,
      'lastMessageSenderUid': lastMessageSenderUid,
      'memberReadAtMs': memberReadAt?.map(
        (String k, Timestamp v) => MapEntry<String, int>(k, v.millisecondsSinceEpoch),
      ),
      'memberUnreadCount': memberUnreadCount,
      'updatedAtMs': updatedAt?.millisecondsSinceEpoch,
    };
  }

  static ConversationRoomModel fromCacheMap(
    String conversationId,
    Map<String, dynamic> m,
  ) {
    final List<dynamic>? pu = m['participantUids'] as List<dynamic>?;
    final Map<String, dynamic>? mra = m['memberReadAtMs'] as Map<String, dynamic>?;
    final Map<String, Timestamp>? readMap = mra == null
        ? null
        : mra.map(
            (String k, dynamic v) => MapEntry<String, Timestamp>(
              k,
              Timestamp.fromMillisecondsSinceEpoch((v as num?)?.toInt() ?? 0),
            ),
          );
    final Map<String, dynamic>? muc =
        m['memberUnreadCount'] as Map<String, dynamic>?;
    final Map<String, int>? unreadMap = muc == null
        ? null
        : muc.map(
            (String k, dynamic v) =>
                MapEntry<String, int>(k, (v as num?)?.toInt() ?? 0),
          );
    final int? lastMs = (m['lastMessageAtMs'] as num?)?.toInt();
    final int? updMs = (m['updatedAtMs'] as num?)?.toInt();
    return ConversationRoomModel(
      id: conversationId,
      type: m['type'] as String? ?? typeDirect,
      participantUids: pu == null
          ? <String>[]
          : pu.map((dynamic e) => e.toString()).toList(),
      groupTitle: m['groupTitle'] as String?,
      groupPhotoUrl: _trimmedNonEmpty(m['groupPhotoUrl'] as String?),
      lastMessagePreview: m['lastMessagePreview'] as String? ?? '',
      lastMessageAt: lastMs == null ? null : Timestamp.fromMillisecondsSinceEpoch(lastMs),
      lastMessageSenderUid: m['lastMessageSenderUid'] as String? ?? '',
      memberReadAt: readMap,
      memberUnreadCount: unreadMap,
      updatedAt: updMs == null ? null : Timestamp.fromMillisecondsSinceEpoch(updMs),
    );
  }

  int unreadCountFor(String myUid) {
    final int n = memberUnreadCount?[myUid] ?? 0;
    if (n > 0) return n;
    // 레거시/미구현 데이터에 대한 최소 보정
    return hasUnreadFor(myUid) ? 1 : 0;
  }

  bool hasUnreadFor(String myUid) {
    if (lastMessageAt == null || lastMessageSenderUid == myUid) {
      return false;
    }
    final Timestamp? myRead = memberReadAt?[myUid];
    if (myRead == null) {
      return true;
    }
    return lastMessageAt!.millisecondsSinceEpoch >
        myRead.millisecondsSinceEpoch;
  }
}
