import 'dart:async';
import 'dart:math';

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

  /// Bạn bè vừa vượt kỷ lục của mình (hiện thông báo ở trang chủ).
  List<FriendEntry> overtakeAlerts = [];

  // Lượt chơi: tối đa 3 lượt miễn phí, hồi 1 lượt mỗi 30 phút.
  static const maxLives = 3;
  static const lifeRegen = Duration(minutes: 30);
  int _lives = maxLives;
  DateTime? _livesSince;
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
    await store.migrateRanks(kRankSchemaVersion);
    _lives = store.lives ?? maxLives;
    _livesSince = store.livesSince;

    final user = cloud.currentUser;
    if (user != null) {
      await store.setLastAccountId(user.uid);
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
    _pulledThisSession = false;
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
      overtakeAlerts = [];
      return;
    }
    overtakeAlerts = store.overtakeAlerts(p.id);
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

  // ---------------- Hướng dẫn ----------------

  /// Người mới (chưa xem hướng dẫn, chưa chơi ván nào) thì tự mở hướng dẫn.
  bool get shouldShowTutorial => !store.tutorialSeen && gamesPlayed == 0 && history.isEmpty;

  /// Đánh dấu đã xem (gọi ngay khi mở, không notify vì có thể đang build).
  void markTutorialSeen() => unawaited(store.setTutorialSeen());

  // ---------------- Vật phẩm ⏱️ Thêm giờ ----------------

  /// Mỗi vật phẩm cộng thêm bao nhiêu giây khi quỹ thời gian về 0.
  static const extraTimeSeconds = 15;

  /// Số lần tối đa nhận Thêm giờ bằng xem quảng cáo mỗi ngày.
  static const adExtraPerDay = 3;

  int get extraTimes => store.extraTimes;

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int get adExtraLeftToday => max(0, adExtraPerDay - store.adExtraCount(_today()));

  void addExtraTimes(int n) {
    unawaited(store.setExtraTimes(extraTimes + n));
    notifyListeners();
  }

  /// Dùng 1 vật phẩm. false nếu không còn.
  bool useExtraTime() {
    if (extraTimes <= 0) return false;
    unawaited(store.setExtraTimes(extraTimes - 1));
    notifyListeners();
    return true;
  }

  /// Ghi nhận đã xem quảng cáo để nhận 1 vật phẩm. false nếu hết lượt hôm nay.
  bool claimAdExtraTime() {
    final day = _today();
    final used = store.adExtraCount(day);
    if (used >= adExtraPerDay) return false;
    unawaited(store.setAdExtraCount(day, used + 1));
    addExtraTimes(1);
    return true;
  }

  // ---------------- Lượt chơi ----------------

  int get lives {
    _refillLives();
    return _lives;
  }

  /// Thời gian còn lại tới khi hồi thêm 1 lượt (null khi đã đầy).
  Duration? get nextLifeIn {
    _refillLives();
    final since = _livesSince;
    if (since == null) return null;
    final left = since.add(lifeRegen).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _refillLives() {
    if (_lives >= maxLives) {
      if (_livesSince != null) {
        _livesSince = null;
        unawaited(store.setLivesSince(null));
      }
      return;
    }
    final since = _livesSince ?? DateTime.now();
    if (_livesSince == null) {
      _livesSince = since;
      unawaited(store.setLivesSince(since));
    }
    final gained = DateTime.now().difference(since).inMilliseconds ~/ lifeRegen.inMilliseconds;
    if (gained <= 0) return;
    _lives = min(maxLives, _lives + gained);
    _livesSince = _lives >= maxLives ? null : since.add(lifeRegen * gained);
    unawaited(store.setLives(_lives));
    unawaited(store.setLivesSince(_livesSince));
  }

  /// Dùng 1 lượt để bắt đầu ván. false nếu đã hết lượt.
  bool useLife() {
    _refillLives();
    if (_lives <= 0) return false;
    _lives--;
    if (_lives < maxLives) _livesSince ??= DateTime.now();
    unawaited(store.setLives(_lives));
    unawaited(store.setLivesSince(_livesSince));
    notifyListeners();
    return true;
  }

  /// Thưởng 1 lượt (sau khi xem quảng cáo). Có thể vượt quá 3 lượt.
  void addLife() {
    _refillLives();
    _lives++;
    if (_lives >= maxLives) _livesSince = null;
    unawaited(store.setLives(_lives));
    unawaited(store.setLivesSince(_livesSince));
    notifyListeners();
  }

  // ---------------- Thông báo bạn bè ----------------

  /// So kỷ lục bạn bè với lần đồng bộ trước: ai vừa vượt kỷ lục của mình thì báo.
  /// Lần đồng bộ đầu tiên (chưa có dữ liệu cũ) và bạn mới kết bạn thì không báo.
  void _checkOvertakes(String pid) {
    final myRank = best?.rank ?? 0;
    final myScore = best?.score ?? 0;
    final seen = store.seenFriendBest(pid);
    final next = <String, String>{};
    final fresh = <FriendEntry>[];
    for (final f in friends) {
      final key = '${f.bestRank}:${f.bestScore}';
      next[f.uid] = key;
      final changed = seen != null && seen.containsKey(f.uid) && seen[f.uid] != key;
      if (changed && f.beatsRecord(myRank, myScore)) fresh.add(f);
    }
    unawaited(store.setSeenFriendBest(pid, next));
    if (fresh.isEmpty) return;
    overtakeAlerts = [
      ...overtakeAlerts.where((a) => !fresh.any((f) => f.uid == a.uid)),
      ...fresh,
    ];
    unawaited(store.setOvertakeAlerts(pid, overtakeAlerts));
  }

  void dismissOvertakeAlerts() {
    final p = profile;
    if (p == null || overtakeAlerts.isEmpty) return;
    overtakeAlerts = [];
    unawaited(store.setOvertakeAlerts(p.id, overtakeAlerts));
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
  Future<String?> signInWithGoogle() async {
    if (!cloud.ready) return 'firebaseMissing';
    try {
      final u = await cloud.signInWithGoogle();
      final np = Profile(
        id: u.uid,
        name: u.displayName ?? 'Player',
        photoUrl: u.photoURL,
        isGuest: false,
      );
      // Lần đầu đăng nhập tài khoản này trên máy: mang theo thành tích đang có
      // (của tài khoản vừa dùng, tài khoản Facebook cũ, hoặc chế độ khách).
      if (!store.hasData(np.id)) {
        final candidates = [profile?.id, store.lastAccountId, Profile.guestId];
        for (final src in candidates) {
          if (src != null && src != np.id && store.hasData(src)) {
            await store.copyProfileData(src, np.id);
            break;
          }
        }
      }
      await store.setLastAccountId(np.id);
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

  /// Xóa vĩnh viễn tài khoản: dữ liệu trên máy chủ, tài khoản đăng nhập và dữ
  /// liệu của tài khoản đó trên máy. Trả về null nếu thành công, '' nếu người
  /// dùng hủy, 'offline' / 'mismatch' hoặc thông báo lỗi.
  Future<String?> deleteAccount() async {
    final p = profile;
    if (!canUseCloud || p == null) return 'error';
    if (!online) return 'offline';
    try {
      await cloud.reauthenticate();
    } on AuthCancelled {
      return '';
    } on AccountMismatch {
      return 'mismatch';
    } catch (e) {
      debugPrint('[Delete] reauth: $e');
      return e.toString();
    }
    try {
      await cloud.deleteAccount(
          uid: p.id, friendCode: friendCode, sentTo: store.sentRequests(p.id));
    } catch (e) {
      debugPrint('[Delete] $e');
      return e.toString();
    }
    await store.clearProfileData(p.id);
    await store.setGuestChosen(false);
    profile = null;
    _loadProfileData();
    notifyListeners();
    return null;
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
    if (isRecord) {
      unawaited(store.setBest(p.id, r));
      // Đã phục thù thành công: bỏ thông báo của những bạn mình vừa vượt lại.
      overtakeAlerts = overtakeAlerts.where((f) => f.beatsRecord(r.rank, r.score)).toList();
      unawaited(store.setOvertakeAlerts(p.id, overtakeAlerts));
    }
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

  /// Danh sách bạn bè / lời mời chỉ tải lại tối đa 30 phút một lần; khi người
  /// chơi chủ động làm mới ([force]) thì tối đa 1 phút một lần.
  static const friendsRefreshEvery = Duration(minutes: 30);

  /// Đã đọc kỷ lục trên máy chủ trong lần mở app này chưa (để lấy kỷ lục
  /// chơi trên máy khác). Chỉ cần đọc một lần mỗi lần mở app.
  bool _pulledThisSession = false;

  String _pushKey() => '${best?.rank}:${best?.score}:$maxRank';

  /// Đồng bộ tiết kiệm lượt đọc/ghi Firestore:
  /// - Hồ sơ (tên, ảnh, mã kết bạn): chỉ ghi khi chưa có mã hoặc tên/ảnh đổi.
  /// - Kỷ lục, hạng: chỉ ghi khi có kỷ lục/hạng mới; đọc 1 lần mỗi lần mở app.
  /// - Bạn bè, lời mời: tối đa 30 phút một lần, hoặc khi [force].
  Future<void> sync({bool force = false}) async {
    final p = profile;
    if (!canUseCloud || !online || syncing || p == null) return;
    syncing = true;
    notifyListeners();
    try {
      final profileKey = '${p.name}|${p.photoUrl}';
      if (friendCode == null || store.syncedProfileKey(p.id) != profileKey) {
        final code = await cloud.ensureProfile(uid: p.id, name: p.name, photoUrl: p.photoUrl);
        if (code != null) {
          friendCode = code;
          await store.setFriendCode(p.id, code);
          await store.setSyncedProfileKey(p.id, profileKey);
        }
      }

      if (!_pulledThisSession || store.pushedKey(p.id) != _pushKey()) {
        try {
          final remote = await cloud.syncBest(
              uid: p.id, localBest: best, gamesPlayed: gamesPlayed, maxRank: maxRank);
          _pulledThisSession = true;
          if (remote.best != null) {
            best = remote.best;
            await store.setBest(p.id, remote.best!);
          }
          if (remote.maxRank > maxRank) {
            maxRank = remote.maxRank.clamp(0, kRanks.length - 1);
            await store.setMaxRank(p.id, maxRank);
          }
          // Chưa đẩy hết (hạng chỉ được tăng từng bậc mỗi lần ghi) thì lần sau đẩy tiếp.
          if (remote.complete) await store.setPushedKey(p.id, _pushKey());
        } catch (e) {
          debugPrint('[Sync] best: $e');
        }
      }

      final last = lastSync;
      final maxAge = force ? const Duration(minutes: 1) : friendsRefreshEvery;
      if (last == null || DateTime.now().difference(last) > maxAge) {
        friends = await cloud.fetchFriends(p.id);
        await store.setFriends(p.id, friends);
        _checkOvertakes(p.id);
        incoming = await cloud.fetchIncoming(p.id);
        lastSync = DateTime.now();
        await store.setLastSync(p.id, lastSync!);
      }
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
        uid: p.id,
        name: p.name,
        photoUrl: p.photoUrl,
        code: code,
        onSent: (target) => unawaited(store.addSentRequest(p.id, target)));
    if (r == FriendOp.accepted) {
      lastSync = null; // có bạn mới: tải lại danh sách ngay
      unawaited(sync(force: true));
    }
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
      if (accept) {
        lastSync = null; // có bạn mới: tải lại danh sách ngay
        unawaited(sync(force: true));
      }
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
