import 'package:flutter/material.dart';

class PostBranchSelector extends StatelessWidget {
  final List<Map<String, String>> branchOptions;
  final String? selectedBranch;
  final String autoBranch;
  final Function(String?) onBranchChanged;
  final VoidCallback onContentChanged;

  const PostBranchSelector({
    super.key,
    required this.branchOptions,
    required this.selectedBranch,
    required this.autoBranch,
    required this.onBranchChanged,
    required this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return branchOptions.isNotEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.business,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '대상 사업소',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: '사업소를 선택하세요',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                value: selectedBranch,
                items: branchOptions
                    .map<DropdownMenuItem<String>>(
                        (b) => DropdownMenuItem<String>(
                              value: b['name'],
                              child: Text(b['name'] ?? ''),
                            ))
                    .toList(),
                onChanged: (value) {
                  onBranchChanged(value);
                  onContentChanged();
                },
                validator: (value) => value == null ? '사업소를 선택하세요.' : null,
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.business,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '대상 사업소',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      autoBranch,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}
