import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsDockController extends ChangeNotifier {
  NotificationsDockController() {
    _load();
  }

  bool isOpen = false;
  double dockWidth = 380;

  static const String _kOpen = 'notifications.open';
  static const String _kWidth = 'notifications.width';
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<void> _load() async {
    try {
      final SharedPreferences p = await _prefs;
      isOpen = p.getBool(_kOpen) ?? false;
      dockWidth = (p.getDouble(_kWidth) ?? 380).clamp(300, 520);
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _save() async {
    try {
      final SharedPreferences p = await _prefs;
      await p.setBool(_kOpen, isOpen);
      await p.setDouble(_kWidth, dockWidth);
    } catch (_) {
      // ignore
    }
  }

  void open() {
    if (isOpen) return;
    isOpen = true;
    notifyListeners();
    _save();
  }

  void close() {
    if (!isOpen) return;
    isOpen = false;
    notifyListeners();
    _save();
  }

  void toggle() {
    isOpen ? close() : open();
  }

  void setDockWidth(double next, BoxConstraints constraints) {
    final double maxW = constraints.maxWidth;
    if (!maxW.isFinite || maxW <= 0) return;
    final double clamped = next.clamp(300.0, maxW.clamp(300.0, 520.0));
    if ((dockWidth - clamped).abs() < 0.5) return;
    dockWidth = clamped;
    notifyListeners();
    _save();
  }
}

