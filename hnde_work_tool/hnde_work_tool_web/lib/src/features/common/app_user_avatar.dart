import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/work_firestore_repository.dart';
import '../../services/r2_storage_service.dart';

/// 사용자 프로필 사진을 원형으로 표시.
///
/// `photoUrl`이 R2 키/URL 형태(예: `https://<worker>/uploads/...` 또는 `?key=...`)면
/// 자동으로 [WorkFirestoreRepository.getPresignedViewUrl] 을 거쳐 인증된 URL로 표시합니다.
/// presigned URL 의 쿼리 파라미터는 매번 달라질 수 있으므로 cacheKey 를 R2 key 로 고정해
/// 같은 사진은 동일한 캐시 항목을 재사용하고, [photoUrl] 자체가 바뀌면(=새 사진 업로드)
/// 새로 받아옵니다.
class AppUserAvatar extends StatefulWidget {
  const AppUserAvatar({
    super.key,
    required this.size,
    this.photoUrl,
    this.fallbackText,
    this.backgroundColor,
    this.foregroundColor,
  });

  final double size;
  final String? photoUrl;
  final String? fallbackText;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<AppUserAvatar> createState() => _AppUserAvatarState();
}

class _AppUserAvatarState extends State<AppUserAvatar> {
  /// 현재 표시 중인 photoUrl (변경 감지용)
  String? _resolvedFor;

  /// 최종 표시 URL (presigned 또는 일반 URL)
  Future<String?>? _displayUrlFuture;

  /// CachedNetworkImage 캐시 키 (R2 key 또는 원본 URL)
  String? _cacheKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AppUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String oldU = oldWidget.photoUrl?.trim() ?? '';
    final String newU = widget.photoUrl?.trim() ?? '';
    if (oldU != newU) {
      _resolveIfNeeded(force: true);
    }
  }

  void _resolveIfNeeded({bool force = false}) {
    final String url = widget.photoUrl?.trim() ?? '';
    if (!force && _resolvedFor == url) return;
    _resolvedFor = url;
    if (url.isEmpty) {
      _displayUrlFuture = null;
      _cacheKey = null;
      return;
    }
    final String? key = R2StorageService.fileKeyFromUrl(url);
    if (key == null || key.trim().isEmpty) {
      _displayUrlFuture = Future<String?>.value(url);
      _cacheKey = url;
      return;
    }
    final WorkFirestoreRepository repo =
        context.read<WorkFirestoreRepository>();
    _displayUrlFuture = repo.getPresignedViewUrl(url);
    _cacheKey = key;
  }

  @override
  Widget build(BuildContext context) {
    final Future<String?>? future = _displayUrlFuture;
    if (future == null) {
      return _fallback();
    }
    return FutureBuilder<String?>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<String?> snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return _loadingTile();
        }
        final String? resolved = snap.data?.trim();
        if (resolved == null || resolved.isEmpty || snap.hasError) {
          return _fallback();
        }
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolved,
            cacheKey: _cacheKey,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (BuildContext _, String __) => _loadingTile(),
            errorWidget: (BuildContext _, String __, Object ___) => _fallback(),
          ),
        );
      },
    );
  }

  Widget _loadingTile() {
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor ?? Colors.grey.shade200,
      ),
      child: SizedBox(
        width: widget.size * 0.35,
        height: widget.size * 0.35,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _fallback() {
    final String t = (widget.fallbackText ?? '').trim();
    final String letter = t.isEmpty ? '' : t.characters.first;
    return CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: widget.backgroundColor ?? const Color(0xFFE2E8F0),
      child: letter.isEmpty
          ? Icon(
              Icons.person,
              size: widget.size * 0.55,
              color: widget.foregroundColor ?? Colors.white,
            )
          : Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: widget.size * 0.45,
                color: widget.foregroundColor ?? Colors.white,
              ),
            ),
    );
  }
}
