import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/rank.dart';
import '../l10n/strings.dart';
import '../models/social.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SkyBackground(
          child: SafeArea(
            child: Column(children: [
              kidAppBar(
                '🏆 ${context.tr('leaderboard')}',
                actions: [
                  if (s.canUseCloud)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: s.syncing ? null : () => s.sync(force: true),
                    ),
                ],
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(30)),
                child: TabBar(
                  indicator: BoxDecoration(
                      color: AppColors.orange, borderRadius: BorderRadius.circular(26)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.ink,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  tabs: [
                    Tab(text: '👫 ${context.tr('friends')}'),
                    Tab(text: '🎮 ${context.tr('myHistory')}'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(children: [_FriendsBoard(), _MyHistory()]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FriendsBoard extends StatelessWidget {
  const _FriendsBoard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rows = s.leaderboard;
    final syncLabel = s.lastSync == null
        ? context.tr('neverSynced')
        : context.tr('lastSync', {'time': fmtDateTime(s.lastSync!)});

    return RefreshIndicator(
      onRefresh: () => s.sync(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!s.canUseCloud) ...[
            _Notice(text: context.tr('needLogin')),
            const SizedBox(height: 8),
            const GoogleLoginButton(height: 56, fontSize: 17),
          ] else ...[
            Row(children: [
              const OnlineBadge(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(syncLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: AppColors.ink.withValues(alpha: 0.7))),
              ),
            ]),
            if (rows.length <= 1) ...[
              const SizedBox(height: 8),
              _Notice(text: context.tr('noFriends')),
            ],
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) _RankRow(rank: i + 1, entry: rows[i]),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry});
  final int rank;
  final FriendEntry entry;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '$rank' };
    final e = entry;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: cardDecoration(color: e.isMe ? const Color(0xFFFFF3BF) : Colors.white),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: Text(medal,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        PlayerAvatar(name: e.name, photoUrl: e.photoUrl, radius: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.isMe ? '${e.name} ${context.tr('you')}' : e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(
              '${rankAt(e.bestRank).emoji} ${context.tr(rankAt(e.bestRank).key)} • Lv ${e.bestLevel} • ⏱️ ${fmtDuration(e.bestTimeMs, context.lang)}',
              style: TextStyle(color: AppColors.ink.withValues(alpha: 0.7), fontSize: 13),
            ),
          ]),
        ),
        Text('⭐ ${e.bestScore}',
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.orange)),
      ]),
    );
  }
}

class _MyHistory extends StatelessWidget {
  const _MyHistory();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final games = [...s.history]
      ..sort((a, b) => a.rank != b.rank ? b.rank.compareTo(a.rank) : b.score.compareTo(a.score));
    if (games.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        _Notice(text: context.tr('noGames')),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: games.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.tr('games', {'n': s.gamesPlayed}),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          );
        }
        final g = games[i - 1];
        final medal = switch (i) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '$i' };
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: cardDecoration(),
          child: Row(children: [
            SizedBox(
              width: 36,
              child: Text(medal,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${rankAt(g.rank).emoji} Lv ${g.level} • ✅ ${g.correct} • ⏱️ ${fmtDuration(g.durationMs, context.lang)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(fmtDateTime(g.playedAt),
                    style: TextStyle(color: AppColors.ink.withValues(alpha: 0.6), fontSize: 13)),
              ]),
            ),
            Text('⭐ ${g.score}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.orange)),
          ]),
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}
