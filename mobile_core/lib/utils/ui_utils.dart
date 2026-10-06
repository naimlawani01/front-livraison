import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class UIUtils {
  static void showError(BuildContext context, String message) {
    _show(context, message: formatError(message), icon: Icons.error_outline_rounded, isError: true);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.check_circle_outline_rounded, isError: false);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message: message, icon: Icons.info_outline_rounded, isError: false);
  }

  /// Nettoie les messages d'erreur techniques (ex: "Exception: message")
  static String formatError(String error) {
    if (error.isEmpty) return 'Une erreur est survenue';
    String formatted = error;
    final prefixes = ['exception:', 'error:', 'unsupported operation:', 'bad state:'];
    bool changed = true;
    while (changed) {
      changed = false;
      final lower = formatted.toLowerCase().trim();
      for (var prefix in prefixes) {
        if (lower.startsWith(prefix)) {
          formatted = formatted.trim().substring(prefix.length).trim();
          changed = true;
          break;
        }
      }
    }
    if (formatted.isNotEmpty) {
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    }
    return formatted.isEmpty ? 'Une erreur est survenue' : formatted;
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    bool isError = false,
  }) {
    if (isError) HapticFeedback.mediumImpact();

    final overlay = Overlay.of(context);
    final entry = _ToastEntry();
    entry.overlayEntry = OverlayEntry(
      builder: (_) => _TopToast(
        message: message,
        icon: icon,
        isError: isError,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry.overlayEntry!);

    Future.delayed(Duration(seconds: isError ? 4 : 3), () {
      entry.remove();
    });
  }
}

class _ToastEntry {
  OverlayEntry? overlayEntry;
  bool _removed = false;

  void remove() {
    if (!_removed) {
      _removed = true;
      try {
        overlayEntry?.remove();
      } catch (_) {}
    }
  }
}

class _TopToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final bool isError;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.message,
    required this.icon,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bgColor => widget.isError
      ? const Color(0xFFFEF2F2)
      : const Color(0xFFF0FDF4);

  Color get _borderColor => widget.isError
      ? const Color(0xFFFCA5A5)
      : const Color(0xFF86EFAC);

  Color get _iconColor => widget.isError
      ? AppTheme.error
      : AppTheme.success;

  Color get _textColor => widget.isError
      ? const Color(0xFF991B1B)
      : const Color(0xFF14532D);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 12,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => FractionalTranslation(
          translation: Offset(0, _slide.value),
          child: FadeTransition(opacity: _fade, child: child),
        ),
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: _iconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
