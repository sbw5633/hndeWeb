import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/loading_provider.dart';
import '../../models/board_post_model.dart';
import '../../services/firebase/board_post_service.dart';
import '../components/common/post_editor_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

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
          onSubmit: (title, content, images, files) async {
            context.read<LoadingProvider>().setLoading(true, text: '공지사항 등록 중...');
            try {
              // Firestore에서 사용할 새 ID 생성
              final newId = const Uuid().v4();
              final now = DateTime.now();
              final post = BoardPost(
                id: newId,
                type: 'notice',
                title: title,
                content: content,
                authorId: 'admin', // TODO: 실제 로그인 유저 정보로 대체
                authorName: '관리자', // TODO: 실제 로그인 유저 정보로 대체
                anonymity: false,
                createdAt: now,
                updatedAt: now,
                images: images,
                files: files,
                views: 0,
                likes: 0,
                commentsCount: 0,
                extra: {},
                targetGroup: BusinessLocation.all, // TODO: UI에서 선택하도록 수정 필요
              );
              await BoardPostService.addBoardPost(post);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('공지 등록 완료!')),
                );
                Navigator.of(context).pop();
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('등록 실패: \n$e')),
                );
              }
            } finally {
              context.read<LoadingProvider>().setLoading(false);
            }
          },
        ),
      ),
    );
  }
} 