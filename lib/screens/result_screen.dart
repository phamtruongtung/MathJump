import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../game/rank.dart';
import '../l10n/strings.dart';
import '../models/game_result.dart';
import '../services/sound_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/lives.dart';
import 'leaderboard_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    required this.newRecord,
    required this.previousBest,
    required this.reason,
    this.promotedTo,
  });

  final GameResult result;
  final bool newRecord;
  final GameResult? previousBest;
  final String reason;

  /// Hạng mới nếu người chơi vừa thăng hạng trong ván này.
  final int? promotedTo;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _cardKey = GlobalKey();
  final _confetti = ConfettiController(duration: const Duration(seconds: 4));
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.newRecord || widget.promotedTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confetti.play();
        context.read<AppState>().sound.play(Sfx.record);
      });
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// Những người bạn vừa bị vượt qua trong ván này.
  /// (so theo hạng trước, điểm sau: trước ván này họ không thua mình,
  /// sau ván này mình hơn họ).
  List<String> _overtaken(AppState s) {
    final prev = widget.previousBest;
    final r = widget.result;
    return s.friends
        .where((f) =>
            (f.bestScore > 0 || f.bestRank > 0) &&
            !f.beatsRecord(r.rank, r.score) &&
            !(f.bestRank == r.rank && f.bestScore == r.score) &&
            (prev == null || !prev.beats(GameResult(
                score: f.bestScore, level: 1, correct: 0, durationMs: 0,
                playedAt: r.playedAt, rank: f.bestRank))))
        .map((f) => f.name)
        .toList();
  }

  List<String> _captions() {
    final r = widget.result;
    final args = {
      'score': r.score,
      'level': r.level,
      'correct': r.correct,
      'time': fmtDuration(r.durationMs, context.lang),
      'rank': context.tr(rankAt(r.rank).key),
    };
    return [
      if (widget.newRecord) context.tr('stRecord', args),
      context.tr('st1', args),
      context.tr('st2', args),
      context.tr('st3', args),
    ];
  }

  Future<void> _share() async {
    final captions = _captions();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(c.tr('pickStatus'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (final s in captions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.send_rounded, color: AppColors.pink),
                    onTap: () => Navigator.pop(c, s),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;

    setState(() => _sharing = true);
    final copiedMsg = context.tr('statusCopied');
    try {
      // Nhiều app (Facebook, Zalo…) không nhận chữ điền sẵn khi chia sẻ ảnh,
      // nên ta sao chép lời khoe vào clipboard để người chơi dán vào.
      await Clipboard.setData(ClipboardData(text: chosen));
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final png = XFile.fromData(
        data!.buffer.asUint8List(),
        mimeType: 'image/png',
        name: 'mathjump_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      if (mounted) showToast(context, copiedMsg);
      await Share.shareXFiles([png], text: chosen);
    } catch (e) {
      if (mounted) showToast(context, context.tr('shareFailed', {'msg': e}));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final overtaken = _overtaken(s);
    final promoted = widget.promotedTo == null ? null : rankAt(widget.promotedTo!);
    final title = promoted != null
        ? context.tr('promoted', {'rank': '${promoted.emoji} ${context.tr(promoted.key)}'})
        : widget.newRecord
            ? context.tr('newRecordCongrats')
            : context.tr(widget.reason);

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Stack(children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                if (overtaken.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Pill(
                    text: context.tr('overtook', {'names': overtaken.join(', ')}),
                    color: AppColors.pink,
                    fontSize: 15,
                  ),
                ],
                const SizedBox(height: 16),
                RepaintBoundary(
                  key: _cardKey,
                  child: ResultCard(
                    result: widget.result,
                    newRecord: widget.newRecord,
                    best: s.best ?? widget.result,
                    playerName: s.profile?.name ?? '',
                    character: s.character,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 62,
                  width: double.infinity,
                  child: BubblyButton(
                    color: AppColors.pink,
                    onPressed: _sharing ? null : _share,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_sharing)
                        const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      else
                        const Text('🎉'),
                      const SizedBox(width: 10),
                      Text(context.tr('shareResult')),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 62,
                      child: BubblyButton(
                        color: AppColors.orange,
                        onPressed: () => startGame(context, replace: true),
                        child: FittedBox(child: Text('🔁 ${context.tr('playAgain')}')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 62,
                      child: BubblyButton(
                        color: AppColors.blue,
                        onPressed: () => Navigator.of(context).pop(),
                        child: FittedBox(child: Text('🏠 ${context.tr('home')}')),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                  icon: const Text('🏆', style: TextStyle(fontSize: 20)),
                  label: Text(context.tr('leaderboard'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
              ]),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                emissionFrequency: 0.06,
                gravity: 0.25,
                colors: const [
                  AppColors.pink,
                  AppColors.sun,
                  AppColors.blue,
                  AppColors.green,
                  AppColors.purple,
                  AppColors.orange,
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Bảng kết quả — cũng chính là ảnh được chia sẻ khi "Khoe kết quả".
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.result,
    required this.newRecord,
    required this.best,
    required this.playerName,
    required this.character,
  });

  final GameResult result;
  final bool newRecord;

  /// Kỷ lục hiện tại của người chơi (hạng + điểm).
  final GameResult best;
  final String playerName;
  final String character;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final rank = rankAt(result.rank);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3BF), Color(0xFFFFDEEB), Color(0xFFD0EBFF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 5),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Row(children: [
          Text(character, style: const TextStyle(fontSize: 52)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Math Jump',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.purple)),
              Text(playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
          Pill(text: '${rank.emoji} ${context.tr(rank.key)}', color: rank.color, fontSize: 15),
        ]),
        if (newRecord) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('🏆 ${context.tr('newRecord')}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Stat('⭐', context.tr('score'), '${result.score}', AppColors.orange)),
          const SizedBox(width: 10),
          Expanded(child: _Stat('🚀', context.tr('level'), '${result.level}', AppColors.purple)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _Stat('⏱️', context.tr('time'), fmtDuration(result.durationMs, lang),
                  AppColors.blue)),
          const SizedBox(width: 10),
          Expanded(
              child: _Stat('✅', context.tr('correct'), '${result.correct}', AppColors.green)),
        ]),
        const SizedBox(height: 12),
        Text(
          newRecord
              ? fmtDateTime(result.playedAt)
              : '${context.tr('yourBest', {
                  'rank': '${rankAt(best.rank).emoji} ${context.tr(rankAt(best.rank).key)}',
                  'score': best.score,
                })} • ${fmtDateTime(result.playedAt)}',
          style: TextStyle(color: AppColors.ink.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.emoji, this.label, this.value, this.color);
  final String emoji;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 3),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        FittedBox(
          child: Text(value,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        ),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
