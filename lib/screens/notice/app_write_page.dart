import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hnde_web/core/select_info_provider.dart';
import 'package:provider/provider.dart';
import '../../const_value.dart';
import '../../core/auth_provider.dart';
import '../../core/loading_provider.dart';
import '../../core/page_state_provider.dart';
import '../../models/board_post_model.dart';
import '../../services/firebase/board_post_service.dart';
import '../components/common/post_editor_form.dart';
import '../../utils/dialog_utils.dart';

import 'package:uuid/uuid.dart';

class AppWritePage extends StatefulWidget {
  final MenuType type;
  const AppWritePage({super.key, required this.type});

  @override
  State<AppWritePage> createState() => _AppWritePageState();
}

class _AppWritePageState extends State<AppWritePage> {
  // PostEditorForm의 submitForm 메서드에 접근하기 위한 콜백
  VoidCallback? _submitFormCallback;

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final SelectInfoProvider selectInfoProvider =
        context.read<SelectInfoProvider>();

    return WillPopScope(
      onWillPop: () async {
        final pageStateProvider = context.read<PageStateProvider>();
        if (pageStateProvider.isEditing &&
            pageStateProvider.hasUnsavedChanges) {
          final shouldPop =
              await DialogUtils.showExitConfirmationDialog(context);
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.type.label} 작성'),
          actions: [
            // 등록 버튼 - 입력된 내용이 있을 때만 활성화
            Consumer<PageStateProvider>(
              builder: (context, pageState, child) {
                final hasContent = pageState.hasUnsavedChanges;
                return TextButton(
                  onPressed: hasContent
                      ? () {
                          // PostEditorForm의 submitForm 메서드 호출
                          _submitFormCallback?.call();
                        }
                      : null, // 입력된 내용이 없으면 비활성화
                  child: Text(
                    '등록',
                    style: TextStyle(
                      color: hasContent ? Colors.white : Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: PostEditorForm(
            authProvider: authProvider,
            selectInfoProvider: selectInfoProvider,
            type: widget.type,
            onSubmit: (title, content, images, files, selectedBranch) async {
              // 제출 실행
              await _submitForm(
                title: title,
                content: content,
                images: images,
                files: files,
                selectedBranch: selectedBranch,
                type: widget.type,
              );
            },
            onFormReady: (submitCallback) {
              // PostEditorForm이 준비되면 submitForm 콜백 저장
              _submitFormCallback = submitCallback;
            },
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm(
      {required String title,
      required String content,
      List<Map<String, String>>? images,
      List<Map<String, String>>? files,
      String? selectedBranch,
      required MenuType type}) async {
    context.read<LoadingProvider>().setLoading(true, text: '등록 중...');
    try {
      // Firestore에서 사용할 새 ID 생성
      final newId = const Uuid().v4();
      final now = DateTime.now();

      // 로그인한 유저 정보 가져오기
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.appUser;
      final firebaseUser = authProvider.firebaseUser;

      final post = BoardPost(
        id: newId,
        type: type.name,
        title: title,
        content: content,
        authorId: firebaseUser?.uid ?? currentUser?.uid ?? 'unknown',
        authorName: currentUser?.name ?? firebaseUser?.displayName ?? '관리자',
        anonymity: type == MenuType.anonymousBoard ? true : false,  // 익명게시판일 경우 익명으로 설정. 게시물 불러올때 익명 여부에 따라 처리
        createdAt: now,
        updatedAt: now,
        images: images ?? [],
        files: files ?? [],
        views: 0,
        likes: 0,
        commentsCount: 0,
        extra: {},
        targetGroup: selectedBranch ?? '전체',
      );
      await BoardPostService.addBoardPost(post);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.label} 등록 완료!')),
        );
        context.go(type.route);

        // Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.label} 등록 실패: \n$e')),
        );
      }
    } finally {
      context.read<LoadingProvider>().setLoading(false);
    }
  }
}
