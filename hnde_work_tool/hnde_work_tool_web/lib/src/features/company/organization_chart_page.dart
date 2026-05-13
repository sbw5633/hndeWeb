import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../../constants/super_admin.dart';
import '../../repositories/work_firestore_repository.dart';
import '../common/loading_widget.dart';
import '../common/merged_user_profile_stream_builder.dart';
import 'company_info_back_bar.dart';

/// 조직도: Firestore+R2 업로드본 우선, 없으면 번들 에셋
class OrganizationChartPage extends StatelessWidget {
  const OrganizationChartPage({super.key});

  static const String assetFallback =
      'assets/company/organization_chart.pdf';

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

        return StreamBuilder<Map<String, dynamic>?>(
          stream: repo.watchOrgChartDoc(),
          builder: (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> orgSnap,
          ) {
            final Map<String, dynamic>? d = orgSnap.data;
            final String? url = (d?['fileUrl'] as String?)?.trim();
            final String? r2Key = (d?['r2Key'] as String?)?.trim();

            return Scaffold(
              appBar: AppBar(
                title: const Text('조직도'),
                actions: <Widget>[
                  if (mainAdmin)
                    IconButton(
                      tooltip: 'PDF 업로드',
                      icon: const Icon(Icons.upload_file_outlined),
                      onPressed: () => _uploadOrgChart(context, repo),
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
                  Expanded(
                    child: _OrgPdfBody(
                      key: ValueKey<String>(
                        url != null && url.isNotEmpty
                            ? '$url|$r2Key'
                            : 'asset',
                      ),
                      assetPath: assetFallback,
                      fileUrl: url,
                      r2Key: r2Key,
                      repo: repo,
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

  static Future<void> _uploadOrgChart(
    BuildContext context,
    WorkFirestoreRepository repo,
  ) async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    final PlatformFile f = picked.files.first;
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
      await repo.setOrgChartPdf(f);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('조직도 PDF를 반영했습니다.')),
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
}

class _OrgPdfBody extends StatefulWidget {
  const _OrgPdfBody({
    super.key,
    required this.assetPath,
    required this.fileUrl,
    required this.r2Key,
    required this.repo,
  });

  final String assetPath;
  final String? fileUrl;
  final String? r2Key;
  final WorkFirestoreRepository repo;

  @override
  State<_OrgPdfBody> createState() => _OrgPdfBodyState();
}

class _OrgPdfBodyState extends State<_OrgPdfBody> {
  PdfControllerPinch? _controller;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Uint8List> _fetchBytes() async {
    final String? u = widget.fileUrl;
    if (u != null && u.isNotEmpty) {
      final String signed = await widget.repo.getPresignedDownloadUrl(
        u,
        fileKey: widget.r2Key,
      );
      final http.Response res = await http
          .get(Uri.parse(signed))
          .timeout(const Duration(minutes: 3));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('다운로드 실패 (${res.statusCode})');
      }
      return res.bodyBytes;
    }
    final ByteData data = await rootBundle.load(widget.assetPath);
    return data.buffer.asUint8List();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final Uint8List bytes = await _fetchBytes();
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
          size: 72,
          duration: const Duration(seconds: 2),
          text: 'PDF 불러오는 중…',
          textStyle: TextStyle(
            fontSize: 13,
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
            'PDF를 불러오지 못했습니다.\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final PdfControllerPinch? c = _controller;
    if (c == null) {
      return const SizedBox.shrink();
    }
    return PdfViewPinch(controller: c);
  }
}
