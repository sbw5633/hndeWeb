import 'package:flutter/material.dart';

class DashboardAppBar extends StatelessWidget {
  const DashboardAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Text('사내 업무 시스템', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF336699))),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 32, color: Color(0xFF336699)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
} 