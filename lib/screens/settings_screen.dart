import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

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
                if (p != null && p.isGuest)
                  _section(
                    context.tr('yourName'),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          maxLength: 20,
                          decoration: const InputDecoration(counterText: ''),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await s.setGuestName(_name.text);
                          if (context.mounted) showToast(context, context.tr('saved'));
                        },
                        child: Text(context.tr('save')),
                      ),
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
                        onTap: s.syncing ? null : s.sync,
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
                  ]),
                ),
                _section(
                  '📖 ${context.tr('howToPlay')}',
                  Text(context.tr('howToPlayBody'),
                      style: const TextStyle(fontSize: 15, height: 1.4)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
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
