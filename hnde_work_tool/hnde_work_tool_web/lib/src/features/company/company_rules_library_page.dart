import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import '../../constants/super_admin.dart';
import '../../models/company_rule_file_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../common/loading_widget.dart';
import '../common/merged_user_profile_stream_builder.dart';
import 'company_info_back_bar.dart';

/// 사규집: 규정·지침 파일명 목록 → 탭 시 본문 전체 PDF 뷰어
class CompanyRulesPage extends StatefulWidget {
  const CompanyRulesPage({super.key});

  @override
  State<CompanyRulesPage> createState() => _CompanyRulesPageState();
}

class _CompanyRulesPageState extends State<CompanyRulesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _appliedQuery = '';
  String? _openFileId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    setState(() {
      _appliedQuery = _searchController.text.trim();
    });
  }

  List<CompanyRuleFileModel> _filter(List<CompanyRuleFileModel> list) {
    final String q = _appliedQuery.toLowerCase();
    if (q.isEmpty) {
      return list;
    }
    return list
        .where((CompanyRuleFileModel e) =>
            e.fileName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _pickAndUpload(
    BuildContext context,
    WorkFirestoreRepository repo,
    String category,
  ) async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LoadingWidget(
                size: 88,
                duration: const Duration(seconds: 3),
                text: '업로드 중…',
                textStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 32));
    if (!context.mounted) {
      return;
    }
    try {
      for (final PlatformFile f in picked.files) {
        await repo.addCompanyRuleFile(category: category, file: f);
      }
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${category == 'regulation' ? '규정' : '지침'} PDF '
              '${picked.files.length}건 반영',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    }
  }

  CompanyRuleFileModel? _resolveOpen(List<CompanyRuleFileModel> all) {
    if (_openFileId == null) {
      return null;
    }
    for (final CompanyRuleFileModel e in all) {
      if (e.id == _openFileId) {
        return e;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    final WorkFirestoreRepository repo = context.read<WorkFirestoreRepository>();

    return MergedUserProfileStreamBuilder(
      uid: user.uid,
      builder: (
        BuildContext context,
        Map<String, dynamic> pd,
        bool streamsWaiting,
      ) {
        final bool mainAdmin = SuperAdmin.effectiveMainAdmin(
          profileMainAdmin: pd['mainAdmin'],
          profileEmail: pd['email'] as String?,
          authEmail: user.email,
          roleIdx: (pd['roleIdx'] as num?)?.toInt(),
        );

        return StreamBuilder<List<CompanyRuleFileModel>>(
          stream: repo.watchCompanyRuleFiles(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<CompanyRuleFileModel>> listSnap,
          ) {
            final List<CompanyRuleFileModel> all =
                listSnap.data ?? <CompanyRuleFileModel>[];
            final List<CompanyRuleFileModel> regulations = _filter(
              all
                  .where((CompanyRuleFileModel e) =>
                      e.category == 'regulation')
                  .toList(),
            );
            final List<CompanyRuleFileModel> guidelines = _filter(
              all
                  .where((CompanyRuleFileModel e) =>
                      e.category == 'guideline')
                  .toList(),
            );

            final CompanyRuleFileModel? openResolved = _resolveOpen(all);
            if (_openFileId != null && openResolved == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _openFileId = null);
                }
              });
            }

            if (openResolved != null) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (bool didPop, Object? result) {
                  if (didPop) {
                    return;
                  }
                  setState(() => _openFileId = null);
                },
                child: Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: '사규집 목록',
                      onPressed: () => setState(() => _openFileId = null),
                    ),
                    title: Text(
                      openResolved.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  body: _CompanyRulePdfViewer(
                    key: ValueKey<String>(openResolved.id),
                    item: openResolved,
                    repo: repo,
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('사규집'),
                actions: <Widget>[
                  if (mainAdmin)
                    PopupMenuButton<String>(
                      tooltip: 'PDF 업로드',
                      child: const Icon(Icons.upload_file_outlined),
                      onSelected: (String value) {
                        _pickAndUpload(context, repo, value);
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'regulation',
                          child: ListTile(
                            leading: Icon(Icons.gavel_outlined),
                            title: Text('규정 PDF 업로드'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'guideline',
                          child: ListTile(
                            leading: Icon(Icons.menu_book_outlined),
                            title: Text('지침 PDF 업로드'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: CompanyInfoBackBar(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: '파일명 검색',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _applySearch(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _applySearch,
                          icon: const Icon(Icons.search),
                          tooltip: '검색',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (
                        BuildContext context,
                        BoxConstraints constraints,
                      ) {
                        final bool stackVertical =
                            constraints.maxWidth < 720;
                        final Widget left = _RulesColumn(
                          label: '규정',
                          files: regulations,
                          mainAdmin: mainAdmin,
                          onOpen: (String id) =>
                              setState(() => _openFileId = id),
                          onDelete: (CompanyRuleFileModel e) =>
                              _confirmDelete(context, repo, e),
                        );
                        final Widget right = _RulesColumn(
                          label: '지침',
                          files: guidelines,
                          mainAdmin: mainAdmin,
                          onOpen: (String id) =>
                              setState(() => _openFileId = id),
                          onDelete: (CompanyRuleFileModel e) =>
                              _confirmDelete(context, repo, e),
                        );
                        if (stackVertical) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(child: left),
                              const Divider(height: 1),
                              Expanded(child: right),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(child: left),
                            const VerticalDivider(width: 1),
                            Expanded(child: right),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WorkFirestoreRepository repo,
    CompanyRuleFileModel item,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('「${item.fileName}」을(를) 삭제할까요?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      await repo.deleteCompanyRuleFile(item);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제했습니다.')),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }
}

class _RulesColumn extends StatelessWidget {
  const _RulesColumn({
    required this.label,
    required this.files,
    required this.mainAdmin,
    required this.onOpen,
    required this.onDelete,
  });

  final String label;
  final List<CompanyRuleFileModel> files;
  final bool mainAdmin;
  final void Function(String id) onOpen;
  final void Function(CompanyRuleFileModel e) onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Expanded(
          child: files.isEmpty
              ? Center(
                  child: Text(
                    '등록된 파일이 없습니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) {
                    final CompanyRuleFileModel e = files[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      title: Text(
                        e.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: mainAdmin
                          ? IconButton(
                              tooltip: '삭제',
                              icon: const Icon(Icons.delete_outline, size: 22),
                              onPressed: () => onDelete(e),
                            )
                          : null,
                      onTap: () => onOpen(e.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 목록에서 연 전체 영역 PDF
class _CompanyRulePdfViewer extends StatefulWidget {
  const _CompanyRulePdfViewer({
    super.key,
    required this.item,
    required this.repo,
  });

  final CompanyRuleFileModel item;
  final WorkFirestoreRepository repo;

  @override
  State<_CompanyRulePdfViewer> createState() => _CompanyRulePdfViewerState();
}

class _CompanyRulePdfViewerState extends State<_CompanyRulePdfViewer> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CompanyRulePdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _controller?.dispose();
      _controller = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final String signed = await widget.repo.getPresignedDownloadUrl(
        widget.item.fileUrl,
        fileKey: widget.item.r2Key,
        fileName: widget.item.fileName,
      );
      final http.Response res = await http
          .get(Uri.parse(signed))
          .timeout(const Duration(minutes: 3));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('다운로드 실패 (${res.statusCode})');
      }
      final Uint8List bytes = res.bodyBytes;
      if (!mounted) {
        return;
      }
      _controller?.dispose();
      _controller = PdfControllerPinch(
        document: PdfDocument.openData(Future<Uint8List>.value(bytes)),
      );
      setState(() {
        _loading = false;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: LoadingWidget(
          size: 88,
          duration: const Duration(seconds: 3),
          text: 'PDF 불러오는 중…',
          textStyle: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'PDF를 열 수 없습니다.\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final PdfControllerPinch? c = _controller;
    if (c == null) {
      return const SizedBox.expand();
    }
    return PdfViewPinch(controller: c);
  }
}
