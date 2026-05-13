import 'package:flutter/material.dart';
import '../models/location.dart';
import 'map_view.dart';

class LocationPage extends StatelessWidget {
  final LocationInfo locationInfo;

  const LocationPage({
    super.key,
    required this.locationInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              '찾아오시는 길',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 4,
              color: Colors.orange,
            ),
            const SizedBox(height: 40),
            // 지도 영역 (비율 유지)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 40),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9, // 16:9 비율 유지
                  child: MapView(address: locationInfo.mapAddress),
                ),
              ),
            ),
            // 정보 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.location_on,
                    label: '주소',
                    value: locationInfo.address,
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(
                    icon: Icons.phone,
                    label: '문의전화',
                    value: locationInfo.phone,
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(
                    icon: Icons.directions_bus,
                    label: '버스',
                    value: locationInfo.busInfo,
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(
                    icon: Icons.train,
                    label: '지하철',
                    value: locationInfo.subwayInfo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.blue[900],
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
