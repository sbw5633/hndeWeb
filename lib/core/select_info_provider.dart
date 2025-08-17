import 'package:flutter/material.dart';
import '../services/firebase/employee_select_info_service.dart';

class SelectInfoProvider extends ChangeNotifier {
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> positions = [];
  List<Map<String, dynamic>> ranks = [];
  bool loaded = false;

  Future<void> loadAll() async {
    branches = await EmployeeSelectInfoService.getBranches();
    positions = await EmployeeSelectInfoService.getPositions();
    ranks = await EmployeeSelectInfoService.getRanks();
    loaded = true;
    notifyListeners();
  }

  void clear() {
    branches = [];
    positions = [];
    ranks = [];
    loaded = false;
    notifyListeners();
  }
} 