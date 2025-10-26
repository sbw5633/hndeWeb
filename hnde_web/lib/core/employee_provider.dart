import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeProvider extends ChangeNotifier {
  List<AppUser> _employees = [];
  bool _isLoading = false;
  bool _isLoaded = false;

  List<AppUser> get employees => _employees;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  Future<void> loadEmployees() async {
    if (_isLoaded) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('approved', isEqualTo: true)
          .get();

      _employees = snapshot.docs.map((doc) {
        return AppUser.fromJson(
          doc.data(),
          uid: doc.id,
        );
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      _isLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshEmployees() async {
    _isLoaded = false;
    await loadEmployees();
  }
}

