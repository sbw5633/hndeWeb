import 'package:flutter/material.dart';

class PostTitleField extends StatelessWidget {
  final TextEditingController controller;
  final Function(bool) onContentChanged;

  const PostTitleField({
    super.key,
    required this.controller,
    required this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(labelText: '제목'),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? '제목을 입력하세요.' : null,
      onChanged: (_) {
        onContentChanged(true);
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}
