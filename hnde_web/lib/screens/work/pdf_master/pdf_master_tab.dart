import 'package:flutter/material.dart';
import '../tools/tool_navigator.dart';
import '../models/tool_definition.dart';

class PDFMasterTab extends StatefulWidget {
  const PDFMasterTab({super.key});

  @override
  State<PDFMasterTab> createState() => _PDFMasterTabState();
}

class _PDFMasterTabState extends State<PDFMasterTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        body: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'PDF 구성'),
                Tab(text: 'PDF 최적화'),
                Tab(text: 'PDF로 변환'),
                Tab(text: 'PDF에서 변환'),
                Tab(text: 'PDF 편집'),
                Tab(text: 'PDF 보안'),
                Tab(text: 'AI 기능'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPDFComposition(),
                  _buildPDFOptimization(),
                  _buildToPDFConversion(),
                  _buildFromPDFConversion(),
                  _buildPDFEdit(),
                  _buildPDFSecurity(),
                  _buildAIFeatures(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPDFComposition() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.merge_type,
          title: 'PDF 합치기',
          subtitle: '여러 PDF 파일을 하나로 병합',
          gradient: [Colors.red.shade400, Colors.red.shade600],
          onTap: () => ToolNavigator.navigateToTool(context, ToolType.pdfMerge),
        ),
        _buildToolCard(
          icon: Icons.content_cut,
          title: 'PDF 분할',
          subtitle: 'PDF를 여러 파일로 나누기',
          gradient: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        _buildToolCard(
          icon: Icons.delete_outline,
          title: '페이지 제거',
          subtitle: '불필요한 페이지 삭제',
          gradient: [Colors.red.shade300, Colors.red.shade500],
        ),
        _buildToolCard(
          icon: Icons.open_in_full,
          title: '페이지 추출',
          subtitle: '특정 페이지만 추출',
          gradient: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
        ),
        _buildToolCard(
          icon: Icons.reorder,
          title: 'PDF 구성',
          subtitle: '페이지 순서 재정렬',
          gradient: [Colors.brown.shade400, Colors.brown.shade600],
        ),
        _buildToolCard(
          icon: Icons.scanner,
          title: 'PDF로 스캔',
          subtitle: '이미지를 PDF로 변환',
          gradient: [Colors.grey.shade400, Colors.grey.shade600],
        ),
      ],
    );
  }

  Widget _buildPDFOptimization() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.compress,
          title: 'PDF 압축',
          subtitle: '파일 크기 줄이기',
          gradient: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        _buildToolCard(
          icon: Icons.restore,
          title: 'PDF 복구',
          subtitle: '손상된 PDF 복구',
          gradient: [Colors.lightBlue.shade400, Colors.lightBlue.shade600],
        ),
        _buildToolCard(
          icon: Icons.archive,
          title: 'PDF/A 변환',
          subtitle: '표준 형식으로 변환',
          gradient: [Colors.cyan.shade400, Colors.cyan.shade600],
        ),
      ],
    );
  }

  Widget _buildToPDFConversion() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.image,
          title: 'JPG → PDF',
          subtitle: '이미지를 PDF로 변환',
          gradient: [Colors.green.shade400, Colors.green.shade600],
        ),
        _buildToolCard(
          icon: Icons.description,
          title: 'Word → PDF',
          subtitle: 'DOC/DOCX 파일을 PDF로 변환',
          gradient: [Colors.lightGreen.shade400, Colors.lightGreen.shade600],
        ),
        _buildToolCard(
          icon: Icons.insert_drive_file,
          title: 'HWP → PDF',
          subtitle: '한글 파일을 PDF로 변환',
          gradient: [Colors.purple.shade400, Colors.purple.shade600],
        ),
        _buildToolCard(
          icon: Icons.slideshow,
          title: 'PowerPoint → PDF',
          subtitle: 'PPT/PPTX를 PDF로 변환',
          gradient: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
        ),
        _buildToolCard(
          icon: Icons.grid_on,
          title: 'Excel → PDF',
          subtitle: 'XLS/XLSX를 PDF로 변환',
          gradient: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
        _buildToolCard(
          icon: Icons.language,
          title: 'HTML → PDF',
          subtitle: '웹페이지를 PDF로 변환',
          gradient: [Colors.teal.shade400, Colors.teal.shade600],
        ),
      ],
    );
  }

  Widget _buildFromPDFConversion() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.image_outlined,
          title: 'PDF → JPG',
          subtitle: 'PDF를 이미지로 변환',
          gradient: [Colors.green.shade300, Colors.green.shade500],
        ),
        _buildToolCard(
          icon: Icons.description_outlined,
          title: 'PDF → Word',
          subtitle: 'PDF를 편집 가능한 Word로',
          gradient: [Colors.lightGreen.shade300, Colors.lightGreen.shade500],
        ),
        _buildToolCard(
          icon: Icons.slideshow_outlined,
          title: 'PDF → PowerPoint',
          subtitle: 'PDF를 PPT로 변환',
          gradient: [Colors.deepPurple.shade300, Colors.deepPurple.shade500],
        ),
        _buildToolCard(
          icon: Icons.grid_on_outlined,
          title: 'PDF → Excel',
          subtitle: 'PDF를 스프레드시트로',
          gradient: [Colors.indigo.shade300, Colors.indigo.shade500],
        ),
        _buildToolCard(
          icon: Icons.image_search,
          title: 'PDF → TXT',
          subtitle: 'PDF를 텍스트로 변환',
          gradient: [Colors.blueGrey.shade300, Colors.blueGrey.shade500],
        ),
        _buildToolCard(
          icon: Icons.text_fields,
          title: 'PDF → OCR',
          subtitle: '스캔한 PDF를 텍스트로',
          gradient: [Colors.amber.shade300, Colors.amber.shade500],
        ),
      ],
    );
  }

  Widget _buildPDFEdit() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.rotate_right,
          title: 'PDF 회전',
          subtitle: 'PDF 페이지 방향 변경',
          gradient: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        _buildToolCard(
          icon: Icons.add_circle_outline,
          title: '페이지 번호',
          subtitle: '페이지 번호 추가',
          gradient: [Colors.cyan.shade400, Colors.cyan.shade600],
        ),
        _buildToolCard(
          icon: Icons.add_photo_alternate,
          title: '워터마크',
          subtitle: '이미지/문자 워터마크 추가',
          gradient: [Colors.blueGrey.shade400, Colors.blueGrey.shade600],
        ),
        _buildToolCard(
          icon: Icons.crop,
          title: 'PDF 자르기',
          subtitle: '페이지 여백 조정',
          gradient: [Colors.green.shade400, Colors.green.shade600],
        ),
        _buildToolCard(
          icon: Icons.edit,
          title: 'PDF 편집',
          subtitle: '텍스트/이미지 추가 및 편집',
          gradient: [Colors.lime.shade400, Colors.lime.shade600],
        ),
        _buildToolCard(
          icon: Icons.text_fields,
          title: '텍스트 추가',
          subtitle: 'PDF에 텍스트 추가',
          gradient: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ],
    );
  }

  Widget _buildPDFSecurity() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.lock_open,
          title: 'PDF 잠금해제',
          subtitle: '비밀번호로 보호된 PDF 열기',
          gradient: [Colors.amber.shade400, Colors.amber.shade600],
        ),
        _buildToolCard(
          icon: Icons.lock,
          title: 'PDF 보호',
          subtitle: '비밀번호로 PDF 보호',
          gradient: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        _buildToolCard(
          icon: Icons.draw,
          title: 'PDF에 서명',
          subtitle: '전자 서명 추가',
          gradient: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
        ),
        _buildToolCard(
          icon: Icons.block,
          title: 'PDF 검열',
          subtitle: '민감한 정보 제거',
          gradient: [Colors.brown.shade400, Colors.brown.shade600],
        ),
        _buildToolCard(
          icon: Icons.gavel,
          title: 'PDF 비교',
          subtitle: '두 PDF 파일 비교',
          gradient: [Colors.pink.shade400, Colors.pink.shade600],
        ),
      ],
    );
  }

  Widget _buildAIFeatures() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildToolCard(
          icon: Icons.auto_awesome,
          title: 'AI: PDF 요약',
          subtitle: 'PDF 내용 자동 요약',
          gradient: [Colors.pink.shade300, Colors.pink.shade500],
          isNew: true,
        ),
        _buildToolCard(
          icon: Icons.chat_bubble_outline,
          title: 'AI: PDF 질의응답',
          subtitle: 'PDF 내용 질문하기',
          gradient: [Colors.purple.shade300, Colors.purple.shade500],
          isNew: true,
        ),
        _buildToolCard(
          icon: Icons.translate,
          title: 'AI: PDF 번역',
          subtitle: 'PDF 내용 자동 번역',
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
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
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
