import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../models/chat_message_model.dart';
import '../../models/conversation_room_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../services/r2_storage_service.dart';
import 'messenger_dock_controller.dart';

String _messengerStaffDisplayName(Map<String, dynamic> s) {
  final String email = (s['email'] as String?)?.trim() ?? '';
  final String rawName = (s['name'] as String?)?.trim() ?? '';
  final String rawDisp = (s['displayName'] as String?)?.trim() ?? '';
  // name/displayName이 없을 수 있어, email도 uid보다 우선 표시합니다.
  // (기존: email 포함 값은 junk 처리되어 uid가 보이는 문제가 있었음)
  bool junk(String v) => v.isEmpty;
  if (!junk(rawName)) return rawName;
  if (!junk(rawDisp)) return rawDisp;
  if (email.isNotEmpty) return email;
  final String uid = (s['uid'] as String?)?.trim() ?? '';
  if (uid.isEmpty) return '미등록 사용자';
  return uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
}

String _messengerStaffBranch(Map<String, dynamic> s) {
  final String? bn = (s['branchName'] as String?)?.trim();
  if (bn != null && bn.isNotEmpty) return bn;
  return (s['branch'] as String?)?.trim() ?? '';
}

String? _messengerStaffPhotoUrl(Map<String, dynamic> s) {
  final String? u = (s['photoUrl'] as String?)?.trim();
  if (u == null || u.isEmpty) {
    return null;
  }
  return u;
}

String _messengerStaffInitials(String rawName) {
  final String t = rawName.trim();
  if (t.isEmpty) {
    return '?';
  }
  final List<int> runes = t.runes.toList();
  if (runes.length >= 2) {
    return String.fromCharCodes(<int>[runes[0], runes[1]]);
  }
  return String.fromCharCode(runes.first);
}

String _messengerStaffPosition(Map<String, dynamic> s) {
  return (s['position'] as String?)?.trim() ?? '';
}

String _messengerStaffPhone(Map<String, dynamic> s) {
  return (s['phone'] as String?)?.trim() ?? '';
}

bool _isStaffOnline(Map<String, dynamic> s) {
  final String state = (s['presenceState'] as String?)?.trim().toLowerCase() ?? '';
  final Timestamp? t = s['lastActiveAt'] as Timestamp?;
  if (t == null) {
    return false;
  }
  final int diffMs =
      DateTime.now().millisecondsSinceEpoch - t.toDate().millisecondsSinceEpoch;
  // 하트비트 30s 기준, 2분 이내면 온라인으로 간주
  final bool recent = diffMs >= 0 && diffMs <= const Duration(minutes: 2).inMilliseconds;
  return state == 'online' && recent;
}

String _staffPresenceLabel(Map<String, dynamic> s) {
  if (_isStaffOnline(s)) return '온라인';
  final Timestamp? t = s['lastActiveAt'] as Timestamp?;
  if (t == null) return '오프라인';
  return '오프라인 · ${DateFormat('MM/dd HH:mm').format(t.toDate())}';
}

/// 메신저 직원 목록·프로필 카드용 원형 사진
class _MessengerStaffAvatar extends StatefulWidget {
  const _MessengerStaffAvatar(
    this.staff, {
    this.size = 40,
    this.borderColor,
    this.borderWidth = 1,
  });

  final Map<String, dynamic> staff;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  @override
  State<_MessengerStaffAvatar> createState() => _MessengerStaffAvatarState();
}

class _MessengerStaffAvatarState extends State<_MessengerStaffAvatar> {
  String? _resolvedFor;
  Future<String?>? _displayUrlFuture;
  String? _cacheKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MessengerStaffAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String oldU = _messengerStaffPhotoUrl(oldWidget.staff) ?? '';
    final String newU = _messengerStaffPhotoUrl(widget.staff) ?? '';
    if (oldU != newU) _resolveIfNeeded(force: true);
  }

  void _resolveIfNeeded({bool force = false}) {
    final String url = _messengerStaffPhotoUrl(widget.staff) ?? '';
    if (!force && _resolvedFor == url) return;
    _resolvedFor = url;
    if (url.isEmpty) {
      _displayUrlFuture = null;
      _cacheKey = null;
      return;
    }
    final String? key = R2StorageService.fileKeyFromUrl(url);
    if (key == null || key.trim().isEmpty) {
      _displayUrlFuture = Future<String?>.value(url);
      _cacheKey = url;
      return;
    }
    final WorkFirestoreRepository repo =
        context.read<WorkFirestoreRepository>();
    _displayUrlFuture = repo.getPresignedViewUrl(url);
    _cacheKey = key;
  }

  @override
  Widget build(BuildContext context) {
    final String name = _messengerStaffDisplayName(widget.staff);
    final String initials = _messengerStaffInitials(name);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F5F9),
        border: Border.all(
          color: widget.borderColor ?? const Color(0xFFE2E8F0),
          width: widget.borderWidth,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _displayUrlFuture == null
          ? _MessengerInitialsFill(size: widget.size, initials: initials)
          : FutureBuilder<String?>(
              future: _displayUrlFuture,
              builder: (BuildContext context, AsyncSnapshot<String?> snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return Center(
                    child: SizedBox(
                      width: widget.size * 0.38,
                      height: widget.size * 0.38,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue.shade300,
                      ),
                    ),
                  );
                }
                final String? resolved = snap.data?.trim();
                if (resolved == null || resolved.isEmpty || snap.hasError) {
                  return _MessengerInitialsFill(
                    size: widget.size,
                    initials: initials,
                  );
                }
                return CachedNetworkImage(
                  imageUrl: resolved,
                  cacheKey: _cacheKey,
                  fit: BoxFit.cover,
                  width: widget.size,
                  height: widget.size,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (BuildContext _, String __) => Center(
                    child: SizedBox(
                      width: widget.size * 0.38,
                      height: widget.size * 0.38,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue.shade300,
                      ),
                    ),
                  ),
                  errorWidget: (BuildContext _, String __, Object ___) =>
                      _MessengerInitialsFill(
                    size: widget.size,
                    initials: initials,
                  ),
                );
              },
            ),
    );
  }
}

class _MessengerInitialsFill extends StatelessWidget {
  const _MessengerInitialsFill({
    required this.size,
    required this.initials,
  });

  final double size;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE0E7FF),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF3730A3),
          height: 1,
        ),
      ),
    );
  }
}

Widget _staffProfileInfoTile({
  required IconData icon,
  required String label,
  required String value,
}) {
  final String display = value.trim().isEmpty ? '—' : value.trim();
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                display,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _userFacingErrorMessage(Object e) {
  String s = e.toString().trim();
  const String bad = 'Bad state: ';
  if (s.startsWith('Exception: ')) {
    s = s.substring('Exception: '.length).trim();
  }
  if (s.startsWith(bad)) {
    s = s.substring(bad.length).trim();
  }
  if (s.isEmpty) {
    return '알 수 없는 오류가 발생했습니다.';
  }
  return s;
}

void _showMessengerCenterToast(BuildContext context, String message) {
  final OverlayState? overlay = Overlay.of(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext ctx) {
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xE6000000),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2600), () {
    try {
      entry.remove();
    } catch (_) {
      // 이미 제거됨
    }
  });
}

Map<String, Map<String, dynamic>> _staffByUid(List<Map<String, dynamic>> list) {
  final Map<String, Map<String, dynamic>> m = <String, Map<String, dynamic>>{};
  for (final Map<String, dynamic> s in list) {
    final String uid = (s['uid'] as String?)?.trim() ?? '';
    if (uid.isNotEmpty) {
      m[uid] = s;
    }
  }
  return m;
}

String _displayNameForUid(
  String uid,
  Map<String, Map<String, dynamic>> staffByUid,
) {
  final Map<String, dynamic>? s = staffByUid[uid];
  if (s == null) {
    return uid.length > 10 ? '${uid.substring(0, 10)}…' : uid;
  }
  return _messengerStaffDisplayName(s);
}

String _conversationTitle(
  ConversationRoomModel room,
  String myUid,
  Map<String, Map<String, dynamic>> staffByUid,
) {
  if (room.type == ConversationRoomModel.typeGroup) {
    final String gt = (room.groupTitle ?? '').trim();
    if (gt.isNotEmpty) {
      return gt;
    }
    final List<String> others = room.participantUids
        .where((String id) => id != myUid)
        .map((String id) => _displayNameForUid(id, staffByUid))
        .toList();
    if (others.isEmpty) {
      return '그룹 대화';
    }
    if (others.length <= 3) {
      return others.join(', ');
    }
    return '${others.take(3).join(', ')} 외 ${others.length - 3}명';
  }
  for (final String id in room.participantUids) {
    if (id != myUid) {
      return _displayNameForUid(id, staffByUid);
    }
  }
  return '나에게 보내기';
}

String _conversationShortTitle(
  ConversationRoomModel room,
  String myUid,
  Map<String, Map<String, dynamic>> staffByUid,
) {
  if (room.type == ConversationRoomModel.typeGroup) {
    final String gt = (room.groupTitle ?? '').trim();
    if (gt.isNotEmpty) return gt;
    final List<String> others = room.participantUids
        .where((String id) => id != myUid)
        .map((String id) => _displayNameForUid(id, staffByUid))
        .where((String s) => s.trim().isNotEmpty)
        .toList();
    if (others.isEmpty) return '그룹 대화';
    if (others.length == 1) return others.first;
    return '${others.first} 외 ${others.length - 1}명';
  }
  for (final String id in room.participantUids) {
    if (id != myUid) {
      return _displayNameForUid(id, staffByUid);
    }
  }
  return '나에게 보내기';
}

/// 직원 정보 다이얼로그용 맵. 1:1은 상대, 그룹은 `myUid`가 아닌 첫 참가자.
Map<String, dynamic> _messengerBriefStaffForRoom(
  ConversationRoomModel r,
  String? myUid,
  Map<String, Map<String, dynamic>> staffByUid,
) {
  final String fallbackTitle =
      myUid == null ? r.id : _conversationShortTitle(r, myUid, staffByUid);
  if (myUid == null || myUid.isEmpty) {
    return <String, dynamic>{
      'uid': '',
      'displayName': fallbackTitle,
    };
  }
  if (r.type == ConversationRoomModel.typeDirect) {
    String? other;
    for (final String id in r.participantUids) {
      if (id != myUid) {
        other = id;
        break;
      }
    }
    final String uid = (other ?? myUid).trim();
    if (uid.isEmpty) {
      return <String, dynamic>{'uid': '', 'displayName': fallbackTitle};
    }
    return staffByUid[uid] ??
        <String, dynamic>{
          'uid': uid,
          'displayName': _displayNameForUid(uid, staffByUid),
        };
  }
  for (final String id in r.participantUids) {
    if (id != myUid) {
      return staffByUid[id] ??
          <String, dynamic>{
            'uid': id,
            'displayName': _displayNameForUid(id, staffByUid),
          };
    }
  }
  return staffByUid[myUid] ??
      <String, dynamic>{
        'uid': myUid,
        'displayName': fallbackTitle,
      };
}

String _fmtMsgTime(Timestamp? t) {
  if (t == null) {
    return '';
  }
  return DateFormat('MM/dd HH:mm').format(t.toDate());
}

/// 상단 앱바 메신저 패널: 대화방 목록 / 직원 목록
class MessengerOverlay extends StatefulWidget {
  const MessengerOverlay({
    required this.onClose,
    required this.primaryColor,
    super.key,
  });

  final VoidCallback onClose;
  final Color primaryColor;

  @override
  State<MessengerOverlay> createState() => _MessengerOverlayState();
}

enum _MessengerMainTab { conversations, staff }

class _MessengerOverlayState extends State<MessengerOverlay> {
  _MessengerMainTab _mainTab = _MessengerMainTab.conversations;
  bool _dockWidthSyncScheduled = false;
  bool _floatingClampScheduled = false;

  Future<void> _startDirectWithStaff(Map<String, dynamic> s) async {
    final String uid = (s['uid'] as String?)?.trim() ?? '';
    if (uid.isEmpty) {
      return;
    }
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    try {
      final String id = await repo.ensureDirectConversation(uid);
      if (mounted) {
        // 직원정보창에서 "대화하기" → 즉시 [대화] 탭으로 전환 + 해당 DM 활성화
        setState(() => _mainTab = _MessengerMainTab.conversations);
        final MessengerDockController dock = context.read<MessengerDockController>();
        dock.open(conversationId: id);
        dock.setActive(id);
        // 생성 직후 unread가 남아있을 수 있어 방어적으로 읽음 처리
        unawaited(repo.markConversationRead(id));
      }
    } on Object catch (e) {
      if (mounted) {
        _showMessengerCenterToast(context, _userFacingErrorMessage(e));
      }
    }
  }

  Future<void> _showGroupCreateDialog(BuildContext context) async {
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    final Object? createdId = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _GroupConversationDialog(repo: repo),
    );
    if (!context.mounted || createdId is! String || createdId.isEmpty) {
      return;
    }
    context.read<MessengerDockController>().open(conversationId: createdId);
  }

  void _showStaffBrief(BuildContext context, Map<String, dynamic> s) {
    final BuildContext parentContext = context;
    final String name = _messengerStaffDisplayName(s);
    final String email = (s['email'] as String?)?.trim() ?? '';
    final String branch = _messengerStaffBranch(s);
    final String phone = _messengerStaffPhone(s);
    final String position = _messengerStaffPosition(s);
    final Color accent = widget.primaryColor;
    final String uid = (s['uid'] as String?)?.trim() ?? '';
    final bool canChat = uid.isNotEmpty;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          accent,
                          Color.lerp(accent, Colors.black, 0.12)!,
                        ],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _MessengerStaffAvatar(
                          s,
                          size: 56,
                          borderColor: Colors.white.withOpacity(0.95),
                          borderWidth: 2.5,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            name.isEmpty ? '직원' : name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  color: const Color(0xFFF8FAFC),
                  child: Column(
                    children: <Widget>[
                      _staffProfileInfoTile(
                        icon: Icons.apartment_outlined,
                        label: '사업소',
                        value: branch,
                      ),
                      const Divider(height: 1, indent: 64),
                      _staffProfileInfoTile(
                        icon: Icons.badge_outlined,
                        label: '직책',
                        value: position,
                      ),
                      const Divider(height: 1, indent: 64),
                      _staffProfileInfoTile(
                        icon: Icons.phone_outlined,
                        label: '연락처',
                        value: phone,
                      ),
                      const Divider(height: 1, indent: 64),
                      _staffProfileInfoTile(
                        icon: Icons.mail_outline_rounded,
                        label: '이메일',
                        value: email,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FilledButton(
                        onPressed: !canChat
                            ? null
                            : () {
                                Navigator.of(ctx).pop();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!parentContext.mounted) {
                                    return;
                                  }
                                  _startDirectWithStaff(s);
                                });
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '대화하기',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGroupRoomInfoDialog(
    BuildContext context,
    ConversationRoomModel room,
    Map<String, Map<String, dynamic>> staffByUid,
  ) {
    if (room.type != ConversationRoomModel.typeGroup) {
      return;
    }
    final Color accent = widget.primaryColor;
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    final String title = (room.groupTitle ?? '').trim().isNotEmpty
        ? room.groupTitle!.trim()
        : (myUid == null
            ? room.id
            : _conversationShortTitle(room, myUid, staffByUid));
    final String rawPhoto = (room.groupPhotoUrl ?? '').trim();
    final String? photoUrl = rawPhoto.isNotEmpty ? rawPhoto : null;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final double listH =
            (MediaQuery.sizeOf(ctx).height * 0.42).clamp(160.0, 440.0);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                  child: Column(
                    children: <Widget>[
                      _MessengerStaffAvatar(
                        <String, dynamic>{
                          'uid': '',
                          'displayName': title,
                          if (photoUrl != null) 'photoUrl': photoUrl,
                        },
                        size: 80,
                        borderColor: accent.withOpacity(0.4),
                        borderWidth: 2.6,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '참가자 ${room.participantUids.length}명',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text(
                    '참가자',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                SizedBox(
                  height: listH,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    itemCount: room.participantUids.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (BuildContext _, int i) {
                      final String uid = room.participantUids[i];
                      final Map<String, dynamic> s = staffByUid[uid] ??
                          <String, dynamic>{
                            'uid': uid,
                            'displayName': _displayNameForUid(uid, staffByUid),
                          };
                      final String sub = _messengerStaffBranch(s);
                      final String email = (s['email'] as String?)?.trim() ?? '';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        leading: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showStaffBrief(context, s),
                            child: _MessengerStaffAvatar(s, size: 44),
                          ),
                        ),
                        title: Text(
                          _messengerStaffDisplayName(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          <String>[
                            if (sub.isNotEmpty) sub,
                            if (email.isNotEmpty) email,
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Consumer<MessengerDockController>(
          builder: (BuildContext context, MessengerDockController dock, _) {
            // 도킹 상태에서 화면이 극단적으로 좁아지면 패널 폭이 레이아웃을 깨뜨릴 수 있어 최소 폭을 보장합니다.
            // (좌측 레일 92 + 채팅 최소 220 + 여백)
            const double kMinMessengerDockWidth = 92 + 220 + 16;
            if (!dock.floating) {
              final double maxAllowed = constraints.maxWidth;
              if (maxAllowed.isFinite && maxAllowed > 0) {
                final double target = dock.dockWidth.clamp(
                  kMinMessengerDockWidth.clamp(0.0, maxAllowed),
                  maxAllowed,
                );
                if ((dock.dockWidth - target).abs() > 0.5) {
                  if (!_dockWidthSyncScheduled) {
                    _dockWidthSyncScheduled = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _dockWidthSyncScheduled = false;
                      dock.setDockWidth(target, constraints);
                    });
                  }
                }
              }
            } else {
              if (!_floatingClampScheduled) {
                _floatingClampScheduled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _floatingClampScheduled = false;
                  dock.clampFloatingToScreen(constraints);
                });
              }
            }

            final bool floating = dock.floating;
            final double w = floating ? dock.floatingSize.width : dock.dockWidth;
            final double h = floating ? dock.floatingSize.height : constraints.maxHeight;

            Widget panel = Material(
              elevation: 18,
              color: Colors.white,
              borderRadius: floating ? BorderRadius.circular(16) : BorderRadius.zero,
              clipBehavior: Clip.antiAlias,
              child: Builder(
                builder: (BuildContext context) {
                  final Widget body = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _DockHeader(
                        primaryColor: widget.primaryColor,
                        title: '메신저',
                        floating: floating,
                        onClose: widget.onClose,
                        onDockRight: dock.dockToRight,
                        onDragStart: () => dock.beginFloatingFromDock(constraints),
                        onDragUpdate: (Offset delta) =>
                            dock.moveFloatingBy(delta, constraints),
                        onSortTap: _mainTab == _MessengerMainTab.conversations
                            ? () => _showSortDialog(context, dock)
                            : null,
                        onSearchTap: _mainTab == _MessengerMainTab.conversations
                            ? () => _showConversationSearchDialog(context)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                        child: StreamBuilder<int>(
                          stream: repo.watchUnreadConversationCount(),
                          builder: (BuildContext context, AsyncSnapshot<int> c) {
                            final int unread = c.data ?? 0;
                            return Row(
                              children: <Widget>[
                                Expanded(
                                  child: _MessengerTabButton(
                                    label: '대화',
                                    selected: _mainTab == _MessengerMainTab.conversations,
                                    showDot: unread > 0,
                                    onTap: () => setState(
                                      () => _mainTab = _MessengerMainTab.conversations,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _MessengerTabButton(
                                    label: '직원목록',
                                    selected: _mainTab == _MessengerMainTab.staff,
                                    onTap: () => setState(
                                      () => _mainTab = _MessengerMainTab.staff,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: '그룹 대화 만들기',
                                  onPressed: () => _showGroupCreateDialog(context),
                                  icon: Icon(
                                    Icons.group_add_outlined,
                                    color: widget.primaryColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _mainTab == _MessengerMainTab.staff
                            ? _StaffListBody(
                                repo: repo,
                                onStaffTap: (Map<String, dynamic> s) =>
                                    _showStaffBrief(context, s),
                              )
                            : _ConversationDockBody(
                                repo: repo,
                                primaryColor: widget.primaryColor,
                                onStaffBrief: (Map<String, dynamic> s) =>
                                    _showStaffBrief(context, s),
                                onGroupRoomInfo: (BuildContext c, ConversationRoomModel r,
                                        Map<String, Map<String, dynamic>> staff) =>
                                    _showGroupRoomInfoDialog(c, r, staff),
                              ),
                      ),
                    ],
                  );

                  if (!floating) {
                    return body;
                  }

                  // 플로팅일 때는 Stack 위에 리사이즈 핸들을 올립니다.
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(child: body),
                      Positioned(
                        right: 0,
                        top: 54,
                        bottom: 18,
                        width: 10,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (DragUpdateDetails d) =>
                                dock.resizeFloatingBy(Offset(d.delta.dx, 0), constraints),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 0,
                        height: 10,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpDown,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (DragUpdateDetails d) =>
                                dock.resizeFloatingBy(Offset(0, d.delta.dy), constraints),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: 26,
                        height: 26,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpLeftDownRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (DragUpdateDetails d) =>
                                dock.resizeFloatingBy(d.delta, constraints),
                            child: const Icon(
                              Icons.drag_handle,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );

            if (!floating) {
              panel = Stack(
                children: <Widget>[
                  Positioned.fill(child: panel),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 10,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (DragUpdateDetails d) {
                          dock.setDockWidth(dock.dockWidth - d.delta.dx, constraints);
                        },
                      ),
                    ),
                  ),
                ],
              );
            }

            final Widget positioned = floating
                ? Positioned(
                    left: dock.floatingPos.dx,
                    top: dock.floatingPos.dy,
                    width: w,
                    height: h,
                    child: panel,
                  )
                : Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: w,
                    child: panel,
                  );

            // NOTE: `Positioned`는 반드시 `Stack`의 직접 자식이어야 합니다.
            // 이 위젯은 WorkAppShell의 Stack 안에 직접 놓이므로,
            // 여기서 다시 `Positioned.fill`로 감싸면(LayoutBuilder 아래) ParentData 오류가 납니다.
            return SizedBox.expand(
              child: IgnorePointer(
                ignoring: false,
                child: Stack(children: <Widget>[positioned]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSortDialog(BuildContext context, MessengerDockController dock) async {
    final MessengerConversationSort cur = dock.sort;
    final MessengerConversationSort? picked = await showDialog<MessengerConversationSort>(
      context: context,
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: const Text('정렬'),
          children: <Widget>[
            RadioListTile<MessengerConversationSort>(
              value: MessengerConversationSort.unreadThenRecent,
              groupValue: cur,
              title: const Text('안읽은 메시지 우선'),
              onChanged: (MessengerConversationSort? v) => Navigator.of(ctx).pop(v),
            ),
            RadioListTile<MessengerConversationSort>(
              value: MessengerConversationSort.recent,
              groupValue: cur,
              title: const Text('최신 메시지 순'),
              onChanged: (MessengerConversationSort? v) => Navigator.of(ctx).pop(v),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      dock.setSort(picked);
    }
  }

  Future<void> _showConversationSearchDialog(BuildContext context) async {
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    final MessengerDockController dock = context.read<MessengerDockController>();
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          child: SizedBox(
            width: 420,
            height: 520,
            child: _ConversationSearchDialogBody(
              dock: dock,
              repo: repo,
              myUid: myUid,
              primaryColor: widget.primaryColor,
            ),
          ),
        );
      },
    );
  }
}

class _ConversationSearchDialogBody extends StatefulWidget {
  const _ConversationSearchDialogBody({
    required this.dock,
    required this.repo,
    required this.myUid,
    required this.primaryColor,
  });

  final MessengerDockController dock;
  final WorkFirestoreRepository repo;
  final String? myUid;
  final Color primaryColor;

  @override
  State<_ConversationSearchDialogBody> createState() => _ConversationSearchDialogBodyState();
}

class _ConversationSearchDialogBodyState extends State<_ConversationSearchDialogBody> {
  final TextEditingController _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MessengerDockController dock = widget.dock;
    final String? myUid = widget.myUid;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '대화 검색/고정',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _q,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '이름/그룹명 검색',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.repo.watchUsersMirror(),
              builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> staffSnap) {
                final Map<String, Map<String, dynamic>> staffByUid =
                    _staffByUid(staffSnap.data ?? <Map<String, dynamic>>[]);
                return StreamBuilder<List<ConversationRoomModel>>(
                  stream: widget.repo.watchMyConversations(),
                  builder: (BuildContext context, AsyncSnapshot<List<ConversationRoomModel>> convSnap) {
                    final List<ConversationRoomModel> rooms =
                        convSnap.data ?? <ConversationRoomModel>[];
                    final List<_SearchRow> rows = <_SearchRow>[];
                    for (final ConversationRoomModel r in rooms) {
                      final String title = (myUid == null)
                          ? r.id
                          : _conversationShortTitle(r, myUid, staffByUid);
                      final String key = title.toLowerCase();
                      if (_query.isNotEmpty && !key.contains(_query)) {
                        continue;
                      }
                      rows.add(_SearchRow(room: r, title: title));
                    }
                    rows.sort((_SearchRow a, _SearchRow b) {
                      final bool fa = dock.isFavorite(a.room.id);
                      final bool fb = dock.isFavorite(b.room.id);
                      if (fa != fb) return fb ? 1 : -1;
                      return _conversationRecencyMs(b.room).compareTo(_conversationRecencyMs(a.room));
                    });
                    if (rows.isEmpty) {
                      return const Center(child: Text('검색 결과가 없습니다.'));
                    }
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int i) {
                        final _SearchRow row = rows[i];
                        final ConversationRoomModel r = row.room;
                        final bool fav = dock.isFavorite(r.id);
                        final int unread = myUid == null ? 0 : r.unreadCountFor(myUid);
                        return ListTile(
                          leading: Icon(
                            fav ? Icons.star_rounded : Icons.star_border_rounded,
                            color: fav ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                          ),
                          title: Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: unread > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.primaryColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () async {
                            dock.open(conversationId: r.id);
                            dock.setActive(r.id);
                            try {
                              await widget.repo.markConversationRead(r.id);
                            } catch (_) {}
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          onLongPress: () => dock.toggleFavorite(r.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '팁: 항목을 길게 누르면 즐겨찾기 고정/해제',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _SearchRow {
  const _SearchRow({required this.room, required this.title});
  final ConversationRoomModel room;
  final String title;
}

class _DockHeader extends StatelessWidget {
  const _DockHeader({
    required this.primaryColor,
    required this.title,
    required this.floating,
    required this.onClose,
    required this.onDockRight,
    required this.onDragStart,
    required this.onDragUpdate,
    this.onSortTap,
    this.onSearchTap,
  });

  final Color primaryColor;
  final String title;
  final bool floating;
  final VoidCallback onClose;
  final VoidCallback onDockRight;
  final VoidCallback onDragStart;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback? onSortTap;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        if (!floating) {
          onDragStart();
        }
      },
      onPanUpdate: (DragUpdateDetails d) => onDragUpdate(d.delta),
      child: Container(
        height: 54,
        color: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 6),
            const Icon(Icons.drag_indicator, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            if (onSortTap != null)
              IconButton(
                tooltip: '정렬',
                onPressed: onSortTap,
                icon: const Icon(Icons.sort, color: Colors.white),
              ),
            if (onSearchTap != null)
              IconButton(
                tooltip: '검색',
                onPressed: onSearchTap,
                icon: const Icon(Icons.search, color: Colors.white),
              ),
            if (floating)
              IconButton(
                tooltip: '오른쪽 고정',
                onPressed: onDockRight,
                icon: const Icon(Icons.push_pin_outlined, color: Colors.white),
              ),
            IconButton(
              tooltip: '닫기',
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessengerTabButton extends StatelessWidget {
  const _MessengerTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: selected ? Colors.blue.shade100 : null,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: onTap,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: selected ? Colors.blue.shade900 : Colors.black87,
                ),
              ),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _StaffListBody extends StatelessWidget {
  const _StaffListBody({
    required this.repo,
    required this.onStaffTap,
  });

  final WorkFirestoreRepository repo;
  final void Function(Map<String, dynamic> s) onStaffTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.watchUsersMirror(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Map<String, dynamic>>> snap,
      ) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Map<String, dynamic>> list =
            snap.data ?? <Map<String, dynamic>>[];
        if (list.isEmpty) {
          return const Center(child: Text('직원 데이터가 없습니다.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> s = list[i];
            final String title = _messengerStaffDisplayName(s);
            final String sub = _messengerStaffBranch(s);
            final String email = (s['email'] as String?)?.trim() ?? '';
            final bool online = _isStaffOnline(s);
            final String presence = _staffPresenceLabel(s);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              leading: _MessengerStaffAvatar(s, size: 44),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              subtitle: Text(
                <String>[if (sub.isNotEmpty) sub, if (email.isNotEmpty) email]
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              trailing: Tooltip(
                message: presence,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      online ? '온라인' : '오프라인',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () => onStaffTap(s),
            );
          },
        );
      },
    );
  }
}

int _conversationRecencyMs(ConversationRoomModel r) {
  final int u = r.updatedAt?.millisecondsSinceEpoch ?? 0;
  final int lm = r.lastMessageAt?.millisecondsSinceEpoch ?? 0;
  return u > lm ? u : lm;
}

class _ConversationDockBody extends StatefulWidget {
  const _ConversationDockBody({
    required this.repo,
    required this.primaryColor,
    required this.onStaffBrief,
    required this.onGroupRoomInfo,
  });

  final WorkFirestoreRepository repo;
  final Color primaryColor;
  final void Function(Map<String, dynamic> staff) onStaffBrief;
  final void Function(
    BuildContext context,
    ConversationRoomModel room,
    Map<String, Map<String, dynamic>> staffByUid,
  ) onGroupRoomInfo;

  @override
  State<_ConversationDockBody> createState() => _ConversationDockBodyState();
}

class _ConversationDockBodyState extends State<_ConversationDockBody> {
  @override
  Widget build(BuildContext context) {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    final MessengerDockController dock = context.watch<MessengerDockController>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.repo.watchUsersMirror(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Map<String, dynamic>>> staffSnap,
      ) {
        final Map<String, Map<String, dynamic>> staffByUid =
            _staffByUid(staffSnap.data ?? <Map<String, dynamic>>[]);
        return StreamBuilder<List<ConversationRoomModel>>(
          stream: widget.repo.watchMyConversations(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<ConversationRoomModel>> convSnap,
          ) {
            if (convSnap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SelectableText(
                    '대화 목록을 불러오지 못했습니다.\n${convSnap.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              );
            }
            final List<ConversationRoomModel> rooms0 =
                convSnap.data ?? <ConversationRoomModel>[];
            if (rooms0.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        '대화가 없습니다.\n직원 목록에서 대화를 시작하거나\n그룹 대화를 만들어 보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            }

            // flashing 감지
            // 반짝 대신 배지 숫자(`memberUnreadCount`)로 표시합니다.

            // active 기본값: 첫 대화방
            final String active = (dock.activeConversationId?.trim().isNotEmpty ?? false)
                ? dock.activeConversationId!.trim()
                : rooms0.first.id;
            if (dock.activeConversationId != active) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                context.read<MessengerDockController>().setActive(active);
              });
            }

            // 정렬
            final List<ConversationRoomModel> rooms = List<ConversationRoomModel>.from(rooms0);
            rooms.sort((ConversationRoomModel a, ConversationRoomModel b) {
              final bool fa = dock.isFavorite(a.id);
              final bool fb = dock.isFavorite(b.id);
              if (fa != fb) return fb ? 1 : -1;
              if (dock.sort == MessengerConversationSort.unreadThenRecent && myUid != null) {
                final int ua = a.unreadCountFor(myUid);
                final int ub = b.unreadCountFor(myUid);
                if ((ua > 0) != (ub > 0)) return (ub > 0 ? 1 : 0) - (ua > 0 ? 1 : 0);
                if (ua != ub) return ub.compareTo(ua);
              }
              return _conversationRecencyMs(b).compareTo(_conversationRecencyMs(a));
            });

            return Row(
              children: <Widget>[
                _ConversationIconRail(
                  rooms: rooms,
                  myUid: myUid,
                  staffByUid: staffByUid,
                  primaryColor: widget.primaryColor,
                  activeId: active,
                  onSelect: (String id) async {
                    context.read<MessengerDockController>().setActive(id);
                    try {
                      await widget.repo.markConversationRead(id);
                    } on Object {
                      // ignore
                    }
                  },
                  onActiveConversationTap: (ConversationRoomModel r) {
                    if (r.type == ConversationRoomModel.typeGroup) {
                      widget.onGroupRoomInfo(context, r, staffByUid);
                    } else {
                      widget.onStaffBrief(
                        _messengerBriefStaffForRoom(r, myUid, staffByUid),
                      );
                    }
                  },
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: _ChatPane(
                    conversationId: active,
                    primaryColor: widget.primaryColor,
                    onStaffBrief: widget.onStaffBrief,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ConversationIconRail extends StatelessWidget {
  const _ConversationIconRail({
    required this.rooms,
    required this.myUid,
    required this.staffByUid,
    required this.primaryColor,
    required this.activeId,
    required this.onSelect,
    required this.onActiveConversationTap,
  });

  final List<ConversationRoomModel> rooms;
  final String? myUid;
  final Map<String, Map<String, dynamic>> staffByUid;
  final Color primaryColor;
  final String activeId;
  final Future<void> Function(String conversationId) onSelect;
  final void Function(ConversationRoomModel room) onActiveConversationTap;

  static const double _railWidth = 92;

  @override
  Widget build(BuildContext context) {
    final MessengerDockController dock = context.watch<MessengerDockController>();
    return Container(
      width: _railWidth,
      color: const Color(0xFFF8FAFC),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        itemCount: rooms.length,
        itemBuilder: (BuildContext context, int i) {
          final ConversationRoomModel r = rooms[i];
          final bool selected = r.id == activeId;
          final int unreadCount =
              myUid == null ? 0 : r.unreadCountFor(myUid!);
          final bool fav = dock.isFavorite(r.id);
          final String title =
              myUid == null ? r.id : _conversationShortTitle(r, myUid!, staffByUid);

          // 대표 아바타: 그룹은 개설 시 지정한 이름·이미지, 1:1은 상대 직원
          Map<String, dynamic> avatarStaff = <String, dynamic>{
            'uid': r.id,
            'displayName': title,
          };
          if (r.type == ConversationRoomModel.typeGroup) {
            final String disp = (r.groupTitle ?? '').trim().isNotEmpty
                ? r.groupTitle!.trim()
                : title;
            final String gp = (r.groupPhotoUrl ?? '').trim();
            avatarStaff = <String, dynamic>{
              'uid': '',
              'displayName': disp,
              if (gp.isNotEmpty) 'photoUrl': gp,
            };
          } else if (myUid != null && r.type == ConversationRoomModel.typeDirect) {
            String? other;
            for (final String id in r.participantUids) {
              if (id != myUid) {
                other = id;
                break;
              }
            }
            if (other != null) {
              avatarStaff = staffByUid[other] ??
                  <String, dynamic>{
                    'uid': other,
                    'displayName': title,
                  };
            }
          }

          final Color border = selected
              ? primaryColor
              : const Color(0xFFE2E8F0);
          final double bw = selected ? 2.6 : 1.2;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                if (r.id == activeId) {
                  onActiveConversationTap(r);
                } else {
                  await onSelect(r.id);
                }
              },
              onLongPress: () => dock.toggleFavorite(r.id),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                decoration: BoxDecoration(
                  color: selected
                      ? primaryColor.withOpacity(0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        _MessengerStaffAvatar(
                          avatarStaff,
                          size: 46,
                          borderColor: border,
                          borderWidth: bw,
                        ),
                        if (r.type == ConversationRoomModel.typeGroup)
                          Positioned(
                            left: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                '그룹',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        if (fav)
                          const Positioned(
                            left: -6,
                            top: -6,
                            child: Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChatPane extends StatefulWidget {
  const _ChatPane({
    required this.conversationId,
    required this.primaryColor,
    required this.onStaffBrief,
  });

  final String conversationId;
  final Color primaryColor;
  final void Function(Map<String, dynamic> staff) onStaffBrief;

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  DateTime? _lastSentAt;
  static const Duration _sendCooldown = Duration(seconds: 1);
  final FocusNode _kbdFocus = FocusNode();
  final FocusNode _textFocus = FocusNode();

  @override
  void dispose() {
    _kbdFocus.dispose();
    _textFocus.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(WorkFirestoreRepository repo) async {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastSentAt;
    if (_sending || (last != null && now.difference(last) < _sendCooldown)) {
      _showMessengerCenterToast(context, '너무 잦은 시도입니다.');
      return;
    }
    final String t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    try {
      await repo.sendChatMessage(widget.conversationId, t);
      _input.clear();
      _lastSentAt = DateTime.now();
      if (mounted) setState(() => _sending = false);
      // 전송 성공 후에는 입력창으로 포커스 복귀(연속 입력 UX)
      if (mounted) {
        FocusScope.of(context).requestFocus(_textFocus);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _showMessengerCenterToast(context, _userFacingErrorMessage(e));
      }
    }
  }

  /// 극단적으로 좁은 폭에서도 `clamp(lower, upper)`가 역전하지 않도록 말풍선 최대 폭을 계산합니다.
  double _kakaoBubbleMaxWidth(
    BoxConstraints c, {
    required double maxRatio,
    required double reservedWidth,
    double preferredMin = 220,
    double absoluteMin = 72,
  }) {
    final double raw = c.maxWidth.isFinite ? c.maxWidth : 0.0;
    if (raw <= 0) return absoluteMin;

    final double upper = (raw - reservedWidth).clamp(absoluteMin, raw);
    final double lower = math.min(preferredMin, upper);
    final double ratioCap = (raw * maxRatio).clamp(absoluteMin, upper);
    return ratioCap.clamp(lower, upper);
  }

  Widget _buildOtherMessage(
    BuildContext context, {
    required String messageId,
    required Map<String, dynamic> staff,
    required String name,
    required String body,
    required Timestamp? createdAt,
    required Color primaryColor,
  }) {
    const double avatar = 30;
    const double gap = 8;
    const double maxRatio = 0.82;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onStaffBrief(staff),
                child: _MessengerStaffAvatar(staff, size: avatar),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double maxW = _kakaoBubbleMaxWidth(
              c,
              maxRatio: maxRatio,
              reservedWidth: avatar + gap,
            );
            return Padding(
              padding: const EdgeInsets.only(left: avatar + gap),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _KakaoBubble(
                      side: _BubbleSide.left,
                      color: Colors.white,
                      shadow: true,
                      child: _ExpandableMessageText(
                        key: ValueKey<String>('msg_$messageId'),
                        text: body,
                        collapsedMaxLines: 10,
                        textStyle: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          height: 1.35,
                        ),
                        controlTextStyle: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtMsgTime(createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMyMessage(
    BuildContext context, {
    required String? myUid,
    required String messageId,
    required Map<String, dynamic> myStaff,
    required String name,
    required String body,
    required Timestamp? createdAt,
    required Color primaryColor,
  }) {
    const double avatar = 30;
    const double gap = 8;
    const double maxRatio = 0.82;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: gap),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onStaffBrief(myStaff),
                child: _MessengerStaffAvatar(
                  myStaff,
                  size: avatar,
                  borderColor: primaryColor.withOpacity(0.55),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            // 왼쪽(상대 아바타 칼럼)은 침범하지 않도록 폭 제한
            final double maxW = _kakaoBubbleMaxWidth(
              c,
              maxRatio: maxRatio,
              reservedWidth: avatar + gap,
            );
            return Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _KakaoBubble(
                      side: _BubbleSide.right,
                      color: Color.lerp(primaryColor, Colors.white, 0.82) ??
                          primaryColor.withOpacity(0.18),
                      shadow: false,
                      child: _ExpandableMessageText(
                        key: ValueKey<String>('msg_$messageId'),
                        text: body,
                        collapsedMaxLines: 10,
                        textStyle: TextStyle(
                          color: (Color.lerp(primaryColor, Colors.white, 0.82) ??
                                      primaryColor.withOpacity(0.18))
                                  .computeLuminance() >
                              0.5
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        controlTextStyle: TextStyle(
                          color: (Color.lerp(primaryColor, Colors.white, 0.82) ??
                                      primaryColor.withOpacity(0.18))
                                  .computeLuminance() >
                              0.5
                              ? const Color(0xFF0F172A)
                              : Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtMsgTime(createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: <Widget>[
        Expanded(
          child: Container(
            color: const Color(0xFFF1F5F9),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: repo.watchUsersMirror(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<Map<String, dynamic>>> staffSnap,
              ) {
                final Map<String, Map<String, dynamic>> staffByUid =
                    _staffByUid(staffSnap.data ?? <Map<String, dynamic>>[]);
                return StreamBuilder<List<ChatMessageModel>>(
                  stream: repo.watchConversationMessages(widget.conversationId),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<ChatMessageModel>> snap,
                  ) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: SelectableText(
                            '채팅을 불러오지 못했습니다.\n${snap.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      );
                    }
                    final List<ChatMessageModel> msgs =
                        snap.data ?? <ChatMessageModel>[];
                    if (msgs.isEmpty) {
                      return const Center(
                        child: Text(
                          '첫 메시지를 보내 보세요.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
                        _scroll.jumpTo(_scroll.position.maxScrollExtent);
                      }
                    });
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: msgs.length,
                      itemBuilder: (BuildContext context, int i) {
                        final ChatMessageModel m = msgs[i];
                        final bool mine = myUid != null && m.senderUid == myUid;
                        final String name = m.senderDisplay.isEmpty
                            ? (mine ? '나' : '(알 수 없음)')
                            : m.senderDisplay;
                        final Map<String, dynamic> avatarStaff =
                            staffByUid[m.senderUid] ??
                                <String, dynamic>{
                                  'uid': m.senderUid,
                                  'displayName': name,
                                };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: mine
                              ? _buildMyMessage(
                                  context,
                                  myUid: myUid,
                                  messageId: m.id,
                                  myStaff: staffByUid[myUid] ??
                                      <String, dynamic>{'uid': myUid, 'displayName': name},
                                  name: name,
                                  body: m.body,
                                  createdAt: m.createdAt,
                                  primaryColor: widget.primaryColor,
                                )
                              : _buildOtherMessage(
                                  context,
                                  messageId: m.id,
                                  staff: avatarStaff,
                                  name: name,
                                  body: m.body,
                                  createdAt: m.createdAt,
                                  primaryColor: widget.primaryColor,
                                ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: KeyboardListener(
                    focusNode: _kbdFocus,
                    onKeyEvent: (KeyEvent e) {
                      if (e is! KeyDownEvent) return;
                      if (e.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _send(repo);
                      }
                    },
                    child: TextField(
                      controller: _input,
                      focusNode: _textFocus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: '메시지 입력',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      // Enter 전송은 KeyboardListener에서 처리(중복 전송 방지)
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sending ? null : () => _send(repo),
                  style: FilledButton.styleFrom(minimumSize: const Size(52, 48)),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 22),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandableMessageText extends StatefulWidget {
  const _ExpandableMessageText({
    required this.text,
    required this.collapsedMaxLines,
    required this.textStyle,
    required this.controlTextStyle,
    super.key,
  });

  final String text;
  final int collapsedMaxLines;
  final TextStyle textStyle;
  final TextStyle controlTextStyle;

  @override
  State<_ExpandableMessageText> createState() => _ExpandableMessageTextState();
}

class _ExpandableMessageTextState extends State<_ExpandableMessageText> {
  bool _expanded = false;

  int _lineCount(String text, TextStyle style, double maxWidth) {
    final double mw = maxWidth.isFinite ? maxWidth.clamp(1.0, 1000000.0) : 400.0;
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: null,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: mw);
    return tp.computeLineMetrics().length;
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.text;
    if (text.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double w = c.maxWidth.isFinite ? c.maxWidth.clamp(1.0, 1000000.0) : 400.0;
        final int lines = _lineCount(text, widget.textStyle, w);
        final bool needsFold = lines > widget.collapsedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              text,
              style: widget.textStyle,
              maxLines: (!_expanded && needsFold) ? widget.collapsedMaxLines : null,
              overflow: (!_expanded && needsFold) ? TextOverflow.ellipsis : TextOverflow.visible,
            ),
            if (needsFold)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? '접기' : '펼쳐보기',
                    style: widget.controlTextStyle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _BubbleSide { left, right }

class _KakaoBubble extends StatelessWidget {
  const _KakaoBubble({
    required this.side,
    required this.color,
    required this.child,
    this.shadow = true,
  });

  final _BubbleSide side;
  final Color color;
  final Widget child;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    return CustomPaint(
      painter: _KakaoBubblePainter(
        side: side,
        color: color,
        radius: 14,
        shadow: shadow,
      ),
      child: Padding(
        padding: pad,
        child: DefaultTextStyle.merge(
          style: const TextStyle(height: 1.35),
          child: child,
        ),
      ),
    );
  }
}

class _KakaoBubblePainter extends CustomPainter {
  _KakaoBubblePainter({
    required this.side,
    required this.color,
    required this.radius,
    required this.shadow,
  });

  final _BubbleSide side;
  final Color color;
  final double radius;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final double tailW = 8;
    final double tailH = 10;
    final double tailTop = 10;

    final Rect body = side == _BubbleSide.left
        ? Rect.fromLTWH(tailW, 0, size.width - tailW, size.height)
        : Rect.fromLTWH(0, 0, size.width - tailW, size.height);

    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(radius));

    if (shadow) {
      final Paint sp = Paint()
        ..color = Colors.black.withOpacity(0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(rr.shift(const Offset(0, 2)), sp);
    }

    final Paint p = Paint()..color = color;
    canvas.drawRRect(rr, p);

    // 꼬리(삼각형)
    final Path tail = Path();
    if (side == _BubbleSide.left) {
      tail
        ..moveTo(tailW, tailTop + 2)
        ..lineTo(0, tailTop + tailH * 0.55)
        ..lineTo(tailW, tailTop + tailH)
        ..close();
    } else {
      final double x = size.width - tailW;
      tail
        ..moveTo(x, tailTop + 2)
        ..lineTo(size.width, tailTop + tailH * 0.55)
        ..lineTo(x, tailTop + tailH)
        ..close();
    }
    canvas.drawPath(tail, p);
  }

  @override
  bool shouldRepaint(covariant _KakaoBubblePainter oldDelegate) {
    return oldDelegate.side != side ||
        oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.shadow != shadow;
  }
}

// (구) 대화 목록 리스트/스레드 패널 UI는 도킹 레이아웃으로 교체됨.

// (구) 리스트 전용 아바타 위젯은 아이콘 레일로 대체됨.

class _ChatThreadPanel extends StatefulWidget {
  const _ChatThreadPanel({
    required this.conversationId,
    required this.primaryColor,
    required this.onBack,
  });

  final String conversationId;
  final Color primaryColor;
  final VoidCallback onBack;

  @override
  State<_ChatThreadPanel> createState() => _ChatThreadPanelState();
}

class _ChatThreadPanelState extends State<_ChatThreadPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(WorkFirestoreRepository repo) async {
    if (_sending) {
      return;
    }
    final String t = _input.text.trim();
    if (t.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      await repo.sendChatMessage(widget.conversationId, t);
      _input.clear();
      if (mounted) {
        setState(() => _sending = false);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _showMessengerCenterToast(context, _userFacingErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.watchUsersMirror(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> staffSnap,
          ) {
            final Map<String, Map<String, dynamic>> staffByUid =
                _staffByUid(staffSnap.data ?? <Map<String, dynamic>>[]);
            return StreamBuilder<ConversationRoomModel?>(
              stream: repo.watchConversationRoom(widget.conversationId),
              builder: (
                BuildContext context,
                AsyncSnapshot<ConversationRoomModel?> roomSnap,
              ) {
                final ConversationRoomModel? room = roomSnap.data;
                final String title = room == null || myUid == null
                    ? '대화'
                    : _conversationTitle(room, myUid, staffByUid);
                return Container(
                  height: 56,
                  color: widget.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF1F5F9),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: repo.watchUsersMirror(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<Map<String, dynamic>>> staffSnap,
              ) {
                final Map<String, Map<String, dynamic>> staffByUid =
                    _staffByUid(staffSnap.data ?? <Map<String, dynamic>>[]);
                return StreamBuilder<List<ChatMessageModel>>(
                  stream: repo.watchConversationMessages(widget.conversationId),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<ChatMessageModel>> snap,
                  ) {
                    final List<ChatMessageModel> msgs =
                        snap.data ?? <ChatMessageModel>[];
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (msgs.isEmpty) {
                      return const Center(
                        child: Text(
                          '첫 메시지를 보내 보세요.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients &&
                          _scroll.position.maxScrollExtent > 0) {
                        _scroll.jumpTo(_scroll.position.maxScrollExtent);
                      }
                    });
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                      itemCount: msgs.length,
                      itemBuilder: (BuildContext context, int i) {
                        final ChatMessageModel m = msgs[i];
                        final bool mine = myUid != null && m.senderUid == myUid;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: mine
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              if (!mine) ...<Widget>[
                                _MessengerStaffAvatar(
                                  staffByUid[m.senderUid] ??
                                      <String, dynamic>{
                                        'uid': m.senderUid,
                                        'displayName': m.senderDisplay,
                                      },
                                  size: 32,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: mine
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (!mine)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          m.senderDisplay.isEmpty
                                              ? '(알 수 없음)'
                                              : m.senderDisplay,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: mine
                                            ? widget.primaryColor
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        m.body,
                                        style: TextStyle(
                                          color: mine
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                          fontSize: 14,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _fmtMsgTime(m.createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: 8,
            bottom: MediaQuery.paddingOf(context).bottom + 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: '메시지 입력',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _send(repo),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : () => _send(repo),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  minimumSize: const Size(52, 48),
                  padding: EdgeInsets.zero,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupConversationDialog extends StatefulWidget {
  const _GroupConversationDialog({required this.repo});

  final WorkFirestoreRepository repo;

  @override
  State<_GroupConversationDialog> createState() =>
      _GroupConversationDialogState();
}

class _GroupConversationDialogState extends State<_GroupConversationDialog> {
  final TextEditingController _searchC = TextEditingController();
  final TextEditingController _titleC = TextEditingController();
  final TextEditingController _photoUrlC = TextEditingController();
  final List<Map<String, String>> _recipients = <Map<String, String>>[];
  bool _creating = false;

  @override
  void dispose() {
    _searchC.dispose();
    _titleC.dispose();
    _photoUrlC.dispose();
    super.dispose();
  }

  void _addRecipient(Map<String, dynamic> s) {
    final String uid = (s['uid'] as String?)?.trim() ?? '';
    if (uid.isEmpty) {
      return;
    }
    if (_recipients.any((Map<String, String> e) => e['uid'] == uid)) {
      return;
    }
    final String label = _messengerStaffDisplayName(s);
    setState(() {
      _recipients.add(<String, String>{'uid': uid, 'label': label});
    });
  }

  void _removeRecipient(String uid) {
    setState(() {
      _recipients.removeWhere((Map<String, String> e) => e['uid'] == uid);
    });
  }

  bool _isRecipientUid(String uid) {
    final String id = uid.trim();
    if (id.isEmpty) return false;
    return _recipients.any((Map<String, String> e) => e['uid'] == id);
  }

  void _toggleRecipient(Map<String, dynamic> s) {
    final String uid = (s['uid'] as String?)?.trim() ?? '';
    if (uid.isEmpty) return;
    if (_isRecipientUid(uid)) {
      _removeRecipient(uid);
    } else {
      _addRecipient(s);
    }
  }

  bool _staffMatches(Map<String, dynamic> s, String q) {
    final String t = q.trim().toLowerCase();
    if (t.isEmpty) {
      return false;
    }
    final String name = _messengerStaffDisplayName(s).toLowerCase();
    final String email = ((s['email'] as String?) ?? '').toLowerCase();
    final String branch = _messengerStaffBranch(s).toLowerCase();
    final String pos = ((s['position'] as String?) ?? '').toLowerCase();
    return name.contains(t) ||
        email.contains(t) ||
        branch.contains(t) ||
        pos.contains(t);
  }

  Future<void> _create() async {
    if (_creating) {
      return;
    }
    if (_recipients.isEmpty) {
      _showMessengerCenterToast(context, '참가자를 한 명 이상 추가해 주세요.');
      return;
    }
    if (_titleC.text.trim().isEmpty) {
      _showMessengerCenterToast(context, '그룹방 이름을 입력해 주세요.');
      return;
    }
    setState(() => _creating = true);
    try {
      final String newId = await widget.repo.createGroupConversation(
        participantUids: _recipients.map((Map<String, String> e) => e['uid']!).toList(),
        groupTitle: _titleC.text.trim(),
        groupPhotoUrl: _photoUrlC.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop<String>(newId);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        _showMessengerCenterToast(context, _userFacingErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    const double kSearchBarH = 52;
    final double dropdownMaxH = (MediaQuery.sizeOf(context).height * 0.22)
        .clamp(100.0, 180.0);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      title: const Text('그룹 대화 만들기'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _titleC,
              decoration: const InputDecoration(
                labelText: '그룹방 이름',
                hintText: '목록·정보창에 표시됩니다',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _photoUrlC,
              decoration: const InputDecoration(
                labelText: '대표 이미지 URL (선택)',
                hintText: 'https://… (비우면 이니셜 아이콘)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                const Text(
                  '참가자',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                Text(
                  ' (${_recipients.length}명)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _recipients
                  .map(
                    (Map<String, String> e) => InputChip(
                      label: Text(e['label'] ?? e['uid'] ?? ''),
                      onDeleted: () => _removeRecipient(e['uid']!),
                    ),
                  )
                  .toList(),
            ),
            if (_recipients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '검색하여 직원을 추가하세요. (본인은 자동 포함)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: kSearchBarH + dropdownMaxH,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: widget.repo.watchUsersMirror(),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<List<Map<String, dynamic>>> snap,
                      ) {
                        final String q = _searchC.text.trim();
                        if (q.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        if (snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData) {
                          return const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final List<Map<String, dynamic>> all =
                            snap.data ?? <Map<String, dynamic>>[];
                        final List<Map<String, dynamic>> hit = all
                            .where((Map<String, dynamic> s) {
                              final String uid = (s['uid'] as String?) ?? '';
                              if (myUid != null && uid == myUid) {
                                return false;
                              }
                              return _staffMatches(s, q);
                            })
                            .take(40)
                            .toList();
                        if (hit.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                '검색 결과가 없습니다.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          );
                        }
                        return Material(
                          elevation: 12,
                          shadowColor: Colors.black38,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            physics: const ClampingScrollPhysics(),
                            itemCount: hit.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (BuildContext c, int i) {
                              final Map<String, dynamic> s = hit[i];
                              final String uid =
                                  (s['uid'] as String?)?.trim() ?? '';
                              final bool selected = _isRecipientUid(uid);
                              final String title = _messengerStaffDisplayName(s);
                              final String email =
                                  (s['email'] as String?)?.trim() ?? '';
                              final String branch = _messengerStaffBranch(s);
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: _MessengerStaffAvatar(s, size: 34),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  <String>[
                                    if (branch.isNotEmpty) branch,
                                    if (email.isNotEmpty) email,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                trailing: selected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF22C55E),
                                        size: 18,
                                      )
                                    : const Icon(
                                        Icons.add_circle_outline,
                                        color: Color(0xFF94A3B8),
                                        size: 18,
                                      ),
                                tileColor: selected
                                    ? const Color(0xFF22C55E).withOpacity(0.08)
                                    : null,
                                onTap: () => _toggleRecipient(s),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: kSearchBarH,
                    child: TextField(
                      controller: _searchC,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '직원 검색',
                        hintText: '이름, 이메일, 사업소, 직책',
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _creating ? null : _create,
          child: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('만들기'),
        ),
      ],
    );
  }
}
