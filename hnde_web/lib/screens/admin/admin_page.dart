import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import 'admin_settings_tab.dart';
import 'employee_management_tab.dart';
import 'signup_request_management_tab.dart';

class AdminPage extends StatefulWidget {
  final AppUser currentUser;
  
  const AdminPage({super.key, required this.currentUser});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;
  final GlobalKey _employeeTabKey = GlobalKey();
  bool _hasChanges = false;

  void _onEmployeeChanges(bool hasChanges) {
    setState(() {
      _hasChanges = hasChanges;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser.permissionLevel != PermissionLevel.appAdmin) {
      return const Scaffold(
        body: Center(child: Text('접근 권한이 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 페이지'),
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
        actions: _selectedIndex == 2 
            ? [
                IconButton(
                  icon: Icon(Icons.save, color: _hasChanges ? Colors.blue : Colors.grey),
                  onPressed: _hasChanges ? () async {
                    final employeeTabState = _employeeTabKey.currentState;
                    if (employeeTabState != null && employeeTabState is EmployeeManagementTabState) {
                      await employeeTabState.saveChanges();
                    }
                  } : null,
                  tooltip: '변경사항 저장',
                ),
              ]
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
        final cardWidth = (constraints.maxWidth - 64) / 3; // 3개 기준
        
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
                '관리 항목 선택',
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
        icon: Icons.settings,
        title: '기본 셋팅 관리',
        subtitle: '사업소, 직책, 급수 설정',
        onTap: () => setState(() => _selectedIndex = 1),
      ),
      _buildMenuCard(
        icon: Icons.people,
        title: '직원 관리',
        subtitle: '직원 정보 수정 및 관리',
        onTap: () => setState(() => _selectedIndex = 2),
      ),
      _buildMenuCard(
        icon: Icons.person_add,
        title: '가입 요청 관리',
        subtitle: '가입 승인 대기 관리',
        onTap: () => setState(() => _selectedIndex = 3),
        badgeStream: _getPendingSignupCount(),
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
    required VoidCallback onTap,
    Stream<int>? badgeStream,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.blue.shade100,
              ],
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 36,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              if (badgeStream != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: StreamBuilder<int>(
                    stream: badgeStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
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
        return const AdminSettingsTab();
      case 2:
        return EmployeeManagementTab(
          key: _employeeTabKey,
          currentUser: widget.currentUser,
          onChanges: _onEmployeeChanges,
        );
      case 3:
        return const SignupRequestManagementTab();
      default:
        return _buildMainMenu();
    }
  }

  Stream<int> _getPendingSignupCount() {
    return FirebaseFirestore.instance
        .collection('Users')
        .where('approved', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

