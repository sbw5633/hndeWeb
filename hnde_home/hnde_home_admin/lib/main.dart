import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/firebase.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  runApp(const ProviderScope(child: AdminApp()));
}
