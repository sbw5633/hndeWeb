import 'package:flutter/material.dart';

class DataRequestBranchSelector extends StatefulWidget {
  final List<Map<String, String>> branchOptions;
  final List<String> selectedBranches;
  final Function(List<String>) onBranchesChanged;
  final Function() onContentChanged;

  const DataRequestBranchSelector({
    super.key,
    required this.branchOptions,
    required this.selectedBranches,
    required this.onBranchesChanged,
    required this.onContentChanged,
  });

  @override
  State<DataRequestBranchSelector> createState() => _DataRequestBranchSelectorState();
}

class _DataRequestBranchSelectorState extends State<DataRequestBranchSelector> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onContentChanged();
  }

  void _toggleAllBranches() {
    final actualBranchNames = widget.branchOptions
        .where((branch) => branch['id'] != '전체')
        .map((branch) => branch['name']!)
        .toList();
    final isAllSelected = actualBranchNames.isNotEmpty && 
                         actualBranchNames.every((name) => widget.selectedBranches.contains(name));
    
    if (isAllSelected) {
      // 모든 선택 해제
      widget.onBranchesChanged([]);
    } else {
      // 모든 선택 (전체 제외)
      widget.onBranchesChanged(actualBranchNames);
    }
    widget.onContentChanged();
  }

  void _toggleBranch(String branchName) {
    final newSelectedBranches = List<String>.from(widget.selectedBranches);
    
    if (newSelectedBranches.contains(branchName)) {
      newSelectedBranches.remove(branchName);
    } else {
      newSelectedBranches.add(branchName);
    }
    
    widget.onBranchesChanged(newSelectedBranches);
    widget.onContentChanged();
  }

  @override
  Widget build(BuildContext context) {
    final actualBranchNames = widget.branchOptions
        .where((branch) => branch['id'] != '전체')
        .map((branch) => branch['name']!)
        .toList();
    final isAllSelected = actualBranchNames.isNotEmpty && 
                         actualBranchNames.every((name) => widget.selectedBranches.contains(name));
    final isPartiallySelected = widget.selectedBranches.isNotEmpty && !isAllSelected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Icon(
              Icons.business,
              color: Colors.blue.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '요청사업소',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // 선택기 헤더 (클릭 가능)
        InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.checklist,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.selectedBranches.isEmpty 
                        ? '요청할 사업소를 선택하세요'
                        : '${widget.selectedBranches.length}개 사업소 선택됨',
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.selectedBranches.isEmpty 
                          ? Colors.grey.shade500 
                          : Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        
        // 확장 가능한 내용
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 전체 선택/해제 버튼
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: _toggleAllBranches,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isAllSelected 
                              ? Colors.blue.shade50 
                              : isPartiallySelected 
                                  ? Colors.orange.shade50 
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAllSelected 
                                ? Colors.blue.shade300 
                                : isPartiallySelected 
                                    ? Colors.orange.shade300 
                                    : Colors.grey.shade300,
                          ),
                        ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAllSelected 
                                ? Icons.check_box 
                                : isPartiallySelected 
                                    ? Icons.indeterminate_check_box 
                                    : Icons.check_box_outline_blank,
                            color: isAllSelected 
                                ? Colors.blue.shade600 
                                : isPartiallySelected 
                                    ? Colors.orange.shade600 
                                    : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '전체',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isAllSelected 
                                  ? Colors.blue.shade700 
                                  : isPartiallySelected 
                                      ? Colors.orange.shade700 
                                      : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 사업소 목록 (2-3열 그리드)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 3.5,
                      ),
                      itemCount: widget.branchOptions.where((branch) => branch['id'] != '전체').length,
                      itemBuilder: (context, index) {
                        final filteredBranches = widget.branchOptions.where((branch) => branch['id'] != '전체').toList();
                        final branch = filteredBranches[index];
                        final branchName = branch['name']!;
                        final isSelected = widget.selectedBranches.contains(branchName);
                        
                        return InkWell(
                          onTap: () => _toggleBranch(branchName),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                  color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    branchName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
