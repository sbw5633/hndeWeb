import 'package:flutter/material.dart';

class IMGMasterTab extends StatefulWidget {
  const IMGMasterTab({super.key});

  @override
  State<IMGMasterTab> createState() => _IMGMasterTabState();
}

class _IMGMasterTabState extends State<IMGMasterTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        body: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '압축/리사이즈'),
                Tab(text: '형식 변환'),
                Tab(text: '편집/필터'),
                Tab(text: '합성/효과'),
                Tab(text: '고급 편집'),
                Tab(text: 'AI 기능'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCompressResize(),
                  _buildFormatConversion(),
                  _buildEditFilter(),
                  _buildMergeEffects(),
                  _buildAdvancedEdit(),
                  _buildAIFeatures(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressResize() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.compress,
          title: '이미지 압축',
          subtitle: '파일 크기 줄이기',
          gradient: [Colors.red.shade400, Colors.red.shade600],
        ),
        _buildToolCard(
          icon: Icons.aspect_ratio,
          title: '이미지 리사이즈',
          subtitle: '크기 조정',
          gradient: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        _buildToolCard(
          icon: Icons.crop,
          title: '이미지 자르기',
          subtitle: '원하는 영역만 추출',
          gradient: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
        ),
        _buildToolCard(
          icon: Icons.photo_size_select_actual,
          title: '비율 유지 리사이즈',
          subtitle: '원본 비율 유지하며 크기 조정',
          gradient: [Colors.brown.shade400, Colors.brown.shade600],
        ),
      ],
    );
  }

  Widget _buildFormatConversion() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.image,
          title: 'JPG → PNG',
          subtitle: 'JPG를 PNG로 변환',
          gradient: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        _buildToolCard(
          icon: Icons.image_outlined,
          title: 'PNG → JPG',
          subtitle: 'PNG를 JPG로 변환',
          gradient: [Colors.lightBlue.shade400, Colors.lightBlue.shade600],
        ),
        _buildToolCard(
          icon: Icons.flip,
          title: 'WebP 변환',
          subtitle: 'WebP 형식으로 변환',
          gradient: [Colors.cyan.shade400, Colors.cyan.shade600],
        ),
        _buildToolCard(
          icon: Icons.refresh,
          title: 'GIF 변환',
          subtitle: 'GIF 생성/분해',
          gradient: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        _buildToolCard(
          icon: Icons.picture_as_pdf,
          title: '이미지 → PDF',
          subtitle: '이미지를 PDF로 변환',
          gradient: [Colors.purple.shade400, Colors.purple.shade600],
        ),
        _buildToolCard(
          icon: Icons.all_inclusive,
          title: '일괄 변환',
          subtitle: '여러 이미지 한번에 변환',
          gradient: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
      ],
    );
  }

  Widget _buildEditFilter() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.rotate_right,
          title: '이미지 회전',
          subtitle: '방향 변경',
          gradient: [Colors.green.shade400, Colors.green.shade600],
        ),
        _buildToolCard(
          icon: Icons.flip,
          title: '이미지 뒤집기',
          subtitle: '좌우/상하 반전',
          gradient: [Colors.lightGreen.shade400, Colors.lightGreen.shade600],
        ),
        _buildToolCard(
          icon: Icons.brightness_6,
          title: '밝기 조정',
          subtitle: '밝기/대비/채도 조정',
          gradient: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
        _buildToolCard(
          icon: Icons.tonality,
          title: '이미지 필터',
          subtitle: '다양한 효과 적용',
          gradient: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
        ),
        _buildToolCard(
          icon: Icons.colorize,
          title: '색상 조정',
          subtitle: '색상 수정',
          gradient: [Colors.pink.shade400, Colors.pink.shade600],
        ),
        _buildToolCard(
          icon: Icons.blur_on,
          title: '흐림 효과',
          subtitle: '블러 효과 적용',
          gradient: [Colors.purple.shade300, Colors.purple.shade500],
        ),
      ],
    );
  }

  Widget _buildMergeEffects() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.merge,
          title: '이미지 병합',
          subtitle: '여러 이미지를 한 페이지로',
          gradient: [Colors.red.shade300, Colors.red.shade500],
          isNew: true,
        ),
        _buildToolCard(
          icon: Icons.layers,
          title: '워터마크',
          subtitle: '텍스트/이미지 워터마크',
          gradient: [Colors.orange.shade300, Colors.orange.shade500],
        ),
        _buildToolCard(
          icon: Icons.photo_size_select_actual,
          title: '이미지 프레임',
          subtitle: '프레임 추가',
          gradient: [Colors.amber.shade400, Colors.amber.shade600],
        ),
        _buildToolCard(
          icon: Icons.border_style,
          title: '이미지 테두리',
          subtitle: '테두리 추가',
          gradient: [Colors.lime.shade400, Colors.lime.shade600],
        ),
        _buildToolCard(
          icon: Icons.grid_view,
          title: '이미지 격자',
          subtitle: '격자 배치',
          gradient: [Colors.yellow.shade400, Colors.yellow.shade600],
        ),
      ],
    );
  }

  Widget _buildAdvancedEdit() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.auto_awesome,
          title: '배경 제거',
          subtitle: '자동 배경 제거',
          gradient: [Colors.cyan.shade400, Colors.cyan.shade600],
        ),
        _buildToolCard(
          icon: Icons.brush,
          title: '이미지 색칠',
          subtitle: '색칠하기',
          gradient: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        _buildToolCard(
          icon: Icons.photo_filter,
          title: '이미지 모자이크',
          subtitle: '선택 영역 모자이크',
          gradient: [Colors.blueGrey.shade400, Colors.blueGrey.shade600],
        ),
        _buildToolCard(
          icon: Icons.text_fields,
          title: '이미지에 텍스트',
          subtitle: '텍스트 추가',
          gradient: [Colors.brown.shade400, Colors.brown.shade600],
        ),
        _buildToolCard(
          icon: Icons.auto_fix_high,
          title: '도형 추가',
          subtitle: '도형 그리기',
          gradient: [Colors.grey.shade400, Colors.grey.shade600],
        ),
      ],
    );
  }

  Widget _buildAIFeatures() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.search,
          title: 'AI: 이미지 설명',
          subtitle: '이미지 내용 설명',
          gradient: [Colors.pink.shade300, Colors.pink.shade500],
          isNew: true,
        ),
        _buildToolCard(
          icon: Icons.auto_awesome,
          title: 'AI: 이미지 생성',
          subtitle: '텍스트 → 이미지',
          gradient: [Colors.deepPurple.shade300, Colors.deepPurple.shade500],
          isNew: true,
        ),
        _buildToolCard(
          icon: Icons.image_outlined,
          title: 'AI: 이미지 변환',
          subtitle: '이미지 스타일 변경',
          gradient: [Colors.indigo.shade300, Colors.indigo.shade500],
          isNew: true,
        ),
        _buildToolCard(
          icon: Icons.remove_red_eye,
          title: 'AI: 이미지 개선',
          subtitle: '화질 자동 개선',
          gradient: [Colors.blue.shade300, Colors.blue.shade500],
          isNew: true,
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    bool isNew = false,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // TODO: 각 도구 페이지로 이동
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.pink.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.pink.shade300),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.pink,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
