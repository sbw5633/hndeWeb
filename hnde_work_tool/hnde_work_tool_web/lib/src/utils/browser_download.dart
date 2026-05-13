// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 웹: [bytes]를 [fileName]으로 브라우저 다운로드.
void downloadBytesInBrowser(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
}) {
  if (!kIsWeb) {
    return;
  }
  final html.Blob blob = mimeType != null && mimeType.isNotEmpty
      ? html.Blob(<dynamic>[bytes], mimeType)
      : html.Blob(<dynamic>[bytes]);
  final String url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
