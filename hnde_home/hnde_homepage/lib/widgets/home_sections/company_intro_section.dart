import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/data_service.dart';
import '../../models/vision.dart';
import '../../models/ceo_greeting.dart';

class CompanyIntroSection extends StatelessWidget {
  const CompanyIntroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? 40 : 80,
        right: isMobile ? 40 : 80,
        top: 80,
        bottom: 80,
      ),
      child: FutureBuilder(
        future: Future.wait([
          dataService.getVision(),
          dataService.getCEOGreeting(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final vision = snapshot.data?[0] as VisionContent?;
          final greeting = snapshot.data?[1] as CEOGreeting?;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽: 비전 이미지
              if (!isMobile && vision?.imageUrl != null) ...[
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 400,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        vision!.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, size: 64),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 60),
              ],
              // 오른쪽: 텍스트 내용
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'H&DE',
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
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 32),
                    if (greeting?.textLines.isNotEmpty == true) ...[
                      ...greeting!.textLines.take(3).map((line) {
                        if (line.isDivider) return const SizedBox(height: 16);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            line.text,
                            style: GoogleFonts.notoSans(
                              fontSize: isMobile ? 16 : 18,
                              color: Colors.grey[800],
                              height: 1.8,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ] else if (vision?.content != null) ...[
                      Text(
                        vision!.content!,
                        style: GoogleFonts.notoSans(
                          fontSize: isMobile ? 16 : 18,
                          color: Colors.grey[800],
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '회사소개 더보기',
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

