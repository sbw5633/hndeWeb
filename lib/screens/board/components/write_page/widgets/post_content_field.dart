import 'package:flutter/material.dart';

class PostContentField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onContentChanged;

  const PostContentField({
    super.key,
    required this.controller,
    required this.onContentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(labelText: '내용'),
      maxLines: 8,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? '내용을 입력하세요.' : null,
      onChanged: (_) => onContentChanged(),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}
