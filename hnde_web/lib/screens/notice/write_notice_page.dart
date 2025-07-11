import 'package:flutter/material.dart';
import '../components/common/post_editor_form.dart';

class WriteNoticePage extends StatelessWidget {
  const WriteNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지사항 작성')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: PostEditorForm(
          type: 'notice',
          onSubmit: (title, content, images, files) {
            // TODO: Firestore/Storage 연동
            print('공지 등록: $title, $content, ${images.length}개 이미지, ${files.length}개 파일');
          },
        ),
      ),
    );
  }
} 