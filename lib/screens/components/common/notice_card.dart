import 'package:flutter/material.dart';

class NoticeCard extends StatelessWidget {
  final String title;
  final String summary;
  final VoidCallback? onDetail;
  const NoticeCard({required this.title, required this.summary, this.onDetail, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF336699))),
            const SizedBox(height: 12),
            Text(summary, style: const TextStyle(fontSize: 16, color: Colors.black87)),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: onDetail,
                child: const Text('상세보기', style: TextStyle(color: Color(0xFF4DA3D2))),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 