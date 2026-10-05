import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Gọi đăng nhập Google và hiển thị lỗi (nếu có). Dùng chung cho nhiều màn hình.
Future<void> loginWithGoogle(BuildContext context) async {
  final s = context.read<AppState>();
  final err = await s.signInWithGoogle();
  if (!context.mounted || err == null || err.isEmpty) return;
  showToast(
    context,
    err == 'firebaseMissing'
        ? context.tr('firebaseMissing')
        : context.tr('loginFailed', {'msg': err}),
  );
}

/// Chữ "G" nhiều màu kiểu logo Google.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: ShaderMask(
          shaderCallback: (r) => const SweepGradient(colors: [
            Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335), Color(0xFF4285F4),
          ]).createShader(r),
          child: Text('G',
              style: TextStyle(
                  color: Colors.white, fontSize: size * 0.8, fontWeight: FontWeight.w900, height: 1)),
        ),
      );
}

/// Nút "Đăng nhập bằng Google" dùng chung cho mọi màn hình.
class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({super.key, this.height = 62, this.fontSize = 20});
  final double height;
  final double fontSize;

  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    await loginWithGoogle(context);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        width: double.infinity,
        child: BubblyButton(
          color: Colors.white,
          textColor: AppColors.ink,
          fontSize: widget.fontSize,
          onPressed: _busy ? null : _login,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_busy)
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: AppColors.blue, strokeWidth: 3))
            else
              GoogleMark(size: widget.fontSize + 8),
            const SizedBox(width: 10),
            Flexible(child: FittedBox(child: Text(context.tr('loginGoogle')))),
          ]),
        ),
      );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Align(alignment: Alignment.topRight, child: LanguageSwitch()),
              const Spacer(),
              BouncingCharacter(emoji: s.character, size: 110),
              const SizedBox(height: 8),
              const Text('Math Jump',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.purple,
                    shadows: [Shadow(color: Colors.white, offset: Offset(3, 3))],
                  )),
              Text(context.tr('tagline'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text('1 + ? = 3   ·   6 ? 2 = 3   ·   ? × 4 = 20',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.blue)),
              const Spacer(),
              const GoogleLoginButton(),
              const SizedBox(height: 14),
              SizedBox(
                height: 62,
                width: double.infinity,
                child: BubblyButton(
                  color: AppColors.orange,
                  fontSize: 20,
                  onPressed: s.playAsGuest,
                  child: FittedBox(child: Text('🎮 ${context.tr('playAsGuest')}')),
                ),
              ),
              const SizedBox(height: 10),
              Text(context.tr('guestNote'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.ink.withValues(alpha: 0.7))),
            ]),
          ),
        ),
      ),
    );
  }
}
