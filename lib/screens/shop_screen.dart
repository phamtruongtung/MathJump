import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/ad_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Cửa hàng vật phẩm. Hiện có ⏱️ Thêm giờ: nhận bằng xem quảng cáo (giới hạn
/// mỗi ngày) hoặc mua bằng tiền (sẽ có khi game lên Google Play).
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  Future<void> _watchAd(BuildContext context) async {
    final s = context.read<AppState>();
    if (s.adExtraLeftToday <= 0) {
      showToast(context, context.tr('adLimitReached'));
      return;
    }
    final ok = await showRewardedAd(context);
    if (!ok || !context.mounted) return;
    showToast(context, context.tr(s.claimAdExtraTime() ? 'gotExtra' : 'adLimitReached'));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final adLeft = s.adExtraLeftToday;
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Column(children: [
            kidAppBar('🛒 ${context.tr('shop')}'),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: cardDecoration(),
                  child: Column(children: [
                    const Text('⏱️', style: TextStyle(fontSize: 64)),
                    Text(context.tr('extraTimeName'),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('extraTimeDesc', {'s': AppState.extraTimeSeconds}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Pill(
                      text: context.tr('youHave', {'n': s.extraTimes}),
                      color: AppColors.blue,
                      fontSize: 18,
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Nhận bằng quảng cáo
                SizedBox(
                  height: 62,
                  child: BubblyButton(
                    color: adLeft > 0 ? AppColors.green : Colors.grey.shade400,
                    fontSize: 19,
                    onPressed: () => _watchAd(context),
                    child: Text('📺 ${context.tr('watchAdGet')}'),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('adLeftToday', {'n': adLeft, 'max': AppState.adExtraPerDay}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),

                // Mua bằng tiền (chưa mở)
                Row(children: [
                  for (final (n, price) in const [(5, '10.000đ'), (15, '25.000đ')]) ...[
                    Expanded(child: _Pack(count: n, price: price)),
                    if (n == 5) const SizedBox(width: 12),
                  ],
                ]),
                const SizedBox(height: 10),
                Text(
                  context.tr('buyNote'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.ink.withValues(alpha: 0.6)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Pack extends StatelessWidget {
  const _Pack({required this.count, required this.price});
  final int count;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(children: [
          Text('⏱️ ×$count', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          Text(context.tr('buyPack', {'n': count}),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(price,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.orange)),
          const SizedBox(height: 6),
          Pill(text: context.tr('comingSoon'), color: Colors.grey, fontSize: 13),
        ]),
      ),
    );
  }
}
