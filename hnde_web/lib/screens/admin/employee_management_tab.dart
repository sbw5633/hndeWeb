import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../core/select_info_provider.dart';
import '../../core/employee_provider.dart';
import '../../core/loading_provider.dart';
import '../../utils/search_filter_widget.dart';

class EmployeeManagementTab extends StatefulWidget {
  final AppUser currentUser;
  final Function(bool hasChanges)? onChanges;
  
  const EmployeeManagementTab({
    super.key, 
    required this.currentUser,
    this.onChanges,
  });

  @override
  State<EmployeeManagementTab> createState() => EmployeeManagementTabState();
}

class EmployeeManagementTabState extends State<EmployeeManagementTab> {
  String _searchQuery = '';
  final Map<String, Map<String, dynamic>> _pendingChanges = {};

  @override
  void initState() {
    super.initState();
    // 직원 데이터 로드
    Future.microtask(() {
      context.read<EmployeeProvider>().loadEmployees();
    });
  }

  bool get hasPendingChanges => _pendingChanges.isNotEmpty;

  void addPendingChange(String userId, String field, dynamic value) {
    setState(() {
      if (!_pendingChanges.containsKey(userId)) {
        _pendingChanges[userId] = {};
      }
      _pendingChanges[userId]![field] = value;
    });
    
    // 부모에 변경사항 알림
    widget.onChanges?.call(true);
  }

  Future<void> saveChanges() async {
    final loadingProvider = context.read<LoadingProvider>();
    
    try {
      // 로딩 시작
      loadingProvider.setLoading(true, text: '변경사항 저장 중...');
      
      final batch = FirebaseFirestore.instance.batch();
      
      for (final entry in _pendingChanges.entries) {
        final userId = entry.key;
        final changes = entry.value;
        
        final userRef = FirebaseFirestore.instance.collection('Users').doc(userId);
        batch.update(userRef, changes);
      }
      
      await batch.commit();
      
      setState(() {
        _pendingChanges.clear();
      });
      
      // 부모에 변경사항 없음 알림
      widget.onChanges?.call(false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 변경사항이 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Provider 새로고침
      context.read<EmployeeProvider>().refreshEmployees();
      
      // 로딩 완료
      loadingProvider.setLoading(false);
    } catch (e) {
      // 로딩 완료
      loadingProvider.setLoading(false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();
    final selectInfoProvider = context.watch<SelectInfoProvider>();

    return Column(
      children: [
        SearchFilterWidget(
          searchHint: '이름으로 검색',
          showBranchFilter: false,
          backgroundColor: Colors.white.withValues(alpha: 0.5),
          onSearchChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
          onBranchChanged: (branch) {
            // 사용하지 않음
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: employeeProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : employeeProvider.employees.isEmpty
                  ? const Center(child: Text('승인된 직원이 없습니다.'))
                  : _buildEmployeeList(employeeProvider.employees, selectInfoProvider),
        ),
      ],
    );
  }

  Widget _buildEmployeeList(List<AppUser> employees, SelectInfoProvider selectInfoProvider) {
    // 검색 필터링
    final filteredEmployees = _searchQuery.isEmpty
        ? employees
        : employees.where((user) =>
            user.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (filteredEmployees.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.separated(
        itemCount: filteredEmployees.length,
        separatorBuilder: (_, __) => const Divider(height: 4),
        itemBuilder: (context, index) {
          final user = filteredEmployees[index];
          return _EmployeeRow(
            user: user,
            parentState: this,
            selectInfoProvider: selectInfoProvider,
          );
        },
      ),
    );
  }
}

class _EmployeeRow extends StatefulWidget {
  final AppUser user;
  final EmployeeManagementTabState parentState;
  final SelectInfoProvider selectInfoProvider;

  const _EmployeeRow({
    required this.user,
    required this.parentState,
    required this.selectInfoProvider,
  });

  @override
  State<_EmployeeRow> createState() => _EmployeeRowState();
}

class _EmployeeRowState extends State<_EmployeeRow> {
  late AppUser currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
  }

  void _updateUserField(String field, dynamic value) {
    setState(() {
      if (field == 'permissionLevel') {
        currentUser = AppUser(
          uid: currentUser.uid,
          name: currentUser.name,
          email: currentUser.email,
          affiliation: currentUser.affiliation,
          role: currentUser.role,
          permissionLevel: PermissionLevel.fromLevel(value),
          approved: currentUser.approved,
          createdAt: currentUser.createdAt,
          lastLoginAt: currentUser.lastLoginAt,
        );
      } else if (field == 'affiliation') {
        currentUser = AppUser(
          uid: currentUser.uid,
          name: currentUser.name,
          email: currentUser.email,
          affiliation: value,
          role: currentUser.role,
          permissionLevel: currentUser.permissionLevel,
          approved: currentUser.approved,
          createdAt: currentUser.createdAt,
          lastLoginAt: currentUser.lastLoginAt,
        );
      } else {
        currentUser = AppUser(
          uid: currentUser.uid,
          name: currentUser.name,
          email: currentUser.email,
          affiliation: currentUser.affiliation,
          role: value,
          permissionLevel: currentUser.permissionLevel,
          approved: currentUser.approved,
          createdAt: currentUser.createdAt,
          lastLoginAt: currentUser.lastLoginAt,
        );
      }
    });

    // 부모 상태에 변경사항 추가
    widget.parentState.addPendingChange(widget.user.uid, field, value);
  }

  @override
  Widget build(BuildContext context) {
    final branches = widget.selectInfoProvider.branches;
    final positions = widget.selectInfoProvider.positions;
    final ranks = widget.selectInfoProvider.ranks;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser.email,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildDropdown(
              label: '권한',
              value: currentUser.permissionLevel,
              items: PermissionLevel.values
                  .where((level) =>
                      level != PermissionLevel.guest &&
                      level != PermissionLevel.suspended &&
                      level != PermissionLevel.deleted)
                  .map((level) => DropdownMenuItem(
                        value: level,
                        child: Text(level.description),
                      ))
                  .toList(),
              onChanged: currentUser.permissionLevel == PermissionLevel.appAdmin
                  ? null
                  : (PermissionLevel? value) {
                      if (value != null) {
                        _updateUserField('permissionLevel', value.level);
                      }
                    },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildDropdown(
              label: '사업소',
              value: currentUser.affiliation,
              items: branches
                  .map((branch) => DropdownMenuItem(
                        value: branch['name'] as String,
                        child: Text(branch['name'] as String),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateUserField('affiliation', value);
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDropdown(
              label: '직책',
              value: currentUser.role,
              items: positions
                  .map((position) => DropdownMenuItem(
                        value: position['name'] as String,
                        child: Text(position['name'] as String),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateUserField('role', value);
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDropdown(
              label: '급수',
              value: ranks.isNotEmpty ? ranks.first['name'] as String : '',
              items: ranks
                  .map((rank) => DropdownMenuItem(
                        value: rank['name'] as String,
                        child: Text(rank['name'] as String),
                      ))
                  .toList(),
              onChanged: (value) {
                // 급수 업데이트 로직 추가 필요
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    Function(T?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
        ),
      ],
    );
  }
}
