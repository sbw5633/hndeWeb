// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/role_constants.dart';
import '../../constants/super_admin.dart';
import '../../models/submission_model.dart';
import '../../models/submission_site_model.dart';
import '../../repositories/work_firestore_repository.dart';
import '../common/enterprise_scaffold.dart';
import '../common/message_alert.dart';

String _downloadFailureMessage(int statusCode, String body) {
  final String t = body.trim();
  String? errCode;
  if (t.startsWith('{')) {
    try {
      final Object? decoded = jsonDecode(t);
      if (decoded is Map<String, dynamic>) {
        errCode = decoded['error'] as String?;
      }
    } catch (_) {}
  }
  if (errCode == 'not_found') {
    return '파일을 찾을 수 없습니다. txt 등 확장자 때문이 아니라, '
        '저장소에 해당 객체가 없거나(삭제·이전 업로드), 주소에 적힌 키가 실제와 다를 때 '
        '발생합니다. 새로 제출한 파일은 다시 시도하고, 예전 건은 재제출이 필요할 수 있습니다.';
  }
  if (errCode == 'bad_sig') {
    return '다운로드 링크 서명이 맞지 않습니다. 다시 다운로드 버튼을 눌러 주세요.';
  }
  if (errCode == 'expired') {
    return '다운로드 링크 유효 시간이 지났습니다. 다시 다운로드 버튼을 눌러 주세요.';
  }
  if (errCode != null && errCode.isNotEmpty) {
    return '다운로드 실패 ($statusCode): $errCode';
  }
  final String short = t.length > 200 ? '${t.substring(0, 200)}…' : t;
  return short.isEmpty
      ? '다운로드 실패 (HTTP $statusCode)'
      : '다운로드 실패 ($statusCode): $short';
}

/// 서명 URL로 파일을 받아 브라우저에서 저장. 실패 시 예외 (조용히 새 창 열지 않음).
Future<void> _downloadSignedUrlInBrowser(String url, String fileName) async {
  late http.Response res;
  try {
    res = await http.get(Uri.parse(url));
  } catch (e) {
    throw Exception('다운로드 요청 실패: $e');
  }
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception(_downloadFailureMessage(res.statusCode, res.body));
  }
  final html.Blob blob = html.Blob(<Object>[res.bodyBytes]);
  final String objUrl = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: objUrl)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(objUrl);
}

String _effectiveBranchFromProfile(Map<String, dynamic>? prof) {
  if (prof == null) return '';
  final String? bn = (prof['branchName'] as String?)?.trim();
  if (bn != null && bn.isNotEmpty) return bn;
  final String? br = (prof['branch'] as String?)?.trim();
  return br ?? '';
}

bool _siteMatchesUserBranch(SubmissionSiteModel s, String branch) {
  if (branch.isEmpty) return false;
  return s.id == branch || s.label == branch;
}

/// sites 컬렉션 문서 id (프로필 문자열이 label과만 일치할 때도 실제 id 반환)
String? _siteDocIdForBranch(
  List<SubmissionSiteModel> sites,
  String branch,
) {
  for (final SubmissionSiteModel s in sites) {
    if (_siteMatchesUserBranch(s, branch)) return s.id;
  }
  return null;
}

Future<void> _showRerequestCommentDialog(
  BuildContext context, {
  required String submissionId,
  required String siteDocId,
  required WorkFirestoreRepository repo,
}) async {
  final TextEditingController ctrl = TextEditingController();
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('재요청'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '메시지',
          hintText: '보완 요청 내용을 입력하세요',
          border: OutlineInputBorder(),
        ),
        maxLines: 4,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: const Text('보내기'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (!context.mounted) return;
  if (result == null) return;
  try {
    await repo.setSubmissionSiteStatus(
      submissionId: submissionId,
      siteDocId: siteDocId,
      status: 're_requested',
      reRequestComment: result.isEmpty ? null : result,
    );
  } catch (e) {
    if (context.mounted) {
      showMessageAlert(context, message: '$e', title: '재요청 실패');
    }
  }
}

class ExchangeDetailPage extends StatefulWidget {
  const ExchangeDetailPage({required this.submissionId, super.key});

  final String submissionId;

  @override
  State<ExchangeDetailPage> createState() => _ExchangeDetailPageState();
}

class _ExchangeDetailPageState extends State<ExchangeDetailPage> {
  late final WorkFirestoreRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = context.read<WorkFirestoreRepository>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _repo.ensureDefaultSubmissionSites(widget.submissionId);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestorePaths.submissionsCol()
          .doc(widget.submissionId)
          .snapshots(),
      builder: (BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return EnterpriseScaffold(
            title: '자료송수신',
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('문서를 찾을 수 없습니다.'),
                  TextButton(
                    onPressed: () => context.go('/exchange'),
                    child: const Text('목록으로'),
                  ),
                ],
              ),
            ),
          );
        }
        final SubmissionModel sub = SubmissionModel.fromDoc(snap.data!);

        final User? user = FirebaseAuth.instance.currentUser;
        final DocumentReference<Map<String, dynamic>>? profileRef =
            user == null ? null : FirestorePaths.userProfileMainDoc(user.uid);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: profileRef?.snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> profSnap,
          ) {
            final String? uid = user?.uid;
            final Map<String, dynamic>? prof =
                profSnap.data?.data();
            /// 프로필: branchName 우선, 없으면 branch
            final String effectiveBranch = _effectiveBranchFromProfile(prof);
            final int roleIdx =
                (prof?['roleIdx'] as num?)?.toInt() ??
                    RoleConstants.unspecified;
            /// 요청 작성자(요청처)
            final bool isRequesterViewer = uid != null &&
                sub.createdByUid.isNotEmpty &&
                uid == sub.createdByUid;
            /// 과거 문서(createdByUid 없음): 메인/인사관리자만 수신 현황
            /// (hqViewerMode는 가입 시 기본 true라 분기가 깨짐 — 사용하지 않음)
            final bool isRequesterViewerLegacy = uid != null &&
                sub.createdByUid.isEmpty &&
                (SuperAdmin.effectiveMainAdmin(
                      profileMainAdmin: prof?['mainAdmin'],
                      profileEmail: prof?['email'] as String?,
                      authEmail: user?.email,
                      roleIdx: roleIdx,
                    ) ||
                    RoleConstants.canViewAllBranches(roleIdx));
            final bool showRequesterPanel =
                isRequesterViewer || isRequesterViewerLegacy;

            if (profileRef != null &&
                profSnap.connectionState == ConnectionState.waiting &&
                !profSnap.hasData) {
              return EnterpriseScaffold(
                title: '자료송수신',
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            return EnterpriseScaffold(
              title: '자료송수신',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => context.go('/exchange'),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('목록으로'),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(32),
                            color: const Color(0xFF1E3A8A),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  sub.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  sub.description.isEmpty
                                      ? '설명 없음'
                                      : sub.description,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  if (sub.templateFileName != null &&
                                      sub.templateDownloadUrl != null)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.description,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                      title: Text(sub.templateFileName!),
                                      subtitle: const Text('양식 파일'),
                                      trailing: OutlinedButton(
                                        onPressed: () async {
                                          try {
                                            final String url = await _repo
                                                .getPresignedDownloadUrl(
                                              sub.templateDownloadUrl!,
                                              fileKey: sub.templateR2Key,
                                              fileName: sub.templateFileName,
                                            );
                                            await _downloadSignedUrlInBrowser(
                                              url,
                                              sub.templateFileName ?? 'download',
                                            );
                                          } catch (e) {
                                            if (context.mounted) {
                                              showMessageAlert(context,
                                                  message: '$e',
                                                  title: '다운로드 실패');
                                            }
                                          }
                                        },
                                        child: const Text('다운로드'),
                                      ),
                                    ),
                                  const Divider(height: 32),
                                  StreamBuilder<List<SubmissionSiteModel>>(
                                    stream: _repo.watchSubmissionSites(
                                      widget.submissionId,
                                    ),
                                    builder: (
                                      BuildContext context,
                                      AsyncSnapshot<List<SubmissionSiteModel>>
                                          st,
                                    ) {
                                      final List<SubmissionSiteModel> sites =
                                          st.data ?? <SubmissionSiteModel>[];

                                      if (showRequesterPanel) {
                                        final bool myBranchIsTarget =
                                            effectiveBranch.isNotEmpty &&
                                                effectiveBranch != 'unknown' &&
                                                sites.any(
                                                  (SubmissionSiteModel s) =>
                                                      _siteMatchesUserBranch(
                                                          s, effectiveBranch),
                                                );
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            const Text(
                                              '수신 대상 제출 현황',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            if (sites.isEmpty)
                                              const Text(
                                                '사업소 데이터를 불러오는 중…',
                                                style: TextStyle(
                                                    color: Colors.grey),
                                              )
                                            else
                                              ...sites.map(
                                                (SubmissionSiteModel s) =>
                                                    _SiteRow(
                                                  label: s.label,
                                                  site: s,
                                                  repo: _repo,
                                                  isRequesterViewer: true,
                                                  onConfirm: s.status ==
                                                          'submitted'
                                                      ? () => _repo
                                                          .setSubmissionSiteStatus(
                                                            submissionId: widget
                                                                .submissionId,
                                                            siteDocId: s.id,
                                                            status: 'approved',
                                                          )
                                                      : null,
                                                  onRerequest: s.status ==
                                                          'submitted'
                                                      ? () =>
                                                          _showRerequestCommentDialog(
                                                            context,
                                                            submissionId: widget
                                                                .submissionId,
                                                            siteDocId: s.id,
                                                            repo: _repo,
                                                          )
                                                      : null,
                                                ),
                                              ),
                                            if (myBranchIsTarget) ...<Widget>[
                                              const Divider(height: 40),
                                              const Text(
                                                '내 사업소 제출',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              _BranchUploadPlaceholder(
                                                submissionId:
                                                    widget.submissionId,
                                                siteDocId: _siteDocIdForBranch(
                                                        sites,
                                                        effectiveBranch,) ??
                                                    effectiveBranch,
                                                due: sub.dueDate,
                                                repo: _repo,
                                              ),
                                            ],
                                          ],
                                        );
                                      }

                                      // 제출처: 요청 작성자가 아닌 경우, 내 사업소가 대상일 때만 제출 UI
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          const Text(
                                            '제출 / 이력',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          if (effectiveBranch.isEmpty ||
                                              effectiveBranch == 'unknown')
                                            const Text(
                                              '프로필에 사업소(지점)명이 없습니다. 관리자에게 문의하세요.',
                                              style: TextStyle(
                                                  color: Colors.grey),
                                            )
                                          else if (sites.isEmpty)
                                            const Text(
                                              '사업소 데이터를 불러오는 중…',
                                              style: TextStyle(
                                                  color: Colors.grey),
                                            )
                                          else if (!sites.any(
                                              (SubmissionSiteModel s) =>
                                                  _siteMatchesUserBranch(
                                                      s, effectiveBranch)))
                                            const Text(
                                              '이 요청의 대상 사업소가 아닙니다.',
                                              style: TextStyle(
                                                  color: Colors.grey),
                                            )
                                          else
                                            _BranchUploadPlaceholder(
                                              submissionId:
                                                  widget.submissionId,
                                              siteDocId: _siteDocIdForBranch(
                                                      sites,
                                                      effectiveBranch,) ??
                                                  effectiveBranch,
                                              due: sub.dueDate,
                                              repo: _repo,
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({
    required this.label,
    required this.site,
    required this.repo,
    this.isRequesterViewer = false,
    this.onConfirm,
    this.onRerequest,
  });

  final String label;
  final SubmissionSiteModel site;
  final WorkFirestoreRepository repo;
  final bool isRequesterViewer;
  final VoidCallback? onConfirm;
  final VoidCallback? onRerequest;

  @override
  Widget build(BuildContext context) {
    final String statusKr = SubmissionSiteModel.statusLabel(site.status);
    final List<SubmittedFileItem> files = site.allSubmittedFiles;
    final bool canDownload =
        isRequesterViewer && site.status == 'submitted' && files.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '상태: $statusKr',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (onConfirm != null)
                  TextButton(
                    onPressed: onConfirm,
                    child: const Text('확인'),
                  ),
                if (onRerequest != null)
                  TextButton(
                    onPressed: onRerequest,
                    child: const Text('재요청'),
                  ),
              ],
            ),
            if (canDownload) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                '제출 파일',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...files.map(
                (SubmittedFileItem f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          f.fileName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            final String url = await repo.getPresignedDownloadUrl(
                              f.fileUrl,
                              fileKey: f.fileKey,
                              fileName: f.fileName,
                            );
                            await _downloadSignedUrlInBrowser(url, f.fileName);
                          } catch (e) {
                            if (context.mounted) {
                              showMessageAlert(context,
                                  message: '$e',
                                  title: '다운로드 실패');
                            }
                          }
                        },
                        child: const Text('다운로드'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchUploadPlaceholder extends StatefulWidget {
  const _BranchUploadPlaceholder({
    required this.submissionId,
    required this.siteDocId,
    required this.repo,
    this.due,
  });

  final String submissionId;
  final String siteDocId;
  final WorkFirestoreRepository repo;
  final Timestamp? due;

  @override
  State<_BranchUploadPlaceholder> createState() =>
      _BranchUploadPlaceholderState();
}

class _BranchUploadPlaceholderState extends State<_BranchUploadPlaceholder> {
  List<PlatformFile> _cachedFiles = <PlatformFile>[];
  bool _uploading = false;
  String? _recallingUrl;

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _cachedFiles = List<PlatformFile>.from(result.files));
  }

  Future<void> _submit() async {
    if (_cachedFiles.isEmpty) return;
    setState(() => _uploading = true);
    try {
      await widget.repo.submitSubmissionSiteFiles(
        submissionId: widget.submissionId,
        siteDocId: widget.siteDocId,
        newFiles: _cachedFiles,
      );
      if (mounted) {
        showMessageAlert(context, message: '제출되었습니다.');
        setState(() => _cachedFiles = <PlatformFile>[]);
      }
    } catch (e) {
      if (mounted) {
        showMessageAlert(context, message: '업로드 실패: $e', title: '업로드 실패');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _recallOne(String fileUrl) async {
    setState(() => _recallingUrl = fileUrl);
    try {
      await widget.repo.recallSubmissionSiteFile(
        submissionId: widget.submissionId,
        siteDocId: widget.siteDocId,
        fileUrlToRemove: fileUrl,
      );
      if (mounted) showMessageAlert(context, message: '해당 파일을 회수했습니다.');
    } catch (e) {
      if (mounted) {
        showMessageAlert(context, message: '회수 실패: $e', title: '회수 실패');
      }
    } finally {
      if (mounted) setState(() => _recallingUrl = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestorePaths.submissionSitesCol(widget.submissionId)
          .doc(widget.siteDocId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap,
      ) {
        final SubmissionSiteModel? site = snap.hasData && snap.data!.exists
            ? SubmissionSiteModel.fromDoc(snap.data!)
            : null;
        final List<SubmittedFileItem> submitted =
            site?.allSubmittedFiles ?? <SubmittedFileItem>[];
        final bool hasSubmitted = submitted.isNotEmpty;
        final bool canRecallPerFile = site != null &&
            site.status != 'approved' &&
            site.status != 'rejected';
        final bool canAddMore =
            site == null || (site.status != 'approved');

        final String dueStr = widget.due == null
            ? '-'
            : DateFormat('yyyy-MM-dd').format(widget.due!.toDate());

        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (site != null &&
                  site.reRequestComment != null &&
                  site.reRequestComment!.trim().isNotEmpty) ...<Widget>[
                Material(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.info_outline,
                            color: Colors.amber.shade900, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '재요청 메시지',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(site.reRequestComment!),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (hasSubmitted) ...<Widget>[
                Text(
                  site!.status == 'approved'
                      ? '제출 파일 (요청처 확인됨 · 회수 불가)'
                      : '제출한 파일',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...submitted.map(
                  (SubmittedFileItem f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            f.fileName,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            try {
                              final String url = await widget.repo
                                  .getPresignedDownloadUrl(
                                f.fileUrl,
                                fileKey: f.fileKey,
                                fileName: f.fileName,
                              );
                              await _downloadSignedUrlInBrowser(
                                  url, f.fileName);
                            } catch (e) {
                              if (mounted) {
                                showMessageAlert(context,
                                    message: '$e',
                                    title: '다운로드 실패');
                              }
                            }
                          },
                          child: const Text('다운로드'),
                        ),
                        if (canRecallPerFile) ...<Widget>[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _recallingUrl == f.fileUrl
                                ? null
                                : () => _recallOne(f.fileUrl),
                            child: _recallingUrl == f.fileUrl
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('회수'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (canAddMore) const SizedBox(height: 20),
              ],
              if (canAddMore) ...<Widget>[
                Icon(Icons.cloud_upload_outlined,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  hasSubmitted
                      ? '추가 제출'
                      : '아직 제출된 파일이 없습니다.',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18),
                ),
                if (_cachedFiles.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '선택됨:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._cachedFiles.map(
                    (PlatformFile p) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '마감: $dueStr',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (_cachedFiles.isEmpty)
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file, size: 20),
                    label: const Text('파일 선택'),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _cachedFiles = <PlatformFile>[]),
                        child: const Text('선택 취소'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _uploading ? null : _submit,
                        icon: _uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check, size: 20),
                        label: Text(_uploading ? '업로드 중…' : '제출'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
