import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/question.dart';
import '../l10n/strings.dart';
import '../models/game_result.dart';
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
  late final AnimationController _timer;

  int _level = 1;
  int _score = 0;
  int _levelPoints = 0;
  int _correct = 0;
  int _lastGain = 0;
  late Question _q;

  String? _picked;
  bool _over = false;
  bool _paused = false;
  bool _pendingNext = false;
  bool _showLevelUp = false;
  String _reason = 'wrong';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = AnimationController(vsync: this)
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed && !_over) _gameOver('timeUp');
      });
    _q = QuestionGenerator.generate(_level, _rng);
    _watch.start();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tự tạm dừng khi bé chuyển sang app khác để không bị mất lượt oan.
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _startTimer() {
    _timer.duration =
        Duration(milliseconds: (LevelConfig(_level).timeLimit * 1000).round());
    _timer.forward(from: 0);
  }

  void _nextQuestion() {
    setState(() {
      _q = QuestionGenerator.generate(_level, _rng, avoid: _q);
      _picked = null;
    });
    _startTimer();
  }

  void _onPick(String choice) {
    if (_over || _paused || _picked != null) return;
    if (choice != _q.answer) {
      HapticFeedback.heavyImpact();
      setState(() => _picked = choice);
      _gameOver('wrong');
      return;
    }

    HapticFeedback.lightImpact();
    _timer.stop();
    final gain = 10 + ((1 - _timer.value) * 5).round(); // nhanh thì thêm tối đa 5 điểm
    final cfg = LevelConfig(_level);
    var levelUp = false;
    setState(() {
      _picked = choice;
      _score += gain;
      _lastGain = gain;
      _levelPoints += gain;
      _correct++;
      if (_levelPoints >= cfg.pointsToNext) {
        _levelPoints -= cfg.pointsToNext;
        _level++;
        levelUp = true;
        _showLevelUp = true;
      }
    });
    if (levelUp) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _showLevelUp = false);
      });
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

  void _gameOver(String reason) {
    if (_over) return;
    _timer.stop();
    _watch.stop();
    HapticFeedback.vibrate();
    setState(() {
      _over = true;
      _reason = reason;
    });
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      final result = GameResult(
        score: _score,
        level: _level,
        correct: _correct,
        durationMs: _watch.elapsedMilliseconds,
        playedAt: DateTime.now(),
      );
      final app = context.read<AppState>();
      final previousBest = app.best;
      final isRecord = app.recordResult(result);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: result,
          newRecord: isRecord,
          previousBest: previousBest,
          reason: reason,
        ),
      ));
    });
  }

  void _pause() {
    if (_over || _paused || !mounted) return;
    _timer.stop();
    _watch.stop();
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) return;
    setState(() => _paused = false);
    _watch.start();
    if (_pendingNext) {
      _pendingNext = false;
      _nextQuestion();
    } else if (_picked == null) {
      _timer.forward();
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
                  child: _TimerBar(controller: _timer),
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
                        if (_showLevelUp) Center(child: _LevelUpBanner(level: _level)),
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
        Pill(text: '${context.tr('level')} $_level', color: AppColors.purple),
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
        Pill(text: '⭐ $_score', color: AppColors.orange),
      ]),
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
    final goal = LevelConfig(_level).pointsToNext;
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

class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final remaining = 1 - controller.value;
        final secs = (controller.duration?.inMilliseconds ?? 0) * remaining / 1000;
        final color = Color.lerp(AppColors.red, AppColors.green, remaining)!;
        return Row(children: [
          const Text('⏰', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: remaining.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(secs.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ]);
      },
    );
  }
}

class _LevelUpBanner extends StatelessWidget {
  const _LevelUpBanner({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
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
        child: Text(context.tr('levelUp', {'level': level}),
            style: const TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
