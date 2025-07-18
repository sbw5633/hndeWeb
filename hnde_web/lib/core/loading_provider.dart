import 'package:flutter/material.dart';

class LoadingProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _loadingText;

  bool get isLoading => _isLoading;
  String? get loadingText => _loadingText;

  void setLoading(bool value, {String? text}) {
    _isLoading = value;
    _loadingText = text;
    notifyListeners();
  }
} 