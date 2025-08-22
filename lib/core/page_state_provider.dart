import 'package:flutter/material.dart';

class PageStateProvider extends ChangeNotifier {
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  String _currentPage = '';
  VoidCallback? _submitFormCallback;
  bool get isEditing => _isEditing;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  String get currentPage => _currentPage;

  void setEditing(bool editing) {
    _isEditing = editing;
    notifyListeners();
  }

  void setUnsavedChanges(bool hasChanges) {
    _hasUnsavedChanges = hasChanges;
    notifyListeners();
  }

  void setCurrentPage(String page) {
    _currentPage = page;
    notifyListeners();
  }

    /// 폼 제출 콜백 설정 (추가)
  void setSubmitFormCallback(VoidCallback? callback) {
    _submitFormCallback = callback;
    notifyListeners();
  }

  /// 저장된 폼 제출 콜백 실행 (추가)
  void executeSubmitFormCallback() {
    _submitFormCallback?.call();
  }

  void clearState() {
    _isEditing = false;
    _hasUnsavedChanges = false;
    _currentPage = '';
    _submitFormCallback = null;
    notifyListeners();
  }

  /// 안전한 상태 초기화
  void safeClearState() {
    try {
      clearState();
    } catch (e) {
      // 오류 발생 시에도 기본값으로 초기화
      _isEditing = false;
      _hasUnsavedChanges = false;
      _currentPage = '';
      _submitFormCallback = null;
    }
  }
} 