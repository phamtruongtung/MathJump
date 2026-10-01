import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'friends_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile!;
    final best = s.best;

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 40),
                child: IntrinsicHeight(
                  child: Column(children: [
                    Row(children: [
                      PlayerAvatar(name: p.name, photoUrl: p.photoUrl),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(context.tr('hello', {'name': p.name}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      const OnlineBadge(),
                    ]),
                    const Spacer(),
                    const Text('Math Jump',
                        style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          color: AppColors.purple,
                          shadows: [Shadow(color: Colors.white, offset: Offset(3, 3))],
                        )),
                    const SizedBox(height: 8),
                    BouncingCharacter(emoji: s.character, size: 100),
                    Container(
                      width: 150,
                      padding: const EdgeInsets.only(bottom: 7),
                      decoration: BoxDecoration(
                        color: AppColors.dirt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.grass,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration(),
                      child: best == null
                          ? Text(context.tr('noRecord'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))
                          : Column(children: [
                              Text('🏆 ${context.tr('bestRecord')}',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Pill(text: '⭐ ${best.score}', color: AppColors.orange),
                                  Pill(text: '${context.tr('level')} ${best.level}', color: AppColors.purple),
                                  Pill(
                                      text: '⏱️ ${fmtDuration(best.durationMs, context.lang)}',
                                      color: AppColors.blue),
                                ],
                              ),
                            ]),
                    ),
                    const Spacer(),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 84,
                      width: double.infinity,
                      child: BubblyButton(
                        color: AppColors.green,
                        radius: 30,
                        fontSize: 38,
                        onPressed: () => _go(context, const GameScreen()),
                        child: Text('▶  ${context.tr('play')}'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      _menu(context, '🏆', context.tr('leaderboard'), AppColors.orange,
                          () => _go(context, const LeaderboardScreen())),
                      const SizedBox(width: 12),
                      _menu(context, '👫', context.tr('friends'), AppColors.pink,
                          () => _go(context, const FriendsScreen()),
                          badge: s.incoming.length),
                      const SizedBox(width: 12),
                      _menu(context, '⚙️', context.tr('settings'), AppColors.blue,
                          () => _go(context, const SettingsScreen())),
                    ]),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, String emoji, String label, Color color, VoidCallback onTap,
      {int badge = 0}) {
    return Expanded(
      child: SizedBox(
        height: 88,
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          child: BubblyButton(
            color: color,
            fontSize: 15,
            padding: const EdgeInsets.all(6),
            onPressed: onTap,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              FittedBox(child: Text(label)),
            ]),
          ),
        ),
      ),
    );
  }
}
