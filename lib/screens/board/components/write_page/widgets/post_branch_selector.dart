import 'package:flutter/material.dart';

class PostBranchSelector extends StatelessWidget {
  final List<Map<String, String>> branchOptions;
  final String? selectedBranch;
  final Function(String?) onBranchChanged;
  final String autoBranch;

  const PostBranchSelector({
    super.key,
    required this.branchOptions,
    required this.selectedBranch,
    required this.onBranchChanged,
    required this.autoBranch,
  });

  @override
  Widget build(BuildContext context) {
    return branchOptions.isNotEmpty
        ? Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IntrinsicWidth(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '사업소'),
                  value: selectedBranch,
                  items: branchOptions
                      .map<DropdownMenuItem<String>>(
                          (b) => DropdownMenuItem<String>(
                                value: b['name'],
                                child: Text(b['name'] ?? ''),
                              ))
                      .toList(),
                  onChanged: onBranchChanged,
                  validator: (value) => value == null ? '사업소를 선택하세요.' : null,
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(autoBranch,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          );
  }
}
