import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppUserAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final String? u = photoUrl?.trim();
    if (u != null && u.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: u,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            color: (backgroundColor ?? Colors.grey.shade200),
            child: SizedBox(
              width: size * 0.35,
              height: size * 0.35,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final String t = (fallbackText ?? '').trim();
    final String letter = t.isEmpty ? '' : t.characters.first;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? const Color(0xFFE2E8F0),
      child: letter.isEmpty
          ? Icon(Icons.person, size: size * 0.55, color: foregroundColor ?? Colors.white)
          : Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: size * 0.45,
                color: foregroundColor ?? Colors.white,
              ),
            ),
    );
  }
}

