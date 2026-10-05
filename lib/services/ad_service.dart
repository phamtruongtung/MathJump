import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme.dart';

/// Quảng cáo có thưởng (xem hết thì được +1 lượt chơi).
///
/// Bản hiện tại CHƯA có quảng cáo thật: chỉ hiện màn hình chờ 5 giây rồi tặng
/// lượt. Khi tích hợp quảng cáo (ví dụ Google AdMob rewarded ad), chỉ cần thay
/// phần thân hàm này; trả về true khi người xem đã xem hết quảng cáo.
Future<bool> showRewardedAd(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _FakeAdDialog(),
  );
  return ok == true;
}

class _FakeAdDialog extends StatefulWidget {
  const _FakeAdDialog();

  @override
  State<_FakeAdDialog> createState() => _FakeAdDialogState();
}

class _FakeAdDialogState extends State<_FakeAdDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) Navigator.of(context).pop(true);
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('📺', style: TextStyle(fontSize: 56)),
        Text(context.tr('adPlaying'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(context.tr('adDemo'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.ink.withValues(alpha: 0.6))),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _c.value,
                minHeight: 12,
                color: AppColors.green,
                backgroundColor: AppColors.cream,
              ),
            ),
            const SizedBox(height: 6),
            Text('${(5 - _c.value * 5).ceil()}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        ),
      ]),
    );
  }
}
