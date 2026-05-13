import 'package:flutter/material.dart';

import '../../../models/todo_item_model.dart';

const Color _navy = Color(0xFF1E3A8A);

/// 투두 목록 행 — 캘린더 연동·기간 표시 공통
class TodoTaskRow extends StatelessWidget {
  const TodoTaskRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
    this.selected = false,
    this.onTap,
  });

  final TodoItemModel item;
  final void Function(bool value) onToggle;
  final VoidCallback onDelete;
  final bool selected;
  final VoidCallback? onTap;

  static String? _periodHint(TodoItemModel item) {
    if (item.type != TodoTypes.calendar) {
      return null;
    }
    if (item.dateKeys.length <= 1) {
      return null;
    }
    return '${item.dateKeys.first} ~ ${item.dateKeys.last} (${item.dateKeys.length}일)';
  }

  @override
  Widget build(BuildContext context) {
    final bool cal = item.type == TodoTypes.calendar;
    final String? period = _periodHint(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: item.completed
            ? const Color(0xFFF8FAFC)
            : (selected ? const Color(0xFFEFF6FF) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? _navy
                    : (item.completed
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0)),
                width: selected ? 2 : 2,
              ),
              boxShadow: item.completed
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Checkbox(
                      value: item.completed,
                      onChanged: (bool? v) {
                        if (v != null) {
                          onToggle(v);
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.grey.shade400, width: 2),
                      activeColor: _navy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (cal)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.link_rounded, size: 11, color: _navy),
                                const SizedBox(width: 4),
                                Text(
                                  '캘린더 연동',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _navy,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: item.completed
                                ? Colors.grey.shade400
                                : const Color(0xFF0F172A),
                            decoration: item.completed
                                ? TextDecoration.lineThrough
                                : null,
                            height: 1.2,
                          ),
                        ),
                        if (period != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            period,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: item.completed
                                  ? Colors.grey.shade300
                                  : Colors.orange.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '마감 ',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              item.timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: item.completed
                                    ? Colors.grey.shade400
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.grey.shade400, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
