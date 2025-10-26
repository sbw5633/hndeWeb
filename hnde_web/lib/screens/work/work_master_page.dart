import 'package:flutter/material.dart';
import 'pdf_master/pdf_master_tab.dart';
import 'img_master/img_master_tab.dart';

class WorkMasterPage extends StatefulWidget {
  const WorkMasterPage({super.key});

  @override
  State<WorkMasterPage> createState() => _WorkMasterPageState();
}

class _WorkMasterPageState extends State<WorkMasterPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('업무 도구'),
        leading: _selectedIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              )
            : null,
      ),
      body: _selectedIndex == 0
          ? _buildMainMenu()
          : _buildSelectedPage(),
    );
  }

  Widget _buildMainMenu() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 64) / 3;
        
        int crossAxisCount;
        if (cardWidth >= 280) {
          crossAxisCount = 3;
        } else if (cardWidth >= 200) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '도구 선택',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _buildMenuGrid(crossAxisCount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuGrid(int crossAxisCount) {
    final cards = [
      _buildMenuCard(
        icon: Icons.picture_as_pdf,
        title: 'PDF 마스터',
        subtitle: 'PDF 편집, 변환, 압축',
        gradient: const [
          Color(0xFFE53935),
          Color(0xFFD32F2F),
        ],
        onTap: () => setState(() => _selectedIndex = 1),
      ),
      _buildMenuCard(
        icon: Icons.image,
        title: 'IMG 마스터',
        subtitle: '이미지 편집, 변환, 압축',
        gradient: const [
          Color(0xFF9C27B0),
          Color(0xFF7B1FA2),
        ],
        onTap: () => setState(() => _selectedIndex = 2),
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < cards.length; i += crossAxisCount)
          Row(
            children: [
              for (int j = i; j < (i + crossAxisCount) && j < cards.length; j++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: j < (i + crossAxisCount) - 1 && j < cards.length - 1 ? 16 : 0,
                      bottom: i + crossAxisCount < cards.length ? 16 : 0,
                    ),
                    child: cards[j],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 180,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 1:
        return const PDFMasterTab();
      case 2:
        return const IMGMasterTab();
      default:
        return _buildMainMenu();
    }
  }
}

