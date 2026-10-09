import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/question.dart';
import '../game/rank.dart';
import '../l10n/strings.dart';
import '../models/game_result.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/climber_view.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _rng = Random();
  final _watch = Stopwatch();

  // ---- Quỹ thời gian ----
  // Mỗi câu có thời gian riêng [_qTime]. Trong thời gian riêng, quỹ không bị
  // trừ. Trả lời đúng: phần dư cộng vào quỹ. Quá thời gian riêng: trừ dần vào
  // quỹ. Quỹ về 0 → dùng ⏱️ Thêm giờ hoặc thua. Thông số chọn bằng mô phỏng
  // (tools/simulate_timebank.js).
  static const _startBank = 20.0;
  static const _levelBonus = 5.0;
  static const _rankBonus = 20.0;

  late final Ticker _ticker = createTicker(_onTick);
  Duration? _lastTick;
  bool _clockRunning = false;
  bool _outOfTimeOpen = false;
  double _qTime = 1;
  double _bank = _startBank; // quỹ lúc bắt đầu câu hiện tại
  final _qElapsed = ValueNotifier<double>(0); // giây đã dùng cho câu hiện tại

  double get _bankLeft => _bank - max(0.0, _qElapsed.value - _qTime);

  late final AppState _app = context.read<AppState>();

  /// Hạng đang chơi — thăng hạng giữa ván thì đổi ngay sang hạng mới.
  late int _rank = _app.selectedRank;

  /// Hạng cao nhất vừa thăng trong ván này (null nếu không thăng).
  int? _promotedTo;
  String? _banner;

  // Level, điểm và số câu đúng tính trong hạng hiện tại (về 0 khi thăng hạng).
  int _level = 1;
  int _score = 0;
  int _levelPoints = 0;
  int _rankCorrect = 0;

  /// Tổng số câu đúng cả ván = số bậc nhân vật đã leo.
  int _correct = 0;
  int _lastGain = 0;
  late Question _q;

  String? _picked;
  bool _over = false;
  bool _paused = false;
  bool _pendingNext = false;
  String _reason = 'wrong';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _q = QuestionGenerator.generate(_level, _rng, rank: _rank);
    _watch.start();
    _startQuestionClock();
    _ticker.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _qElapsed.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tự tạm dừng khi bé chuyển sang app khác để không bị mất lượt oan.
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _startQuestionClock() {
    _qTime = LevelConfig(_level, rank: _rank).timeFor(_q);
    _qElapsed.value = 0;
    _lastTick = null;
    _clockRunning = true;
  }

  void _onTick(Duration now) {
    final dt = _lastTick == null ? 0.0 : (now - _lastTick!).inMicroseconds / 1e6;
    _lastTick = now;
    if (!_clockRunning || _over || _paused) return;
    _qElapsed.value += dt;
    if (_bankLeft <= 0) _onOutOfTime();
  }

  /// Quỹ về 0: mời dùng ⏱️ Thêm giờ (hoặc xem quảng cáo để nhận), không thì thua.
  Future<void> _onOutOfTime() async {
    if (_outOfTimeOpen || _over) return;
    _outOfTimeOpen = true;
    _clockRunning = false;
    _watch.stop();
    HapticFeedback.heavyImpact();
    var extended = false;
    while (mounted && !_over) {
      final action = await _askExtraTime();
      if (!mounted) return;
      if (action == 'use' && _app.useExtraTime()) {
        extended = true;
        break;
      }
      if (action == 'ad') {
        final ok = await showRewardedAd(context);
        if (!mounted) return;
        if (ok && _app.claimAdExtraTime() && _app.useExtraTime()) {
          extended = true;
          break;
        }
        continue; // không xem được quảng cáo: hỏi lại
      }
      break; // 'end'
    }
    _outOfTimeOpen = false;
    if (!mounted || _over) return;
    if (!extended) {
      _gameOver('timeUp');
      return;
    }
    // Quỹ còn đúng 15 giây, chơi tiếp câu hiện tại.
    setState(() => _bank = (_qElapsed.value - _qTime) + AppState.extraTimeSeconds);
    _app.sound.play(Sfx.levelup);
    _watch.start();
    _lastTick = null;
    _clockRunning = !_paused;
  }

  Future<String> _askExtraTime() async {
    final have = _app.extraTimes;
    final adLeft = _app.adExtraLeftToday;
    final r = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('⏰ ${c.tr('outOfTimeTitle')}',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
            c.tr(have > 0 ? 'outOfTimeHave' : 'outOfTimeNone',
                {'n': have, 's': AppState.extraTimeSeconds}),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowDirection: VerticalDirection.up,
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 'end'), child: Text(c.tr('endGame'))),
            if (have > 0)
              SizedBox(
                height: 50,
                child: BubblyButton(
                  color: AppColors.green,
                  fontSize: 16,
                  onPressed: () => Navigator.pop(c, 'use'),
                  child: Text('⏱️ ${c.tr('useExtra', {'s': AppState.extraTimeSeconds})}'),
                ),
              )
            else if (adLeft > 0)
              SizedBox(
                height: 50,
                child: BubblyButton(
                  color: AppColors.green,
                  fontSize: 16,
                  onPressed: () => Navigator.pop(c, 'ad'),
                  child: Text('📺 ${c.tr('adForExtra')}'),
                ),
              ),
          ],
        ),
      ),
    );
    return r ?? 'end';
  }

  void _nextQuestion() {
    setState(() {
      _q = QuestionGenerator.generate(_level, _rng, rank: _rank, avoid: _q);
      _picked = null;
    });
    _startQuestionClock();
  }

  void _onPick(String choice) {
    if (_over || _paused || _picked != null) return;
    _clockRunning = false;
    if (choice != _q.answer) {
      HapticFeedback.heavyImpact();
      setState(() => _picked = choice);
      _gameOver('wrong');
      return;
    }

    HapticFeedback.lightImpact();
    _app.sound.play(Sfx.correct);
    final used = _qElapsed.value;
    // Nhanh thì thêm tối đa 5 điểm.
    final gain = 10 + (max(0.0, _qTime - used) / _qTime * 5).round();
    final cfg = LevelConfig(_level, rank: _rank);
    var levelUp = false;
    setState(() {
      _picked = choice;
      // Phần thời gian riêng còn dư cộng vào quỹ (quá giờ thì đã bị trừ).
      _bank += _qTime - used;
      _score += gain;
      _lastGain = gain;
      _levelPoints += gain;
      _correct++;
      _rankCorrect++;
      if (_levelPoints >= cfg.pointsToNext) {
        _levelPoints -= cfg.pointsToNext;
        _level++;
        levelUp = true;
        _bank += _levelBonus;
      }
    });

    // Thăng hạng (chỉ khi đang chơi ở hạng cao nhất đã mở khóa): chuyển ngay
    // sang hạng mới, bắt đầu lại từ level 1 với 0 điểm, ván chơi tiếp tục.
    final rank = rankAt(_rank);
    if (_rank == _app.maxRank && rank.canPromote(_level, _score)) {
      final next = _rank + 1;
      _app.unlockRank(next);
      HapticFeedback.mediumImpact();
      _app.sound.play(Sfx.record);
      setState(() {
        _rank = next;
        _promotedTo = next;
        _level = 1;
        _score = 0;
        _levelPoints = 0;
        _rankCorrect = 0;
        _bank += _rankBonus;
      });
      final r = rankAt(next);
      _showBanner(
          '${r.emoji} ${context.tr('rankUp', {'rank': context.tr(r.key)})} +${_rankBonus.round()}s');
    } else if (levelUp) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 120), () => _app.sound.play(Sfx.levelup));
      _showBanner('${context.tr('levelUp', {'level': _level})} +${_levelBonus.round()}s');
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _over) return;
      if (_paused) {
        _pendingNext = true;
        return;
      }
      _nextQuestion();
    });
  }

  void _showBanner(String text) {
    setState(() => _banner = text);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _banner == text) setState(() => _banner = null);
    });
  }

  void _gameOver(String reason) {
    if (_over) return;
    _clockRunning = false;
    _watch.stop();
    HapticFeedback.vibrate();
    _app.sound.play(Sfx.wrong);
    setState(() {
      _over = true;
      _reason = reason;
    });
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      // Kết quả tính theo hạng cuối cùng đạt được trong ván.
      final result = GameResult(
        score: _score,
        level: _level,
        correct: _rankCorrect,
        durationMs: _watch.elapsedMilliseconds,
        playedAt: DateTime.now(),
        rank: _rank,
      );
      final previousBest = _app.best;
      final isRecord = _app.recordResult(result);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: result,
          newRecord: isRecord,
          previousBest: previousBest,
          reason: reason,
          promotedTo: _promotedTo,
        ),
      ));
    });
  }

  void _pause() {
    if (_over || _paused || !mounted) return;
    _clockRunning = false;
    _watch.stop();
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) return;
    setState(() => _paused = false);
    _lastTick = null;
    if (_outOfTimeOpen) return; // hộp "Hết giờ" đang mở: chờ người chơi chọn
    _watch.start();
    if (_pendingNext) {
      _pendingNext = false;
      _nextQuestion();
    } else if (_picked == null) {
      _clockRunning = true;
    }
  }

  Future<void> _confirmQuit() async {
    final wasPaused = _paused;
    _pause();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(c.tr('quitTitle'), style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(c.tr('quitBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(c.tr('quit'))),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      Navigator.of(context).pop();
    } else if (!wasPaused) {
      _resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = context.select<AppState, String>((s) => s.character);
    return PopScope(
      canPop: _over,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_over) _confirmQuit();
      },
      child: Scaffold(
        body: SkyBackground(
          child: SafeArea(
            child: Stack(children: [
              Column(children: [
                _topBar(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _timeBars(),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(fit: StackFit.expand, children: [
                        Container(color: Colors.white.withValues(alpha: 0.35)),
                        ClimberView(step: _correct, character: character, fallen: _over),
                        if (_banner != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: _Banner(text: _banner!),
                            ),
                          ),
                        if (_over)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Pill(text: context.tr(_reason), color: AppColors.red, fontSize: 20),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
                _equation(),
                Expanded(flex: 6, child: _choices()),
                _levelProgress(),
              ]),
              if (_paused) _pauseOverlay(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: IconButton(
            icon: const Icon(Icons.pause_rounded, color: AppColors.ink),
            onPressed: _over ? null : _pause,
          ),
        ),
        const SizedBox(width: 8),
        Pill(text: rankAt(_rank).emoji, color: rankAt(_rank).color),
        const SizedBox(width: 6),
        Pill(text: 'Lv $_level', color: AppColors.purple),
        const Spacer(),
        if (_correct > 0)
          TweenAnimationBuilder<double>(
            key: ValueKey(_correct),
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 900),
            builder: (_, v, __) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, -12 * (1 - v)),
                child: Text('+$_lastGain',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.green)),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Pill(text: '⏱️×${context.select<AppState, int>((s) => s.extraTimes)}',
            color: AppColors.blue, fontSize: 15),
        const SizedBox(width: 6),
        Pill(text: '⭐ $_score', color: AppColors.orange),
      ]),
    );
  }

  /// Quỹ thời gian ⏳ (lớn) + thanh thời gian riêng của câu hiện tại.
  Widget _timeBars() {
    return ValueListenableBuilder<double>(
      valueListenable: _qElapsed,
      builder: (context, elapsed, _) {
        final qLeft = max(0.0, _qTime - elapsed);
        final draining = elapsed > _qTime && _picked == null && !_over;
        final bankLeft = max(0.0, _bank - max(0.0, elapsed - _qTime));
        final low = draining || bankLeft < 5;
        final frac = (qLeft / _qTime).clamp(0.0, 1.0);
        return Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: low ? AppColors.red : AppColors.purple,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text('⏳ ${bankLeft.toStringAsFixed(1)}s',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 14,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.lerp(AppColors.orange, AppColors.green, frac),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            child: Text(qLeft.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ]);
      },
    );
  }

  Widget _equation() {
    final tokens = <(String, Slot?)>[
      ('${_q.a}', Slot.a),
      (_q.op.symbol, Slot.op),
      ('${_q.b}', Slot.b),
      ('=', null),
      ('${_q.c}', Slot.c),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      height: 88,
      decoration: cardDecoration(),
      child: FittedBox(
        child: Row(
          children: [for (final (text, slot) in tokens) _token(text, slot)],
        ),
      ),
    );
  }

  Widget _token(String text, Slot? slot) {
    const style = TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: AppColors.ink);
    if (slot != _q.missing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(text, style: style),
      );
    }
    final solved = _picked == _q.answer;
    final reveal = solved || _over;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: reveal ? AppColors.green : AppColors.sun,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.15), width: 3),
      ),
      child: Text(reveal ? _q.answer : '?',
          style: style.copyWith(color: reveal ? Colors.white : AppColors.ink)),
    );
  }

  Widget _choices() {
    Widget row(int i, int j) => Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _choice(i)),
            const SizedBox(width: 14),
            Expanded(child: _choice(j)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(children: [row(0, 1), const SizedBox(height: 14), row(2, 3)]),
    );
  }

  Widget _choice(int i) {
    final label = _q.choices[i];
    var color = AppColors.choices[i];
    if (_picked != null || _over) {
      if (label == _q.answer && (_over || _picked == label)) {
        color = AppColors.green;
      } else if (label == _picked) {
        color = AppColors.red;
      } else if (_over) {
        color = Colors.grey.shade400;
      }
    }
    final locked = _over || _paused || _picked != null;
    return BubblyButton(
      color: color,
      radius: 26,
      onPressed: locked ? null : () => _onPick(label),
      child: FittedBox(
        child: Text(label, style: TextStyle(fontSize: _q.isOperator ? 60 : 46)),
      ),
    );
  }

  Widget _levelProgress() {
    final goal = LevelConfig(_level, rank: _rank).pointsToNext;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(children: [
        const Text('🏁', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_levelPoints / goal).clamp(0.0, 1.0),
              minHeight: 12,
              color: AppColors.purple,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(context.tr('nextLevel', {'cur': _levelPoints, 'goal': goal}),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _pauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: cardDecoration(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('😴', style: TextStyle(fontSize: 56)),
            Text(context.tr('paused'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              width: double.infinity,
              child: BubblyButton(
                color: AppColors.green,
                onPressed: _resume,
                child: Text(context.tr('resume')),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _confirmQuit, child: Text(context.tr('quit'))),
          ]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.pink, AppColors.purple]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: FittedBox(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
