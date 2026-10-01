import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Cầu thang zig-zag: mỗi lần [step] tăng, nhân vật nhảy lên bậc kế tiếp
/// và "camera" cuộn theo.
class ClimberView extends StatefulWidget {
  const ClimberView({
    super.key,
    required this.step,
    required this.character,
    this.fallen = false,
  });

  final int step;
  final String character;
  final bool fallen;

  @override
  State<ClimberView> createState() => _ClimberViewState();
}

class _ClimberViewState extends State<ClimberView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late int _from = widget.step;
  late int _to = widget.step;

  @override
  void didUpdateWidget(ClimberView old) {
    super.didUpdateWidget(old);
    if (widget.step != old.step) {
      _from = _to;
      _to = widget.step;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double xFrac(int i) => const [0.22, 0.5, 0.78, 0.5][i % 4];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final e = Curves.easeInOut.transform(t);
          final cam = _from + (_to - _from) * e;
          final baseY = h * 0.80;
          final size = min(64.0, h * 0.3);
          final x = (xFrac(_from) + (xFrac(_to) - xFrac(_from)) * e) * w;
          final arc = sin(pi * t) * h * 0.25;
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _StairsPainter(cam))),
            Positioned(
              left: x - size / 2,
              top: baseY - size - arc + size * 0.08,
              width: size,
              height: size,
              child: Transform.rotate(
                angle: widget.fallen ? 0.5 : 0,
                child: FittedBox(child: Text(widget.character)),
              ),
            ),
            if (widget.fallen)
              Positioned(
                left: x - size * 0.3,
                top: baseY - size * 1.45,
                child: Text('💫', style: TextStyle(fontSize: size * 0.5)),
              ),
          ]);
        },
      );
    });
  }
}

class _StairsPainter extends CustomPainter {
  _StairsPainter(this.cam);
  final double cam;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseY = h * 0.80;
    final stepH = h * 0.30;
    final pw = w * 0.26;

    // Mây trôi xuống khi leo lên (parallax).
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var k = 0; k < 4; k++) {
      final cx = ((k * 0.37 + 0.12) % 1.0) * w;
      final cy = ((k * 0.29 + cam * 0.12) % 1.0) * h;
      final r = 12.0 + k * 3;
      canvas.drawCircle(Offset(cx, cy), r, cloud);
      canvas.drawCircle(Offset(cx + r, cy + 3), r * 0.8, cloud);
      canvas.drawCircle(Offset(cx - r, cy + 4), r * 0.7, cloud);
    }

    // Mặt đất ở bậc 0.
    final groundY = baseY + cam * stepH;
    if (groundY < h) {
      canvas.drawRect(Rect.fromLTRB(0, groundY, w, h), Paint()..color = AppColors.grass);
      canvas.drawRect(
          Rect.fromLTRB(0, groundY + 14, w, h), Paint()..color = AppColors.dirt);
    }

    final first = max(1, cam.floor() - 3);
    final last = cam.floor() + 5;
    for (var i = first; i <= last; i++) {
      final y = baseY - (i - cam) * stepH;
      if (y < -30 || y > h + 30) continue;
      final cx = _ClimberViewState.xFrac(i) * w;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, y + 10), width: pw, height: 20),
        const Radius.circular(10),
      );
      canvas.drawRRect(rect.shift(const Offset(0, 7)), Paint()..color = AppColors.dirt);
      canvas.drawRRect(rect, Paint()..color = AppColors.grass);
      final tp = TextPainter(
        text: TextSpan(
          text: '$i',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, y + 10 - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_StairsPainter old) => old.cam != cam;
}
