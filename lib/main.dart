import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/cloud_service.dart';
import 'services/local_store.dart';
import 'services/sound_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lỗi khi vẽ giao diện: hiện nội dung lỗi thay vì màn hình trắng/xám.
  ErrorWidget.builder = (details) => _ErrorBox(details.exceptionAsString());
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[Error] ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Error] $error\n$stack');
    return true; // lỗi bất đồng bộ: ghi lại, không làm sập game
  };

  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final store = LocalStore();
    await store.init();
    final cloud = CloudService();
    // Không có cấu hình Firebase vẫn chạy được (offline/khách).
    await cloud.init().timeout(const Duration(seconds: 20));
    final state = AppState(store, cloud, SoundService());
    await state.init().timeout(const Duration(seconds: 20));
    runApp(ChangeNotifierProvider.value(value: state, child: const MathJumpApp()));
  } catch (e, s) {
    // Khởi động thất bại: hiện lỗi để người chơi chụp màn hình báo lại.
    debugPrint('[Startup] $e\n$s');
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: AppColors.cream, body: _ErrorBox('$e')),
    ));
  }
}

/// Hộp báo lỗi thân thiện (thay cho màn hình trắng khi có lỗi).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('😵', style: TextStyle(fontSize: 64)),
              const Text('Ôi, game gặp lỗi / Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text(
                  'Hãy chụp màn hình này gửi cho nhà phát triển, rồi tải lại trang hoặc mở lại game.\n'
                  'Please take a screenshot, then reload the page or reopen the game.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.ink)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.red),
                ),
                child: SelectableText(message,
                    style: const TextStyle(fontSize: 13, color: AppColors.red)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class MathJumpApp extends StatelessWidget {
  const MathJumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppState, String>((s) => s.lang);
    return MaterialApp(
      title: 'Math Jump',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _RootGate(),
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) => context.read<AppState>().sound.ensureMusic(),
        child: child,
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AppState, bool>((s) => s.profile != null);
    return loggedIn ? const HomeScreen() : const LoginScreen();
  }
}
