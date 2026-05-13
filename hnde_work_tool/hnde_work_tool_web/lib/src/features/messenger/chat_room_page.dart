import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message_model.dart';
import '../../models/conversation_room_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../../utils/tab_attention.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({
    required this.conversationId,
    this.standalone = false,
    super.key,
  });

  final String conversationId;
  final bool standalone;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _sending = false;
  bool _background = false;

  AnimationController? _blink;
  Timestamp? _lastSeenLastMessageAt;
  String _baseTitle = '채팅';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 첫 진입 시 읽음 처리
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
      try {
        await repo.markConversationRead(widget.conversationId);
      } on Object {
        // ignore
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabAttentionStop();
    _blink?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (!_background) {
      _stopBlink();
    }
  }

  void _startBlink() {
    tabAttentionStart(baseTitle: _baseTitle);
    _blink ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  void _stopBlink() {
    tabAttentionStop();
    _blink?.stop();
    _blink?.dispose();
    _blink = null;
  }

  Future<void> _send(WorkFirestoreRepository repo) async {
    if (_sending) return;
    final String t = _input.text.trim();
    if (t.isEmpty) return;
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
    } on Object {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<ConversationRoomModel?>(
      stream: repo.watchConversationRoom(widget.conversationId),
      builder: (BuildContext context, AsyncSnapshot<ConversationRoomModel?> roomSnap) {
        if (roomSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SelectableText(
                  '대화방을 불러오지 못했습니다.\n${roomSnap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
          );
        }
        final ConversationRoomModel? room = roomSnap.data;
        final String title = _roomTitle(room, myUid);
        _baseTitle = title;

        // 백그라운드에서 상대 메시지 도착 시 깜빡임
        final Timestamp? lastAt = room?.lastMessageAt;
        if (lastAt != null) {
          final bool changed = _lastSeenLastMessageAt == null ||
              lastAt.millisecondsSinceEpoch !=
                  _lastSeenLastMessageAt!.millisecondsSinceEpoch;
          if (changed) {
            _lastSeenLastMessageAt = lastAt;
            final bool fromOther = myUid != null && room?.lastMessageSenderUid != myUid;
            if (_background && fromOther) {
              _startBlink();
            }
          }
        }

        final Color primary = Theme.of(context).colorScheme.primary;
        final Color appbarColor = _blink == null ? primary : primary;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Column(
            children: <Widget>[
              if (!widget.standalone)
                AppBar(
                  backgroundColor: appbarColor,
                  foregroundColor: Colors.white,
                  title: _blink == null
                      ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : AnimatedBuilder(
                          animation: _blink!,
                          builder: (BuildContext context, _) {
                            final double t = _blink!.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08 + 0.20 * t),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35 + 0.45 * t),
                                ),
                              ),
                              child: Text(
                                '$title · 새 메시지',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            );
                          },
                        ),
                  actions: <Widget>[
                    if (_blink != null)
                      IconButton(
                        tooltip: '알림 끄기',
                        onPressed: () => setState(_stopBlink),
                        icon: const Icon(Icons.notifications_off_outlined),
                      ),
                  ],
                ),
              Expanded(
                child: Container(
                  child: StreamBuilder<List<ChatMessageModel>>(
                    stream: repo.watchConversationMessages(widget.conversationId),
                    builder: (BuildContext context, AsyncSnapshot<List<ChatMessageModel>> snap) {
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
                      final List<ChatMessageModel> msgs = snap.data ?? <ChatMessageModel>[];
                      // 캐시 시드가 없더라도 로딩 스피너는 띄우지 않음 (즉시 화면 유지)
                      if (msgs.isEmpty) {
                        return const Center(
                          child: Text('첫 메시지를 보내 보세요.'),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
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
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 520),
                                child: Column(
                                  crossAxisAlignment:
                                      mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (!mine)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          m.senderDisplay.isEmpty ? '(알 수 없음)' : m.senderDisplay,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: mine ? primary : Colors.white,
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
                                          color: mine ? Colors.white : const Color(0xFF0F172A),
                                          fontSize: 14,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _fmtMsgTime(m.createdAt),
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '메시지 입력',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _send(repo),
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
          ),
        );
      },
    );
  }

  String _roomTitle(ConversationRoomModel? room, String? myUid) {
    if (room == null || myUid == null) return '대화';
    if (room.type == ConversationRoomModel.typeGroup) {
      final String gt = (room.groupTitle ?? '').trim();
      if (gt.isNotEmpty) return gt;
      final List<String> others = room.participantUids.where((String id) => id != myUid).toList();
      if (others.isEmpty) return '그룹 대화';
      if (others.length <= 3) return others.join(', ');
      return '${others.take(3).join(', ')} 외 ${others.length - 3}명';
    }
    if (room.participantUids.length == 1 && room.participantUids.first == myUid) {
      return '나에게 보내기';
    }
    for (final String id in room.participantUids) {
      if (id != myUid) return id;
    }
    return '대화';
  }

  String _fmtMsgTime(Timestamp? t) {
    if (t == null) return '';
    final DateTime d = t.toDate();
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(d),
      alwaysUse24HourFormat: true,
    );
  }
}

