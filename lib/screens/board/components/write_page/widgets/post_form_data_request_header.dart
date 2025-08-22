import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/auth_provider.dart';
import '../../../../../../core/select_info_provider.dart';

class PostFormDataRequestHeader extends StatefulWidget {
  final List<String> selectedBranches;
  final Function(List<String>) onBranchesChanged;

  const PostFormDataRequestHeader({
    super.key,
    required this.selectedBranches,
    required this.onBranchesChanged,
  });

  @override
  State<PostFormDataRequestHeader> createState() => _PostFormDataRequestHeaderState();
}

class _PostFormDataRequestHeaderState extends State<PostFormDataRequestHeader> {
  List<String> _branchOptions = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeBranchOptions();
  }

  void _initializeBranchOptions() {
    final authProvider = context.read<AuthProvider>();
    final selectInfoProvider = context.read<SelectInfoProvider>();
    
    if (authProvider.appUser?.affiliation == '본사') {
      // 본사 사용자는 전체 사업소 표시
      _branchOptions = ['전체', '본사'];
      if (selectInfoProvider.branches.isNotEmpty) {
        _branchOptions.addAll(
          selectInfoProvider.branches
              .where((branch) => branch['name'] != '본사')
              .map((branch) => branch['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
        );
      }
    } else {
      // 본사가 아닌 사용자는 본사만 표시
      _branchOptions = ['본사'];
    }
  }

  void _onBranchChanged(String branch, bool? isChecked) {
    if (isChecked == null) return;

    List<String> newSelectedBranches = List.from(widget.selectedBranches);

    if (branch == '전체') {
      if (isChecked) {
        // 전체 선택 시 모든 사업소 선택
        newSelectedBranches = List.from(_branchOptions);
      } else {
        // 전체 해제 시 모든 사업소 해제
        newSelectedBranches.clear();
      }
    } else {
      if (isChecked) {
        // 개별 사업소 선택
        if (!newSelectedBranches.contains(branch)) {
          newSelectedBranches.add(branch);
        }
        // 개별 사업소 선택 시 전체도 선택
        if (!newSelectedBranches.contains('전체')) {
          newSelectedBranches.add('전체');
        }
      } else {
        // 개별 사업소 해제
        newSelectedBranches.remove(branch);
        // 개별 사업소가 하나라도 해제되면 전체도 해제
        newSelectedBranches.remove('전체');
      }
    }

    widget.onBranchesChanged(newSelectedBranches);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isHeadquarters = authProvider.appUser?.affiliation == '본사';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Row(
            children: [
              Text(
                '요청 대상 사업소',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          firstChild: Container(),
          secondChild: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _branchOptions.map((branch) {
              final isFixed = !isHeadquarters && branch == '본사';
              final isChecked = widget.selectedBranches.contains(branch) || isFixed;
              
              return SizedBox(
                width: 120,
                child: CheckboxListTile(
                  title: Text(
                    branch,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isFixed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  value: isChecked,
                  onChanged: isFixed ? null : (value) => _onBranchChanged(branch, value),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                ),
              );
            }).toList(),
          ),
          crossFadeState: _isExpanded 
              ? CrossFadeState.showSecond 
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
