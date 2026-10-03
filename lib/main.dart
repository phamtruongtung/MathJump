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
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final store = LocalStore();
  await store.init();
  final cloud = CloudService();
  await cloud.init(); // không có cấu hình Firebase vẫn chạy được (offline/khách)
  final state = AppState(store, cloud, SoundService());
  await state.init();

  runApp(ChangeNotifierProvider.value(value: state, child: const MathJumpApp()));
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
