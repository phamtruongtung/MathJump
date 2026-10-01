import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Gọi đăng nhập Facebook và hiển thị lỗi (nếu có). Dùng chung cho nhiều màn hình.
Future<void> loginWithFacebook(BuildContext context) async {
  final s = context.read<AppState>();
  final err = await s.signInWithFacebook();
  if (!context.mounted || err == null || err.isEmpty) return;
  showToast(
    context,
    err == 'firebaseMissing'
        ? context.tr('firebaseMissing')
        : context.tr('loginFailed', {'msg': err}),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _fb() async {
    setState(() => _busy = true);
    await loginWithFacebook(context);
    if (mounted) setState(() => _busy = false);
  }

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
              SizedBox(
                height: 62,
                width: double.infinity,
                child: BubblyButton(
                  color: AppColors.facebook,
                  fontSize: 20,
                  onPressed: _busy ? null : _fb,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_busy)
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    else
                      const Icon(Icons.facebook),
                    const SizedBox(width: 10),
                    Flexible(child: FittedBox(child: Text(context.tr('loginFacebook')))),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 62,
                width: double.infinity,
                child: BubblyButton(
                  color: Colors.white,
                  textColor: AppColors.ink,
                  fontSize: 20,
                  onPressed: _busy ? null : s.playAsGuest,
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
