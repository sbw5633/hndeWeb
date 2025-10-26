import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/select_info_provider.dart';

class SearchFilterWidget extends StatefulWidget {
  final String searchHint;
  final Function(String) onSearchChanged;
  final Function(String) onBranchChanged;
  final String initialSearchQuery;
  final String initialSelectedBranch;
  final Color backgroundColor;
  final bool showBranchFilter;

  const SearchFilterWidget({
    super.key,
    this.searchHint = '제목으로 검색...',
    required this.onSearchChanged,
    required this.onBranchChanged,
    this.initialSearchQuery = '',
    this.initialSelectedBranch = '모든 사업소',
    this.showBranchFilter = true,
    this.backgroundColor = const Color(0xFFD0E8F2),
  });

  @override
  State<SearchFilterWidget> createState() => _SearchFilterWidgetState();
}

class _SearchFilterWidgetState extends State<SearchFilterWidget> {
  late String _searchQuery;
  late String _selectedBranch;
  List<String> _branchOptions = ['전체'];

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery;
    _selectedBranch = widget.initialSelectedBranch;
  }

  // 필터(사업소) 옵션 로드
  Future<void> _loadBranchOptions() async {
    final selectInfoProvider = context.read<SelectInfoProvider>();
    if (selectInfoProvider.loaded) {
      setState(() {
        _branchOptions = [
          '모든 사업소',
          '전체',
          ...selectInfoProvider.branches
              .map((branch) => branch['name'] as String)
        ];
      });
    } else {
      await selectInfoProvider.loadAll().then((_) {
        setState(() {
          _branchOptions = [
            '모든 사업소',
            '전체',
            ...selectInfoProvider.branches
                .map((branch) => branch['name'] as String)
          ];
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadBranchOptions(), // 필터 로드
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (asyncSnapshot.hasError) {
          return Center(child: Text('Error: ${asyncSnapshot.error}'));
        }
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 검색바 (가능한 영역 모두 차지)
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                              widget.onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    widget.onSearchChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 12.0),
              // 사업소 필터 (사업소명 길이에 맞춤)
              if (widget.showBranchFilter)
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '사업소: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14.0,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedBranch,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                          ),
                          items: _branchOptions.map((branch) {
                            return DropdownMenuItem<String>(
                              value: branch,
                              child: Text(
                                branch,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBranch = value!;
                            });
                            widget.onBranchChanged(value!);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }
    );
  }
}
