import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/service.dart';

class ServicesSection extends StatelessWidget {
  final List<Service> services;

  const ServicesSection({
    super.key,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: 80,
      ),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            '사업 분야',
            style: GoogleFonts.notoSans(
              fontSize: isMobile ? 32 : 48,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 4,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 60),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 4),
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: isMobile ? 1.5 : 1.2,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              return _ServiceCard(service: services[index]);
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;

  const _ServiceCard({
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    IconData getIcon() {
      switch (service.icon) {
        case 'design':
          return Icons.design_services;
        case 'architecture':
          return Icons.architecture;
        case 'construction':
          return Icons.construction;
        case 'consulting':
          return Icons.business_center;
        default:
          return Icons.work;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue[100]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              getIcon(),
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            service.title,
            style: GoogleFonts.notoSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            service.description,
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const Spacer(),
          ...service.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
