import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/rank.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../models/social.dart';
import '../widgets/common.dart';
import '../widgets/lives.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile!;
    final best = s.best;

    // Người mới: tự mở hướng dẫn thực hành một lần.
    if (s.shouldShowTutorial) {
      s.markTutorialSeen();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _go(context, const TutorialScreen());
      });
    }

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
                      IconButton(
                        tooltip: context.tr('howToPlay'),
                        icon: const Icon(Icons.help_rounded, color: AppColors.purple, size: 30),
                        onPressed: () => _go(context, const TutorialScreen()),
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
                                  Pill(text: rankAt(best.rank).emoji, color: rankAt(best.rank).color),
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
                    if (s.overtakeAlerts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _OvertakeBanner(alerts: s.overtakeAlerts),
                    ],
                    const SizedBox(height: 16),
                    const _RankCard(),
                    const SizedBox(height: 12),
                    const LivesBar(showAdButton: true),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 84,
                      width: double.infinity,
                      child: BubblyButton(
                        color: AppColors.green,
                        radius: 30,
                        fontSize: 38,
                        onPressed: () => startGame(context),
                        child: Text('▶  ${context.tr('play')}'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      _menu(context, '🏆', context.tr('leaderboard'), AppColors.orange,
                          () {
                            s.dismissOvertakeAlerts();
                            _go(context, const LeaderboardScreen());
                          },
                          badge: s.overtakeAlerts.length),
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

/// "🔥 Minh vừa vượt kỷ lục của bạn…" + nút Phục thù.
class _OvertakeBanner extends StatelessWidget {
  const _OvertakeBanner({required this.alerts});
  final List<FriendEntry> alerts;

  @override
  Widget build(BuildContext context) {
    final s = Provider.of<AppState>(context, listen: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red, width: 2),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final f in alerts.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  context.tr('overtakenBy', {
                    'name': f.name,
                    'rank': '${rankAt(f.bestRank).emoji} ${context.tr(rankAt(f.bestRank).key)}',
                    'score': f.bestScore,
                  }),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: BubblyButton(
                color: AppColors.red,
                fontSize: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: () {
                  s.dismissOvertakeAlerts();
                  startGame(context);
                },
                child: Text('⚔️ ${context.tr('revenge')}'),
              ),
            ),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: s.dismissOvertakeAlerts,
        ),
      ]),
    );
  }
}

String _fmtSec(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// Thẻ hạng đang chọn + mục tiêu thăng hạng. Bấm để đổi hạng.
class _RankCard extends StatelessWidget {
  const _RankCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = rankAt(s.selectedRank);
    final String goal;
    if (r.isTop) {
      goal = context.tr('topRank');
    } else if (s.selectedRank < s.maxRank) {
      goal = context.tr('rankTime', {'start': _fmtSec(r.startTime), 'end': _fmtSec(r.endTime)});
    } else {
      goal = context.tr('nextRankGoal', {
        'rank': context.tr(rankAt(r.index + 1).key),
        'level': r.promoteLevel,
        'score': r.promoteScore,
      });
    }
    return GestureDetector(
      onTap: () => _showRankPicker(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: r.color, width: 3),
        ),
        child: Row(children: [
          Text(r.emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${context.tr('rank')} ${context.tr(r.key)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: r.color)),
              Text(goal, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Icon(Icons.unfold_more_rounded, color: AppColors.ink),
        ]),
      ),
    );
  }
}

void _showRankPicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final s = c.watch<AppState>();
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(c.tr('chooseRank'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (final r in kRanks)
              Builder(builder: (_) {
                final unlocked = r.index <= s.maxRank;
                final selected = r.index == s.selectedRank;
                final prev = r.index == 0 ? null : rankAt(r.index - 1);
                final subtitle = unlocked
                    ? c.tr('rankTime', {'start': _fmtSec(r.startTime), 'end': _fmtSec(r.endTime)})
                    : c.tr('rankLocked', {
                        'level': prev!.promoteLevel,
                        'score': prev.promoteScore,
                        'rank': c.tr(prev.key),
                      });
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Opacity(
                    opacity: unlocked ? 1 : 0.55,
                    child: Material(
                      color: selected ? r.color.withValues(alpha: 0.18) : AppColors.cream,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: selected ? r.color : Colors.transparent, width: 3),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        leading: Text(r.emoji, style: const TextStyle(fontSize: 30)),
                        title: Text(c.tr(r.key),
                            style: TextStyle(fontWeight: FontWeight.w900, color: r.color, fontSize: 18)),
                        subtitle: Text(subtitle),
                        trailing: selected
                            ? Icon(Icons.check_circle_rounded, color: r.color)
                            : unlocked
                                ? null
                                : const Icon(Icons.lock_rounded),
                        onTap: unlocked
                            ? () {
                                s.setSelectedRank(r.index);
                                Navigator.pop(c);
                              }
                            : null,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    },
  );
}
