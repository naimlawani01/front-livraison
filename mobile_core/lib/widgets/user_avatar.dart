import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Circular avatar that shows a remote photo when available and falls back to
/// the user's initials on a soft-coloured background otherwise.
///
/// Used for the livreur greeting on the home screen, but reusable anywhere a
/// user (livreur, expediteur, admin) needs to be shown compactly.
class UserAvatar extends StatelessWidget {
  /// Remote photo URL (e.g. Cloudflare R2 presigned URL). May be null/empty.
  final String? photoUrl;

  /// Full name used to derive initials when [photoUrl] is missing.
  final String? name;

  /// Diameter in logical pixels (avatar is always circular).
  final double size;

  /// Optional border around the avatar (useful on photo-heavy backgrounds).
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.size = 44,
    this.borderColor,
    this.borderWidth = 0,
  });

  String get _initials {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return '?';
    final parts = raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (photoUrl ?? '').trim().isNotEmpty;

    Widget content;
    if (hasPhoto) {
      content = Image.network(
        photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initialsFallback(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: AppTheme.shimmer,
          );
        },
      );
    } else {
      content = _initialsFallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _initialsFallback() {
    return Container(
      width: size,
      height: size,
      color: AppTheme.accentLight,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: AppTheme.accentDark,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
