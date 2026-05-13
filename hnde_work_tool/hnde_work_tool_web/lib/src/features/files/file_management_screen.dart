import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/firestore_paths.dart';
import '../../constants/super_admin.dart';
import '../../services/r2_storage_service.dart';
import '../common/enterprise_scaffold.dart';
import '../common/loading_widget.dart';
import '../common/merged_user_profile_stream_builder.dart';
import '../common/message_alert.dart';

class FileManagementScreen extends StatefulWidget {
  const FileManagementScreen({super.key});

  @override
  State<FileManagementScreen> createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen> {
  static final R2StorageService _storage = R2StorageService();
  static final DateFormat _dt = DateFormat('yyyy-MM-dd HH:mm');

  List<_R2FileRow>? _rows;
  String? _loadError;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final List<R2BucketObjectInfo> objects =
          await _storage.listAllBucketObjects();
      final QuerySnapshot<Map<String, dynamic>> regSnap =
          await FirestorePaths.r2FileRegistryCol().get();
      final QuerySnapshot<Map<String, dynamic>> trSnap =
          await FirestorePaths.transfersCol().get();

      final Map<String, Map<String, dynamic>> byKey =
          <String, Map<String, dynamic>>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d
          in regSnap.docs) {
        final String? fk = d.data()['fileKey'] as String?;
        if (fk != null && fk.isNotEmpty) {
          byKey[fk] = d.data();
        }
      }

      final Map<String, DocumentSnapshot<Map<String, dynamic>>> transferByKey =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in trSnap.docs) {
        final String? fk = d.data()['fileKey'] as String?;
        if (fk != null && fk.isNotEmpty) {
          transferByKey[fk] = d;
        }
      }

      final List<_R2FileRow> rows = <_R2FileRow>[];
      for (final R2BucketObjectInfo o in objects) {
        final Map<String, dynamic>? meta = byKey[o.key];
        rows.add(
          _R2FileRow(
            fileKey: o.key,
            fileName: o.key.split('/').last,
            sizeBytes: o.size,
            r2LastModified: o.lastModified,
            uploadedByDisplayName:
                meta?['uploadedByDisplayName'] as String?,
            uploadedByUid: meta?['uploadedByUid'] as String?,
            source: meta?['source'] as String?,
            sourcePath: meta?['sourcePath'] as String?,
            registryCreatedAt: meta?['createdAt'] as Timestamp?,
            transferDoc: transferByKey[o.key],
          ),
        );
      }
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  static String _formatBytes(int? b) {
    if (b == null) {
      return '—';
    }
    if (b < 1024) {
      return '$b B';
    }
    if (b < 1024 * 1024) {
      return '${(b / 1024).toStringAsFixed(1)} KB';
    }
    return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static String? _tsStr(Timestamp? t) {
    if (t == null) {
      return null;
    }
    return _dt.format(t.toDate());
  }

  static String? _dtStr(DateTime? d) {
    if (d == null) {
      return null;
    }
    return _dt.format(d.toLocal());
  }

  Future<bool> _confirmDeleteTwice(
    BuildContext context, {
    required String fileKey,
    required String label,
  }) async {
    final bool? first = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('파일 삭제'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'R2 저장소에서 아래 객체를 삭제합니다. 복구할 수 없습니다.',
                ),
                const SizedBox(height: 12),
                Text(
                  '파일: $label',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  fileKey,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('다음'),
            ),
          ],
        );
      },
    );
    if (first != true || !context.mounted) {
      return false;
    }
    final bool? second = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('재확인'),
          content: Text(
            '정말 삭제하시겠습니까?\n\n"$label"\n\n연결된 전송 기록·레지스트리도 함께 삭제됩니다.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade900,
              ),
              child: const Text('삭제 실행'),
            ),
          ],
        );
      },
    );
    return second == true;
  }

  Future<void> _deleteRow(BuildContext context, _R2FileRow row) async {
    final bool ok = await _confirmDeleteTwice(
      context,
      fileKey: row.fileKey,
      label: row.fileName,
    );
    if (!ok || !context.mounted) {
      return;
    }
    try {
      await _storage.deleteFile(row.fileKey);
      await FirestorePaths.r2FileRegistryCol()
          .doc(FirestorePaths.r2RegistryDocIdFromFileKey(row.fileKey))
          .delete()
          .catchError((_) {});
      if (row.transferDoc != null) {
        await row.transferDoc!.reference.delete();
      }
      if (context.mounted) {
        showMessageAlert(context, message: '삭제했습니다.');
      }
      await _load();
    } catch (e) {
      if (context.mounted) {
        showMessageAlert(context, message: '삭제 실패: $e', title: '오류');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const EnterpriseScaffold(
        title: '파일 관리 (전체 관리자 전용)',
        child: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return EnterpriseScaffold(
      title: '파일 관리 (전체 관리자 전용)',
      child: MergedUserProfileStreamBuilder(
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
          if (!mainAdmin) {
            return const Center(
              child: Text(
                '접근 권한이 없습니다.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          if (_loadError != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '불러오기 실패: $_loadError',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                if (_loading && _rows == null) {
                  return const Center(child: LoadingWidget(size: 80));
                }

                final List<_R2FileRow>? rows = _rows;
                if (rows == null || rows.isEmpty) {
                  return Column(
                    children: <Widget>[
                      _toolbar(context),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'R2 버킷에 객체가 없습니다.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _toolbar(context),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth:
                                    MediaQuery.sizeOf(context).width - 48,
                              ),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF1F5F9),
                                ),
                                columns: const <DataColumn>[
                                  DataColumn(label: Text('파일명')),
                                  DataColumn(label: Text('R2 경로')),
                                  DataColumn(label: Text('크기')),
                                  DataColumn(label: Text('R2 수정 시각')),
                                  DataColumn(label: Text('업로드자')),
                                  DataColumn(label: Text('출처 / 경로')),
                                  DataColumn(label: Text('등록 시각')),
                                  DataColumn(label: Text('작업')),
                                ],
                                rows: rows
                                    .map(
                                      (_R2FileRow r) => DataRow(
                                        cells: <DataCell>[
                                          DataCell(
                                            Tooltip(
                                              message: r.fileName,
                                              child: Text(
                                                r.fileName,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 280,
                                              child: SelectableText(
                                                r.fileKey,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(_formatBytes(r.sizeBytes))),
                                          DataCell(Text(
                                            _dtStr(r.r2LastModified) ?? '—',
                                          )),
                                          DataCell(Text(
                                            r.uploadedByDisplayName ??
                                                r.uploadedByUid ??
                                                '—',
                                          )),
                                          DataCell(
                                            SizedBox(
                                              width: 220,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  if (r.source != null)
                                                    Text(
                                                      r.source!,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  if (r.sourcePath != null)
                                                    Text(
                                                      r.sourcePath!,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade700,
                                                      ),
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  if (r.source == null &&
                                                      r.sourcePath == null)
                                                    Text(
                                                      '미등록 (이전 업로드 등)',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(
                                            _tsStr(r.registryCreatedAt) ??
                                                '—',
                                          )),
                                          DataCell(
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red.shade700,
                                              ),
                                              tooltip: '삭제',
                                              onPressed: () =>
                                                  _deleteRow(context, r),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text(
          'R2 버킷 전체',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '경로·업로더·시간은 신규 레지스트리 기준입니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _loading ? null : _load,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: const Text('새로고침'),
        ),
      ],
    );
  }
}

class _R2FileRow {
  const _R2FileRow({
    required this.fileKey,
    required this.fileName,
    this.sizeBytes,
    this.r2LastModified,
    this.uploadedByDisplayName,
    this.uploadedByUid,
    this.source,
    this.sourcePath,
    this.registryCreatedAt,
    this.transferDoc,
  });

  final String fileKey;
  final String fileName;
  final int? sizeBytes;
  final DateTime? r2LastModified;
  final String? uploadedByDisplayName;
  final String? uploadedByUid;
  final String? source;
  final String? sourcePath;
  final Timestamp? registryCreatedAt;
  final DocumentSnapshot<Map<String, dynamic>>? transferDoc;
}
