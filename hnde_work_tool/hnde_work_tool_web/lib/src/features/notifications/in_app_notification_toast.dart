import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/app_notification_model.dart';

class InAppNotificationToastManager {
  InAppNotificationToastManager(this._overlay);

  final OverlayState _overlay;
  final List<OverlayEntry> _entries = <OverlayEntry>[];

  static const int _maxToasts = 3;

  void show({
    required AppNotificationModel notif,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    // 최신이 위로
    if (_entries.length >= _maxToasts) {
      try {
        _entries.removeLast().remove();
      } catch (_) {
        // ignore
      }
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return _ToastWidget(
          notif: notif,
          primaryColor: primaryColor,
          onDismiss: () {
            try {
              _entries.remove(entry);
              entry.remove();
            } catch (_) {
              // ignore
            }
          },
          onTap: () {
            try {
              _entries.remove(entry);
              entry.remove();
            } catch (_) {
              // ignore
            }
            onTap();
          },
        );
      },
    );

    _entries.insert(0, entry);
    _overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.notif,
    required this.primaryColor,
    required this.onDismiss,
    required this.onTap,
  });

  final AppNotificationModel notif;
  final Color primaryColor;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_c.forward());
    Timer(const Duration(milliseconds: 3300), () {
      if (!mounted) return;
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.12, curve: Curves.easeOut)),
    );
    final Animation<double> out = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.70, 1, curve: Curves.easeIn)),
    );
    return Positioned(
      top: 82,
      right: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, _) {
          final double opacity = (fade.value * out.value).clamp(0.0, 1.0);
          final double dy = (1 - fade.value) * -10;
          return IgnorePointer(
            ignoring: opacity < 0.05,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Material(
                        elevation: 18,
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFFFFBEB),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: widget.primaryColor.withOpacity(0.20)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: widget.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      widget.notif.title.isEmpty ? '알림' : widget.notif.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.notif.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, height: 1.2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: '닫기',
                                onPressed: widget.onDismiss,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

