import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Nút bấm "nổi" kiểu đồ chơi: lún xuống khi nhấn.
class BubblyButton extends StatefulWidget {
  const BubblyButton({
    super.key,
    required this.child,
    required this.color,
    this.onPressed,
    this.textColor = Colors.white,
    this.radius = 22,
    this.fontSize = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  final Widget child;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;
  final double radius;
  final double fontSize;
  final EdgeInsets padding;

  @override
  State<BubblyButton> createState() => _BubblyButtonState();
}

class _BubblyButtonState extends State<BubblyButton> {
  static const _depth = 6.0;
  bool _down = false;

  void _set(bool v) {
    if (widget.onPressed == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(widget.color);
    final shade = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final radius = BorderRadius.circular(widget.radius);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) {
        _set(false);
        widget.onPressed?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        margin: EdgeInsets.only(top: _down ? _depth : 0),
        padding: EdgeInsets.only(bottom: _down ? 0 : _depth),
        decoration: BoxDecoration(color: shade, borderRadius: radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: widget.textColor,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: widget.textColor, size: widget.fontSize + 4),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nền bầu trời có mây, dùng cho mọi màn hình.
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8FD3FF), Color(0xFFD9F2FF), Color(0xFFFFF6E0)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: 30, left: -10, child: _Cloud(80)),
          const Positioned(top: 110, right: -14, child: _Cloud(64)),
          const Positioned(bottom: 180, left: 24, child: _Cloud(44)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  const _Cloud(this.size);
  final double size;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: 0.75,
        child: Text('☁️', style: TextStyle(fontSize: size)),
      );
}

/// Nhân vật nhún nhảy tại chỗ.
class BouncingCharacter extends StatefulWidget {
  const BouncingCharacter({super.key, required this.emoji, this.size = 96});
  final String emoji;
  final double size;

  @override
  State<BouncingCharacter> createState() => _BouncingCharacterState();
}

class _BouncingCharacterState extends State<BouncingCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -t * widget.size * 0.18),
          child: Transform.scale(scaleY: 0.94 + t * 0.06, child: child),
        );
      },
      child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
    );
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.name, this.photoUrl, this.radius = 22});
  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.purple,
      foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      onForegroundImageError: photoUrl == null ? null : (_, __) {},
      child: Text(initial,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: radius * 0.9)),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.color, this.fontSize = 18});
  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(text,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: fontSize)),
      );
}

class OnlineBadge extends StatelessWidget {
  const OnlineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (s.syncing)
          const SizedBox(
              width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Icon(Icons.circle, size: 10, color: s.online ? AppColors.green : Colors.grey),
        const SizedBox(width: 6),
        Text(context.tr(s.online ? 'online' : 'offline'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget chip(String code, String label) {
      final on = s.lang == code;
      return GestureDetector(
        onTap: () => s.setLang(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? AppColors.orange : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: on ? Colors.white : AppColors.ink)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        chip('vi', '🇻🇳 VI'),
        const SizedBox(width: 4),
        chip('en', '🇬🇧 EN'),
      ]),
    );
  }
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
}
