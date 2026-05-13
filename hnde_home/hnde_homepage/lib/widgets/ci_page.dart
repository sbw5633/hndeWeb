import 'package:flutter/material.dart';
import '../models/ci_info.dart';

class CIPage extends StatelessWidget {
  final CIInfo ciInfo;

  const CIPage({
    super.key,
    required this.ciInfo,
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
              ciInfo.title,
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
            // 좌우 레이아웃: 좌측 CI 표시, 우측 설명 및 내용
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 1000;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 좌측: CI 표시 영역
                      Expanded(
                        flex: 1,
                        child: _CIVisualSection(definition: ciInfo.definition),
                      ),
                      const SizedBox(width: 48),
                      // 우측: 설명 및 내용 영역
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MeaningSection(meaning: ciInfo.meaning),
                            const SizedBox(height: 32),
                            _DefinitionSection(definition: ciInfo.definition),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CIVisualSection(definition: ciInfo.definition),
                      const SizedBox(height: 32),
                      _MeaningSection(meaning: ciInfo.meaning),
                      const SizedBox(height: 32),
                      _DefinitionSection(definition: ciInfo.definition),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CIVisualSection extends StatelessWidget {
  final CIDefinition definition;

  const _CIVisualSection({required this.definition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // CI 로고/이미지 영역
          if (definition.type == CIDefinitionType.image &&
              definition.imageUrl != null &&
              definition.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                minHeight: 300,
                maxHeight: 500,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  definition.imageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'CI 이미지',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.blue[900],
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(
                      child: Text(
                        'H&DE',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Corporate Identity',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w500,
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

class _MeaningSection extends StatelessWidget {
  final CIMeaning meaning;

  const _MeaningSection({required this.meaning});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '의미',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            meaning.content,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DefinitionSection extends StatelessWidget {
  final CIDefinition definition;

  const _DefinitionSection({required this.definition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '정의',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 텍스트 내용만 표시 (이미지는 좌측에 표시)
          if (definition.type == CIDefinitionType.text &&
              definition.content != null &&
              definition.content!.isNotEmpty)
            Text(
              definition.content!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                height: 1.8,
              ),
            )
          else if (definition.type == CIDefinitionType.image &&
              (definition.content == null || definition.content!.isEmpty))
            Text(
              'CI는 Corporate Identity의 약자로, 기업의 정체성과 가치를 시각적으로 표현한 것입니다. H&DE의 CI는 고객 중심의 서비스 철학과 지속 가능한 성장을 상징합니다.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                height: 1.8,
              ),
            ),
        ],
      ),
    );
  }
}
