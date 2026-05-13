import 'package:flutter/material.dart';

/// 에러/안내 메시지를 가운데 알림(Alert)으로 표시
Future<void> showMessageAlert(
  BuildContext context, {
  required String message,
  String title = '알림',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SelectableText(message),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
