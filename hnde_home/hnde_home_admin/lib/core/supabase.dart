import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = 'https://gxyfxikezofjgoakgnxv.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4eWZ4aWtlem9mamdvYWtnbnh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxNDIzNTMsImV4cCI6MjA3NzcxODM1M30.fwQ8W5AO2TqLD7JOYjYJDgPbZ6aHXPdHjXVfPSuZdUU';
}

Future<void> initSupabase() async {
  await Supabase.initialize(
      url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
