import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _code = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    // Mở màn hình là làm mới lời mời & điểm của bạn bè.
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().sync());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final s = context.read<AppState>();
    FocusScope.of(context).unfocus();
    setState(() => _adding = true);
    final r = await s.addFriend(_code.text);
    if (!mounted) return;
    setState(() => _adding = false);
    if (r == FriendOp.sent || r == FriendOp.accepted) _code.clear();
    showToast(context, context.tr('fr_${r.name}'));
  }

  Future<void> _respond(FriendRequest req, bool accept) async {
    final ok = await context.read<AppState>().respondRequest(req, accept);
    if (!mounted) return;
    showToast(context, context.tr(ok ? (accept ? 'fr_accepted' : 'saved') : 'needOnline'));
  }

  Future<void> _remove(FriendEntry f) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('removeFriendQ', {'name': f.name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(c.tr('remove'))),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await context.read<AppState>().removeFriend(f);
    if (!ok && mounted) showToast(context, context.tr('needOnline'));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Column(children: [
            kidAppBar('👫 ${context.tr('friends')}', actions: const [
              Padding(padding: EdgeInsets.only(right: 12), child: OnlineBadge()),
            ]),
            Expanded(child: s.canUseCloud ? _body(s) : _needLogin()),
          ]),
        ),
      ),
    );
  }

  Widget _needLogin() => ListView(padding: const EdgeInsets.all(20), children: [
        const Text('🤝', textAlign: TextAlign.center, style: TextStyle(fontSize: 80)),
        Text(context.tr('needLogin'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        const GoogleLoginButton(height: 60, fontSize: 18),
      ]);

  Widget _body(AppState s) {
    final code = s.friendCode;
    return RefreshIndicator(
      onRefresh: s.sync,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Mã kết bạn của mình
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(color: const Color(0xFFFFF3BF)),
            child: Column(children: [
              Text(context.tr('myCode'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Text(code ?? (s.online ? '…' : context.tr('needOnline')),
                  style: TextStyle(
                      fontSize: code == null ? 15 : 40,
                      letterSpacing: code == null ? 0 : 6,
                      fontWeight: FontWeight.w900,
                      color: AppColors.purple)),
              if (code != null)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(context.tr('copy')),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      showToast(context, context.tr('codeCopied'));
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: Text(context.tr('shareCode')),
                    onPressed: () => Share.share(context.tr('shareCodeText', {'code': code})),
                  ),
                ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Thêm bạn
          Container(
            padding: const EdgeInsets.all(12),
            decoration: cardDecoration(),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: context.tr('enterCode'),
                    hintStyle: const TextStyle(fontSize: 15, letterSpacing: 0),
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              SizedBox(
                height: 52,
                child: BubblyButton(
                  color: AppColors.green,
                  fontSize: 17,
                  onPressed: _adding ? null : _add,
                  child: _adding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text('➕ ${context.tr('add')}'),
                ),
              ),
            ]),
          ),

          // Lời mời
          if (s.incoming.isNotEmpty) ...[
            _header('📩 ${context.tr('requests')}'),
            for (final r in s.incoming)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: cardDecoration(),
                child: Row(children: [
                  PlayerAvatar(name: r.name, photoUrl: r.photoUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.green),
                    tooltip: context.tr('accept'),
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () => _respond(r, true),
                  ),
                  IconButton(
                    tooltip: context.tr('decline'),
                    icon: const Icon(Icons.close_rounded, color: AppColors.red),
                    onPressed: () => _respond(r, false),
                  ),
                ]),
              ),
          ],

          // Danh sách bạn
          _header('💛 ${context.tr('myFriends')} (${s.friends.length})'),
          if (s.friends.isEmpty)
            Text(context.tr('noFriends'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final f in s.friends)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: cardDecoration(),
              child: Row(children: [
                PlayerAvatar(name: f.name, photoUrl: f.photoUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('⭐ ${f.bestScore} • ${context.tr('level')} ${f.bestLevel}',
                        style: TextStyle(color: AppColors.ink.withValues(alpha: 0.7))),
                  ]),
                ),
                IconButton(
                  tooltip: context.tr('remove'),
                  icon: Icon(Icons.person_remove_rounded,
                      color: AppColors.ink.withValues(alpha: 0.5)),
                  onPressed: () => _remove(f),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );
}
