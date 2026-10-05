import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../screens/game_screen.dart';
import '../services/ad_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

String fmtCountdown(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Bắt đầu một ván mới: dùng 1 lượt chơi, hết lượt thì mời xem quảng cáo.
/// [replace] = true khi gọi từ màn kết quả (thay màn hiện tại bằng ván mới).
Future<void> startGame(BuildContext context, {bool replace = false}) async {
  final s = context.read<AppState>();
  if (!s.useLife()) {
    final got = await _showNoLives(context);
    if (!got || !context.mounted || !s.useLife()) return;
  }
  final route = MaterialPageRoute(builder: (_) => const GameScreen());
  if (replace) {
    await Navigator.of(context).pushReplacement(route);
  } else {
    await Navigator.of(context).push(route);
  }
}

/// Thưởng 1 lượt sau khi xem quảng cáo. Trả về true nếu đã nhận lượt.
Future<bool> watchAdForLife(BuildContext context) async {
  final ok = await showRewardedAd(context);
  if (!ok || !context.mounted) return false;
  context.read<AppState>().addLife();
  showToast(context, context.tr('gotLife'));
  return true;
}

Future<bool> _showNoLives(BuildContext context) async {
  final watch = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(c.tr('noLivesTitle'),
          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const LivesBar(),
        const SizedBox(height: 12),
        _Ticker(
          builder: (_) => Text(
            c.tr('noLivesBody', {
              'time': fmtCountdown(
                  Provider.of<AppState>(c, listen: false).nextLifeIn ?? Duration.zero),
            }),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('close'))),
        SizedBox(
          height: 50,
          child: BubblyButton(
            color: AppColors.green,
            fontSize: 16,
            onPressed: () => Navigator.pop(c, true),
            child: Text('📺 ${c.tr('watchAd')}'),
          ),
        ),
      ],
    ),
  );
  if (watch != true || !context.mounted) return false;
  return watchAdForLife(context);
}

/// Hàng trái tim ❤️❤️🤍 + đồng hồ đếm ngược tới lượt kế tiếp.
class LivesBar extends StatelessWidget {
  const LivesBar({super.key, this.showAdButton = false});
  final bool showAdButton;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return _Ticker(builder: (context) {
      final lives = s.lives;
      final next = s.nextLifeIn;
      final hearts = [
        for (var i = 0; i < AppState.maxLives; i++) i < lives ? '❤️' : '🤍',
        if (lives > AppState.maxLives) '+${lives - AppState.maxLives}',
      ];
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Text(hearts.join(' '), style: const TextStyle(fontSize: 22)),
          Text(
            next == null ? context.tr('livesFull') : context.tr('nextLife', {'time': fmtCountdown(next)}),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          if (showAdButton && lives < AppState.maxLives)
            GestureDetector(
              onTap: () => watchAdForLife(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('📺 +1',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      );
    });
  }
}

/// Vẽ lại mỗi giây (cho đồng hồ đếm ngược).
class _Ticker extends StatefulWidget {
  const _Ticker({required this.builder});
  final WidgetBuilder builder;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
