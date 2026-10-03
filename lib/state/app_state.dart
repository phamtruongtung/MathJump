import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../game/rank.dart';
import '../l10n/strings.dart';
import '../models/game_result.dart';
import '../models/social.dart';
import '../services/cloud_service.dart';
import '../services/local_store.dart';
import '../services/sound_service.dart';
import '../theme.dart';

class AppState extends ChangeNotifier {
  AppState(this.store, this.cloud, this.sound);

  final LocalStore store;
  final CloudService cloud;
  final SoundService sound;

  late String lang;
  late String character;
  Profile? profile;

  List<GameResult> history = [];
  GameResult? best;
  int gamesPlayed = 0;

  /// Hạng cao nhất đã mở khóa và hạng đang chọn để chơi.
  int maxRank = 0;
  int selectedRank = 0;
  List<FriendEntry> friends = [];
  List<FriendRequest> incoming = [];
  DateTime? lastSync;
  String? friendCode;

  bool online = false;
  bool syncing = false;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  bool get canUseCloud => cloud.ready && profile != null && !profile!.isGuest;

  Future<void> init() async {
    lang = store.lang;
    final saved = store.character;
    character = kZodiac.any((z) => z.emoji == saved)
        ? saved!
        : zodiacOfYear(DateTime.now().year);
    await sound.init(musicOn: store.musicOn, sfxOn: store.sfxOn);

    final user = cloud.currentUser;
    if (user != null) {
      profile = Profile(
        id: user.uid,
        name: user.displayName ?? 'Player',
        photoUrl: user.photoURL,
        isGuest: false,
      );
    } else if (store.guestChosen) {
      profile = _guestProfile();
    }
    _loadProfileData();

    final conn = Connectivity();
    _connSub = conn.onConnectivityChanged.listen(_onConnectivity);
    try {
      _onConnectivity(await conn.checkConnectivity());
    } catch (_) {}
  }

  void _onConnectivity(List<ConnectivityResult> r) {
    final now = r.any((e) => e != ConnectivityResult.none);
    final wasOnline = online;
    online = now;
    notifyListeners();
    // Vừa có mạng trở lại → cập nhật kết quả của bạn bè.
    if (now && !wasOnline) unawaited(sync());
  }

  Profile _guestProfile() => Profile(
        id: Profile.guestId,
        name: store.guestName ?? trLang(lang, 'guestName'),
        isGuest: true,
      );

  void _loadProfileData() {
    final p = profile;
    if (p == null) {
      history = [];
      best = null;
      gamesPlayed = 0;
      friends = [];
      incoming = [];
      lastSync = null;
      friendCode = null;
      maxRank = 0;
      selectedRank = 0;
      return;
    }
    history = store.history(p.id);
    best = store.best(p.id);
    gamesPlayed = store.gamesPlayed(p.id);
    maxRank = store.maxRank(p.id).clamp(0, kRanks.length - 1);
    selectedRank = (store.selectedRank(p.id) ?? maxRank).clamp(0, maxRank);
    friends = store.friends(p.id);
    lastSync = store.lastSync(p.id);
    friendCode = store.friendCode(p.id);
    incoming = [];
  }

  // ---------------- Settings ----------------

  Future<void> setLang(String v) async {
    lang = v;
    await store.setLang(v);
    if (profile?.isGuest == true && store.guestName == null) profile = _guestProfile();
    notifyListeners();
  }

  Future<void> setCharacter(String v) async {
    character = v;
    await store.setCharacter(v);
    notifyListeners();
  }

  Future<void> setMusicOn(bool v) async {
    await store.setMusicOn(v);
    await sound.setMusicOn(v);
    notifyListeners();
  }

  Future<void> setSfxOn(bool v) async {
    await store.setSfxOn(v);
    sound.setSfxOn(v);
    notifyListeners();
  }

  Future<void> setSelectedRank(int v) async {
    final p = profile;
    if (p == null || v < 0 || v > maxRank) return;
    selectedRank = v;
    await store.setSelectedRank(p.id, v);
    notifyListeners();
  }

  /// Mở khóa hạng mới (gọi khi người chơi đạt điều kiện thăng hạng trong ván).
  /// Ván sau sẽ tự chọn hạng mới.
  void unlockRank(int v) {
    final p = profile;
    if (p == null || v <= maxRank || v >= kRanks.length) return;
    maxRank = v;
    selectedRank = v;
    unawaited(store.setMaxRank(p.id, v));
    unawaited(store.setSelectedRank(p.id, v));
    notifyListeners();
  }

  Future<void> setGuestName(String v) async {
    final name = v.trim();
    if (name.isEmpty) return;
    await store.setGuestName(name);
    if (profile?.isGuest == true) profile = _guestProfile();
    notifyListeners();
  }

  // ---------------- Auth ----------------

  Future<void> playAsGuest() async {
    await store.setGuestChosen(true);
    profile = _guestProfile();
    _loadProfileData();
    notifyListeners();
  }

  /// null = thành công, '' = người dùng hủy, 'firebaseMissing' = chưa cấu hình,
  /// còn lại là thông báo lỗi.
  Future<String?> signInWithFacebook() async {
    if (!cloud.ready) return 'firebaseMissing';
    try {
      final u = await cloud.signInWithFacebook();
      final np = Profile(
        id: u.uid,
        name: u.displayName ?? 'Player',
        photoUrl: u.photoURL,
        isGuest: false,
      );
      // Lần đầu đăng nhập trên máy này: mang theo thành tích chơi chế độ khách.
      if (!store.hasData(np.id) && store.hasData(Profile.guestId)) {
        await store.copyProfileData(Profile.guestId, np.id);
      }
      profile = np;
      _loadProfileData();
      notifyListeners();
      unawaited(sync());
      return null;
    } on AuthCancelled {
      return '';
    } catch (e) {
      debugPrint('[Auth] $e');
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await cloud.signOut();
    await store.setGuestChosen(false);
    profile = null;
    _loadProfileData();
    notifyListeners();
  }

  // ---------------- Game results ----------------

  /// Lưu kết quả vào máy. Trả về true nếu đây là kỷ lục mới.
  bool recordResult(GameResult r) {
    final p = profile;
    if (p == null) return false;
    final isRecord = r.beats(best);
    history = [r, ...history].take(100).toList();
    gamesPlayed++;
    if (isRecord) best = r;
    unawaited(store.setHistory(p.id, history));
    unawaited(store.setGamesPlayed(p.id, gamesPlayed));
    if (isRecord) unawaited(store.setBest(p.id, r));
    notifyListeners();
    unawaited(sync());
    return isRecord;
  }

  /// Bạn bè + chính mình, sắp xếp theo điểm cao nhất.
  List<FriendEntry> get leaderboard {
    final p = profile;
    if (p == null) return [];
    final me = FriendEntry(
      uid: p.id,
      name: p.name,
      photoUrl: p.photoUrl,
      bestScore: best?.score ?? 0,
      bestLevel: best?.level ?? 0,
      bestTimeMs: best?.durationMs ?? 0,
      bestRank: best?.rank ?? 0,
      isMe: true,
    );
    final list = [...friends.where((f) => f.uid != p.id), me];
    list.sort((x, y) {
      final r = y.bestRank.compareTo(x.bestRank);
      if (r != 0) return r;
      final s = y.bestScore.compareTo(x.bestScore);
      if (s != 0) return s;
      final l = y.bestLevel.compareTo(x.bestLevel);
      if (l != 0) return l;
      if (x.isMe == y.isMe) return x.name.compareTo(y.name);
      return x.isMe ? -1 : 1;
    });
    return list;
  }

  // ---------------- Sync ----------------

  Future<void> sync() async {
    final p = profile;
    if (!canUseCloud || !online || syncing || p == null) return;
    syncing = true;
    notifyListeners();
    try {
      final code = await cloud.ensureProfile(uid: p.id, name: p.name, photoUrl: p.photoUrl);
      if (code != null) {
        friendCode = code;
        await store.setFriendCode(p.id, code);
      }
      final remote = await cloud.syncBest(
          uid: p.id, localBest: best, gamesPlayed: gamesPlayed, maxRank: maxRank);
      if (remote.best != null) {
        best = remote.best;
        await store.setBest(p.id, remote.best!);
      }
      if (remote.maxRank > maxRank) {
        maxRank = remote.maxRank.clamp(0, kRanks.length - 1);
        await store.setMaxRank(p.id, maxRank);
      }
      friends = await cloud.fetchFriends(p.id);
      await store.setFriends(p.id, friends);
      incoming = await cloud.fetchIncoming(p.id);
      lastSync = DateTime.now();
      await store.setLastSync(p.id, lastSync!);
    } catch (e) {
      debugPrint('[Sync] $e');
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<FriendOp> addFriend(String code) async {
    final p = profile;
    if (!canUseCloud || p == null) return FriendOp.error;
    if (!online) return FriendOp.offline;
    final r = await cloud.sendRequest(
        uid: p.id, name: p.name, photoUrl: p.photoUrl, code: code);
    if (r == FriendOp.accepted) unawaited(sync());
    return r;
  }

  Future<bool> respondRequest(FriendRequest req, bool accept) async {
    final p = profile;
    if (!canUseCloud || p == null || !online) return false;
    try {
      if (accept) {
        await cloud.accept(uid: p.id, fromUid: req.fromUid);
      } else {
        await cloud.decline(uid: p.id, fromUid: req.fromUid);
      }
      incoming = incoming.where((r) => r.fromUid != req.fromUid).toList();
      notifyListeners();
      if (accept) unawaited(sync());
      return true;
    } catch (e) {
      debugPrint('[Friends] $e');
      return false;
    }
  }

  Future<bool> removeFriend(FriendEntry f) async {
    final p = profile;
    if (!canUseCloud || p == null || !online) return false;
    try {
      await cloud.removeFriend(uid: p.id, friendUid: f.uid);
      friends = friends.where((e) => e.uid != f.uid).toList();
      await store.setFriends(p.id, friends);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Friends] $e');
      return false;
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}
