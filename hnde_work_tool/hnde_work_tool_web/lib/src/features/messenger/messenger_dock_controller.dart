import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MessengerConversationSort {
  unreadThenRecent,
  recent,
}

class MessengerDockController extends ChangeNotifier {
  MessengerDockController() {
    _loadPrefs();
  }

  bool isOpen = false;

  String? activeConversationId;

  /// 기본: 오른쪽에 도킹.
  bool floating = false;

  /// 도킹일 때 폭.
  double dockWidth = 520;

  /// 플로팅일 때 위치/크기.
  Offset floatingPos = const Offset(0, 0);
  Size floatingSize = const Size(520, 760);

  MessengerConversationSort sort = MessengerConversationSort.unreadThenRecent;

  static const String _prefsKeyFavorites = 'messenger.favorites';
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final Set<String> favoriteConversationIds = <String>{};

  Future<void> _loadPrefs() async {
    try {
      final SharedPreferences p = await _prefs;
      final List<String> fav = p.getStringList(_prefsKeyFavorites) ?? <String>[];
      favoriteConversationIds
        ..clear()
        ..addAll(fav.map((String e) => e.trim()).where((String e) => e.isNotEmpty));
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  bool isFavorite(String conversationId) => favoriteConversationIds.contains(conversationId);

  Future<void> toggleFavorite(String conversationId) async {
    final String id = conversationId.trim();
    if (id.isEmpty) return;
    if (!favoriteConversationIds.add(id)) {
      favoriteConversationIds.remove(id);
    }
    notifyListeners();
    try {
      final SharedPreferences p = await _prefs;
      await p.setStringList(_prefsKeyFavorites, favoriteConversationIds.toList());
    } catch (_) {
      // ignore
    }
  }

  void open({String? conversationId}) {
    isOpen = true;
    if (conversationId != null && conversationId.trim().isNotEmpty) {
      activeConversationId = conversationId.trim();
    }
    notifyListeners();
  }

  void close() {
    isOpen = false;
    notifyListeners();
  }

  void setActive(String conversationId) {
    final String id = conversationId.trim();
    if (id.isEmpty) return;
    activeConversationId = id;
    notifyListeners();
  }

  void setSort(MessengerConversationSort next) {
    sort = next;
    notifyListeners();
  }

  void setDockWidth(double next, BoxConstraints constraints) {
    // 화면이 아주 좁을 때(min > max) clamp assertion 방지
    final double screenW = constraints.maxWidth;
    if (!screenW.isFinite || screenW <= 0) return;

    // 도킹 패널은 화면을 넘지 않도록 전체 폭까지 허용(92% 제한은 극단적 좁은 폭에서 오버플로/깨짐 유발)
    final double maxW = screenW;
    final double minW = math.min(360.0, maxW);
    final double maxAllowed = math.max(minW, maxW);
    final double clamped = next.clamp(minW, maxAllowed);
    if ((dockWidth - clamped).abs() < 0.5) return;
    dockWidth = clamped;
    notifyListeners();
  }

  void beginFloatingFromDock(BoxConstraints constraints) {
    if (floating) return;
    floating = true;
    final double maxW = constraints.maxWidth * 0.92;
    final double maxH = constraints.maxHeight * 0.96;
    final double minW = math.min(360.0, maxW);
    final double minH = math.min(520.0, maxH);
    final double w = dockWidth.clamp(minW, math.max(minW, maxW));
    final double h = floatingSize.height.clamp(minH, math.max(minH, maxH));
    floatingSize = Size(w, h);
    floatingPos = Offset(
      (constraints.maxWidth - w - 16).clamp(0.0, constraints.maxWidth - w),
      16.0,
    );
    notifyListeners();
  }

  void dockToRight() {
    if (!floating) return;
    floating = false;
    notifyListeners();
  }

  void moveFloatingBy(Offset delta, BoxConstraints constraints) {
    if (!floating) return;
    final double maxX = math.max(0.0, constraints.maxWidth - floatingSize.width);
    final double maxY = math.max(0.0, constraints.maxHeight - floatingSize.height);
    floatingPos = Offset(
      (floatingPos.dx + delta.dx).clamp(0.0, maxX),
      (floatingPos.dy + delta.dy).clamp(0.0, maxY),
    );
    notifyListeners();
  }

  void resizeFloatingBy(Offset delta, BoxConstraints constraints) {
    if (!floating) return;
    final double maxW = constraints.maxWidth * 0.95;
    final double maxH = constraints.maxHeight * 0.95;
    final double minW = math.min(360.0, maxW);
    final double minH = math.min(520.0, maxH);
    final double nextW =
        (floatingSize.width + delta.dx).clamp(minW, math.max(minW, maxW));
    final double nextH =
        (floatingSize.height + delta.dy).clamp(minH, math.max(minH, maxH));
    floatingSize = Size(nextW, nextH);
    moveFloatingBy(Offset.zero, constraints);
  }

  /// 화면 크기가 바뀌었을 때(또는 초기) 플로팅 창이 화면 밖/초과 크기가 되지 않도록 보정합니다.
  void clampFloatingToScreen(BoxConstraints constraints) {
    if (!floating) return;
    final double maxW = constraints.maxWidth;
    final double maxH = constraints.maxHeight;
    if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) return;

    final double minW = math.min(360.0, maxW);
    final double minH = math.min(520.0, maxH);
    final double w = floatingSize.width.clamp(minW, math.max(minW, maxW));
    final double h = floatingSize.height.clamp(minH, math.max(minH, maxH));

    bool changed = false;
    if ((floatingSize.width - w).abs() > 0.5 || (floatingSize.height - h).abs() > 0.5) {
      floatingSize = Size(w, h);
      changed = true;
    }

    final double maxX = math.max(0.0, constraints.maxWidth - floatingSize.width);
    final double maxY = math.max(0.0, constraints.maxHeight - floatingSize.height);
    final Offset next = Offset(
      floatingPos.dx.clamp(0.0, maxX),
      floatingPos.dy.clamp(0.0, maxY),
    );
    if ((floatingPos - next).distance > 0.5) {
      floatingPos = next;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

