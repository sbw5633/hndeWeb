import 'package:flutter/material.dart';
import '../models/recruitment.dart';

class RecruitmentPage extends StatelessWidget {
  final Recruitment recruitment;

  const RecruitmentPage({
    super.key,
    required this.recruitment,
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
              '인재채용',
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
            // 상단 이미지 (있는 경우에만 표시)
            if (recruitment.topImageUrl != null &&
                recruitment.topImageUrl!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                height: 300,
                margin: const EdgeInsets.only(bottom: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    recruitment.topImageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child:
                              Icon(Icons.image, size: 64, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            // 통합 카드 (채용공고 + 지원방법 + 전형절차)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 채용공고 섹션
                  _RecruitmentSubSection(
                    section: recruitment.jobOpenings ??
                        RecruitmentSection(title: '채용공고'),
                  ),
                  const SizedBox(height: 40),
                  // 지원방법과 전형절차 좌우 배치
                  _RecruitmentSubSection(
                    section: recruitment.applicationMethod ??
                        RecruitmentSection(title: '지원방법'),
                  ),
                  const SizedBox(width: 24),
                  // 전형절차
                  _RecruitmentSubSection(
                    section: recruitment.process ??
                        RecruitmentSection(title: '전형절차'),
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

class _RecruitmentSubSection extends StatelessWidget {
  final RecruitmentSection section;

  const _RecruitmentSubSection({
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        Text(
          section.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 16),
        // 이미지 (있는 경우)
        if (section.imageUrl != null && section.imageUrl!.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              maxHeight: 600,
            ),
            // height: 200,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                section.imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image, size: 48, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
        // 텍스트 내용 (있는 경우)
        if (section.content != null && section.content!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              section.content!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.8,
              ),
            ),
          )
        else if (section.imageUrl == null || section.imageUrl!.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Text(
                '등록된 내용이 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
