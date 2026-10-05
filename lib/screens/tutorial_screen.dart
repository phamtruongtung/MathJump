import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/sound_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Hướng dẫn thực hành cho người mới: 2 bài làm thử (phải chọn đúng mới đi
/// tiếp được). Không tốn lượt chơi.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pages = PageController();
  int _page = 0;
  final _solved = <int>{};

  static const _count = 2;

  bool get _canGoNext => _solved.contains(_page);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int to) {
    _pages.animateToPage(to,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _next() {
    if (!_canGoNext) {
      showToast(context, context.tr('tSolveFirst'));
      return;
    }
    if (_page < _count - 1) {
      _go(_page + 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onSolved(int page) {
    setState(() => _solved.add(page));
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _count - 1;
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                Text('📖 ${context.tr('howToPlay')}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const Spacer(),
                if (!last)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('tSkip'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                // Trang thực hành chưa làm đúng thì không vuốt sang trang sau được.
                physics: _canGoNext
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _Page(
                    title: context.tr('t2Title'),
                    body: context.tr('t2Body'),
                    child: _Practice(
                      left: '2', op: '+', right: '?', result: '5',
                      choices: const ['3', '4', '1', '6'],
                      answer: '3',
                      onSolved: () => _onSolved(0),
                    ),
                  ),
                  _Page(
                    title: context.tr('t3Title'),
                    body: context.tr('t3Body'),
                    child: _Practice(
                      left: '6', op: '?', right: '2', result: '8',
                      choices: const ['+', '−', '×', '÷'],
                      answer: '+',
                      onSolved: () => _onSolved(1),
                    ),
                  ),
                ],
              ),
            ),
            // Chấm trang
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  width: i == _page ? 22 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.purple : Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(children: [
                if (_page > 0)
                  Expanded(
                    child: SizedBox(
                      height: 58,
                      child: BubblyButton(
                        color: Colors.white,
                        textColor: AppColors.ink,
                        fontSize: 18,
                        onPressed: () => _go(_page - 1),
                        child: Text('← ${context.tr('tBack')}'),
                      ),
                    ),
                  ),
                if (_page > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 58,
                    child: BubblyButton(
                      color: _canGoNext
                          ? (last ? AppColors.green : AppColors.purple)
                          : Colors.grey.shade400,
                      fontSize: 20,
                      onPressed: _next,
                      child: FittedBox(
                        child: Text(last ? '▶ ${context.tr('tStart')}' : '${context.tr('tNext')} →'),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.body, required this.child});
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(children: [
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.purple)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4)),
        ),
        const SizedBox(height: 24),
        child,
      ]),
    );
  }
}

class _Practice extends StatefulWidget {
  const _Practice({
    required this.left,
    required this.op,
    required this.right,
    required this.result,
    required this.choices,
    required this.answer,
    required this.onSolved,
  });

  final String left, op, right, result, answer;
  final List<String> choices;
  final VoidCallback onSolved;

  @override
  State<_Practice> createState() => _PracticeState();
}

class _PracticeState extends State<_Practice> {
  String? _picked;
  bool get _solved => _picked == widget.answer;

  void _pick(String c) {
    if (_solved) return;
    final sound = context.read<AppState>().sound;
    setState(() => _picked = c);
    if (c == widget.answer) {
      HapticFeedback.lightImpact();
      sound.play(Sfx.correct);
      widget.onSolved();
    } else {
      HapticFeedback.heavyImpact();
      sound.play(Sfx.wrong);
    }
  }

  Widget _token(String t) {
    const style = TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.ink);
    if (t != '?') {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(t, style: style));
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _solved ? AppColors.green : AppColors.sun,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.15), width: 3),
      ),
      child: Text(_solved ? widget.answer : '?',
          style: style.copyWith(color: _solved ? Colors.white : AppColors.ink)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wrong = _picked != null && !_solved;
    return Column(children: [
      Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: cardDecoration(),
        child: FittedBox(
          child: Row(children: [
            for (final t in [widget.left, widget.op, widget.right, '=', widget.result]) _token(t),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.1,
        children: [
          for (var i = 0; i < widget.choices.length; i++)
            Builder(builder: (_) {
              final c = widget.choices[i];
              var color = AppColors.choices[i];
              if (_solved && c == widget.answer) color = AppColors.green;
              if (wrong && c == _picked) color = AppColors.red;
              return BubblyButton(
                color: color,
                radius: 24,
                onPressed: () => _pick(c),
                child: FittedBox(child: Text(c, style: const TextStyle(fontSize: 38))),
              );
            }),
        ],
      ),
      const SizedBox(height: 12),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _picked == null
            ? const SizedBox(height: 30)
            : Text(
                _solved ? context.tr('tGood') : context.tr('tTryAgain'),
                key: ValueKey(_solved),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _solved ? AppColors.green : AppColors.red),
              ),
      ),
    ]);
  }
}
