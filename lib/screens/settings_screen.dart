import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../models/names.dart';
import 'login_screen.dart';
import 'tutorial_screen.dart';
import '../version.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<AppState>().profile?.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile;
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Column(children: [
            kidAppBar('⚙️ ${context.tr('settings')}'),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _section(context.tr('language'), const Center(child: LanguageSwitch())),
                _section(
                  context.tr('character'),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final z in kZodiac)
                        GestureDetector(
                          onTap: () => s.setCharacter(z.emoji),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 68,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: s.character == z.emoji ? AppColors.sun : AppColors.cream,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: s.character == z.emoji ? AppColors.orange : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Column(children: [
                              Text(z.emoji, style: const TextStyle(fontSize: 32)),
                              Text(context.lang == 'vi' ? z.vi : z.en,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
                _section(
                  '🔊 ${context.tr('sound')}',
                  Column(children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('music'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      secondary: const Text('🎵', style: TextStyle(fontSize: 24)),
                      value: s.sound.musicOn,
                      onChanged: s.setMusicOn,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('sfx'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      secondary: const Text('🔔', style: TextStyle(fontSize: 24)),
                      value: s.sound.sfxOn,
                      onChanged: s.setSfxOn,
                    ),
                  ]),
                ),
                if (p != null)
                  _section(
                    context.tr('displayName'),
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _name,
                            maxLength: displayNameMax,
                            decoration: InputDecoration(
                              counterText: '',
                              helperText: context.tr('displayNameHint'),
                            ),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final err = await s.setDisplayName(_name.text);
                            if (!context.mounted) return;
                            if (err == null) _name.text = s.profile?.name ?? _name.text;
                            showToast(context, context.tr(err ?? 'nameSaved'));
                          },
                          child: Text(context.tr('save')),
                        ),
                      ]),
                      if (s.canUseCloud) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.tr('searchableTitle'),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(context.tr('searchableDesc')),
                          value: s.searchable,
                          onChanged: s.setSearchable,
                        ),
                      ],
                    ]),
                  ),
                _section(
                  context.tr('account'),
                  Column(children: [
                    if (p != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PlayerAvatar(name: p.name, photoUrl: p.photoUrl),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(context.tr(p.isGuest ? 'guestAccount' : 'googleAccount')),
                      ),
                    if (p != null && p.isGuest)
                      const GoogleLoginButton(height: 54, fontSize: 17),
                    if (s.canUseCloud)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.sync_rounded),
                        title: Text(context.tr('syncNow')),
                        subtitle: Text(s.lastSync == null
                            ? context.tr('neverSynced')
                            : context.tr('lastSync', {'time': fmtDateTime(s.lastSync!)})),
                        trailing: s.syncing
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                        onTap: s.syncing ? null : () => s.sync(force: true),
                      ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      icon: const Icon(Icons.logout_rounded, color: AppColors.red),
                      label: Text(context.tr('logout'),
                          style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
                      onPressed: () async {
                        await s.signOut();
                        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                    ),
                    if (s.canUseCloud)
                      TextButton.icon(
                        icon: Icon(Icons.delete_forever_rounded,
                            color: AppColors.ink.withValues(alpha: 0.5)),
                        label: Text(context.tr('deleteAccount'),
                            style: TextStyle(
                                color: AppColors.ink.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w700)),
                        onPressed: () => _deleteAccount(context, s),
                      ),
                  ]),
                ),
                _section(
                  '📖 ${context.tr('howToPlay')}',
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(context.tr('howToPlayBody'),
                        style: const TextStyle(fontSize: 15, height: 1.4)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: BubblyButton(
                        color: AppColors.purple,
                        fontSize: 17,
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TutorialScreen())),
                        child: Text('🎓 ${context.tr('tReplay')}'),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'Math Jump • ${context.tr('version', {'v': kAppVersion})}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.ink.withValues(alpha: 0.6), fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, AppState s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('⚠️ ${c.tr('deleteTitle')}',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(c.tr('deleteBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('deleteConfirm'),
                style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;

    // Màn hình chờ trong lúc chọn lại tài khoản và xóa dữ liệu.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(c.tr('deleting'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
    final err = await s.deleteAccount();
    if (!context.mounted) return;
    Navigator.of(context).pop(); // đóng màn hình chờ

    if (err == null) {
      showToast(context, context.tr('deleted'));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (err.isNotEmpty) {
      showToast(
        context,
        switch (err) {
          'offline' => context.tr('needOnline'),
          'mismatch' => context.tr('deleteMismatch'),
          _ => context.tr('deleteFailed', {'msg': err}),
        },
      );
    }
  }

  Widget _section(String title, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}
