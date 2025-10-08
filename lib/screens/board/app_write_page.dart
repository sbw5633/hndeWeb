import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../const_value.dart';
import '../../core/auth_provider.dart';
import '../../core/page_state_provider.dart';
import '../../core/select_info_provider.dart';
import '../../models/board_post_model.dart';
import '../../services/firebase/board_post_service.dart';
import '../../utils/dialog_utils.dart';
import '../../widgets/permission_guard.dart';
import 'components/write_page/form/post_editor_form.dart';
import 'components/write_page_app_Bar.dart';

class AppWritePage extends StatefulWidget {
  final MenuType type;
  const AppWritePage({super.key, required this.type});

  @override
  State<AppWritePage> createState() => _AppWritePageState();
}

class _AppWritePageState extends State<AppWritePage> {
  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final SelectInfoProvider selectInfoProvider = context.read<SelectInfoProvider>();

    return PermissionGuard(
      requiredPermission: widget.type,
      requireWritePermission: true,
      child: WillPopScope(
        onWillPop: () async {
          final pageStateProvider = context.read<PageStateProvider>();
          if (pageStateProvider.isEditing && pageStateProvider.hasUnsavedChanges) {
            final shouldPop = await DialogUtils.showExitConfirmationDialog(context);
            return shouldPop ?? false;
          }
          return true;
        },
        child: Scaffold(
          appBar: WritePageAppBar(type: widget.type.toString()),
          body: Padding(
            padding: const EdgeInsets.all(4.0),
            child: PostEditorForm(
              authProvider: authProvider,
              selectInfoProvider: selectInfoProvider,
              type: widget.type,
              onSubmit: (title, content, images, files, selectedBranch, extraData) async {
                await _submitForm(
                  title: title,
                  content: content,
                  images: images,
                  files: files,
                  selectedBranch: selectedBranch,
                  extraData: extraData,
                  type: widget.type,
                );
              },
              onFormReady: (submitCallback) {
                context.read<PageStateProvider>().setSubmitFormCallback(submitCallback);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm({
    required String title,
    required String content,
    required List<Map<String, String>> images,
    required List<Map<String, String>> files,
    required String selectedBranch,
    Map<String, dynamic>? extraData,
    required MenuType type,
  }) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.appUser;
      
      if (currentUser == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final boardPost = BoardPost(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // 임시 ID 생성
        title: title,
        content: content,
        authorId: currentUser.uid,
        authorName: currentUser.name,
        type: type,
        images: images,
        files: files,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        likes: 0,
        views: 0,
        anonymity: false,
        commentsCount: 0,
        extra: extraData ?? {},
        targetGroup: selectedBranch,
      );

      await BoardPostService.addBoardPost(boardPost);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('게시글이 성공적으로 등록되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 게시판 페이지로 이동
        String routePath;
        switch (type) {
          case MenuType.notice:
            routePath = '/notices';
            break;
          case MenuType.board:
            routePath = '/boards';
            break;
          case MenuType.anonymousBoard:
            routePath = '/anonymous-boards';
            break;
          case MenuType.dataRequest:
            routePath = '/data-requests';
            break;
          default:
            routePath = '/boards';
        }
        context.go(routePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('게시글 등록에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
