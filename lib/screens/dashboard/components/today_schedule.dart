import 'package:flutter/material.dart';

class TodaySchedule extends StatelessWidget {
  const TodaySchedule({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal.shade50, Colors.teal.shade100],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.teal.shade600, size: 24),
                const SizedBox(width: 8),
                Text(
                  '오늘의 일정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildScheduleItem('', '일정 기능', '추후 제공 예정'),
            _buildScheduleItem('', '개발 중', ''),
            _buildScheduleItem('', '준비 중', ''),
            _buildScheduleItem('', 'Coming Soon', ''),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 일정 관리 페이지로 이동
                },
                icon: const Icon(Icons.event, size: 16),
                label: const Text('일정 관리'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String time, String title, String location) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            child: Text(
              time.isNotEmpty ? time : '•',
              style: TextStyle(
                fontSize: 12,
                color: Colors.teal.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (location.isNotEmpty)
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
