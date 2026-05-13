import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../repositories/work_firestore_repository.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import '../common/message_alert.dart';

const int _kTitleMax = 50;
const int _kBodyMax = 3000;
const int _kImageMax = 5;

const Color _navy = Color(0xFF1E3A8A);

/// 전체 화면 게시글 작성 (공지/자유/익명 공통 레이아웃)
///
/// 이미지: 로컬에만 두었다가 [등록] 시 Cloudflare Worker `POST /v1/upload`(R2)로 업로드.
class BoardComposePage extends StatefulWidget {
  const BoardComposePage({
    required this.boardType,
    super.key,
  });

  final String boardType;

  static String listTitleFor(String boardType) {
    switch (boardType) {
      case 'notice':
        return '전사 공지사항';
      case 'freeboard':
        return '자유게시판';
      case 'anonymous':
        return '익명게시판';
      default:
        return '게시판';
    }
  }

  @override
  State<BoardComposePage> createState() => _BoardComposePageState();
}

class _BoardComposePageState extends State<BoardComposePage> {
  late final WorkFirestoreRepository _repo;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  bool _official = false;
  bool _submitting = false;
  /// 등록 전까지 로컬 파일만 보관 (네트워크 업로드 없음)
  final List<PlatformFile> _localImages = <PlatformFile>[];
  String _submitStatusLine = '';

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    _bodyCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _isNotice => widget.boardType == 'notice';
  bool get _isAnonymous => widget.boardType == 'anonymous';

  Future<void> _pickImages() async {
    final int remaining = _kImageMax - _localImages.length;
    if (remaining <= 0) {
      return;
    }
    try {
      final FilePickerResult? r = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (r == null || r.files.isEmpty) {
        return;
      }
      final List<PlatformFile> picked = r.files;
      final int toTake = picked.length > remaining ? remaining : picked.length;
      if (picked.length > remaining && mounted) {
        await showMessageAlert(
          context,
          title: '첨부 제한',
          message:
              '이미지는 최대 $_kImageMax장까지 첨부됩니다. 선택한 이미지 중 처음 ${toTake}장만 추가했습니다.',
        );
      }
      final List<PlatformFile> slice = picked.sublist(0, toTake);
      setState(() {
        for (final PlatformFile f in slice) {
          if (_localImages.length >= _kImageMax) {
            break;
          }
          _localImages.add(f);
        }
      });
    } catch (e) {
      if (mounted) {
        showMessageAlert(context, message: '파일 선택 실패: $e', title: '오류');
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _localImages.removeAt(index));
  }

  Widget _previewTile(int index) {
    final PlatformFile f = _localImages[index];
    final Uint8List? bytes = f.bytes;
    return Stack(
      alignment: Alignment.topRight,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: bytes != null && bytes.isNotEmpty
              ? Image.memory(
                  bytes,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: Icon(Icons.image_outlined, color: Colors.grey.shade500),
                ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _removeImage(index),
          icon: const Icon(Icons.close, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    final String title = _titleCtrl.text.trim();
    final String body = _bodyCtrl.text.trim();
    if (title.isEmpty) {
      showMessageAlert(context, message: '제목을 입력하세요.', title: '입력');
      return;
    }
    if (body.isEmpty) {
      showMessageAlert(context, message: '내용을 입력하세요.', title: '입력');
      return;
    }

    setState(() {
      _submitting = true;
      _submitStatusLine = _localImages.isEmpty ? '등록 중…' : '이미지 업로드 0/${_localImages.length}';
    });

    try {
      final List<String> imageUrls = <String>[];
      for (int i = 0; i < _localImages.length; i++) {
        if (mounted) {
          setState(() {
            _submitStatusLine = '이미지 업로드 ${i + 1}/${_localImages.length}';
          });
        }
        final String url = await _repo.uploadBoardImage(_localImages[i]);
        imageUrls.add(url);
      }
      if (mounted) {
        setState(() => _submitStatusLine = '게시글 저장 중…');
      }
      final String id = await _repo.createPost(
        boardType: widget.boardType,
        title: title,
        body: body,
        imageUrls: imageUrls,
        isOfficial: _isNotice && _official,
        anonymous: _isAnonymous,
      );
      if (!context.mounted) {
        return;
      }
      context.go('/board/${widget.boardType}/$id');
    } catch (e) {
      if (context.mounted) {
        showMessageAlert(context, message: '등록 실패: $e', title: '등록 실패');
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitStatusLine = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _submitting,
      loadingText: _submitStatusLine.isEmpty ? '처리 중…' : _submitStatusLine,
      child: EnterpriseScaffold(
        title: '글쓰기',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: '목록으로',
                  onPressed: _submitting
                      ? null
                      : () => context.go(_listPath(widget.boardType)),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${BoardComposePage.listTitleFor(widget.boardType)} · 글쓰기',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _navy,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('등록'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _titleCtrl,
                        maxLength: _kTitleMax,
                        maxLines: 1,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(_kTitleMax),
                        ],
                        decoration: const InputDecoration(
                          labelText: '제목',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bodyCtrl,
                        maxLength: _kBodyMax,
                        minLines: 12,
                        maxLines: 24,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(_kBodyMax),
                        ],
                        decoration: const InputDecoration(
                          labelText: '내용',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_bodyCtrl.text.length}/$_kBodyMax',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (_isNotice) ...<Widget>[
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _official,
                          onChanged: (bool? v) =>
                              setState(() => _official = v ?? false),
                          title: const Text('중요공지'),
                          subtitle: const Text(
                            '목록에서 중요 표시로 강조됩니다.',
                            style: TextStyle(fontSize: 12),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        '이미지 첨부 (최대 $_kImageMax장, 등록 시 업로드)',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          for (int i = 0; i < _localImages.length; i++)
                            _previewTile(i),
                          if (_localImages.length < _kImageMax)
                            OutlinedButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                              label: const Text('이미지 추가'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _listPath(String boardType) {
    switch (boardType) {
      case 'notice':
        return '/notice';
      case 'freeboard':
        return '/freeboard';
      case 'anonymous':
        return '/anonymous';
      default:
        return '/';
    }
  }
}
