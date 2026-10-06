import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_result.dart';
import '../models/social.dart';

/// Toàn bộ dữ liệu người chơi được lưu trên máy (chơi offline được).
/// Dữ liệu ván chơi được tách theo profile id ('guest' hoặc Firebase uid).
class LocalStore {
  late final SharedPreferences _p;

  Future<void> init() async => _p = await SharedPreferences.getInstance();

  // ---- Cài đặt chung ----
  String get lang =>
      _p.getString('lang') ??
      (PlatformDispatcher.instance.locale.languageCode == 'vi' ? 'vi' : 'en');
  Future<void> setLang(String v) => _p.setString('lang', v);

  String? get character => _p.getString('character');
  Future<void> setCharacter(String v) => _p.setString('character', v);

  bool get musicOn => _p.getBool('musicOn') ?? true;
  Future<void> setMusicOn(bool v) => _p.setBool('musicOn', v);

  bool get sfxOn => _p.getBool('sfxOn') ?? true;
  Future<void> setSfxOn(bool v) => _p.setBool('sfxOn', v);

  bool get guestChosen => _p.getBool('guestChosen') ?? false;
  Future<void> setGuestChosen(bool v) => _p.setBool('guestChosen', v);

  String? get guestName => _p.getString('guestName');
  Future<void> setGuestName(String v) => _p.setString('guestName', v);

  bool get tutorialSeen => _p.getBool('tutorialSeen') ?? false;
  Future<void> setTutorialSeen() => _p.setBool('tutorialSeen', true);

  // ---- Lượt chơi (dùng chung cho cả máy) ----
  int? get lives => _p.getInt('lives');
  Future<void> setLives(int v) => _p.setInt('lives', v);

  /// Mốc bắt đầu tính giờ hồi lượt (null khi đầy lượt).
  DateTime? get livesSince {
    final v = _p.getInt('livesSince');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  Future<void> setLivesSince(DateTime? v) => v == null
      ? _p.remove('livesSince')
      : _p.setInt('livesSince', v.millisecondsSinceEpoch);

  // ---- Chuyển đổi dữ liệu cũ ----

  /// Từ v1 (6 hạng, Đồng = 0) lên v2 (thêm Tân Binh = 0): mọi số hạng đã lưu +1.
  /// Người đã từng chơi ở bản cũ (có lịch sử) mà chưa mở khóa hạng nào thì ở Đồng.
  Future<void> migrateRanks(int targetVersion) async {
    final from = _p.getInt('rankSchema') ?? 1;
    if (from >= targetVersion) return;
    final keys = _p.getKeys().toList();
    final players = keys.where((k) => k.startsWith('history_')).map((k) => k.substring(8));
    for (final pid in players) {
      if (!_p.containsKey('maxRank_$pid')) await setMaxRank(pid, 0);
    }
    for (final k in _p.getKeys().toList()) {
      if (k.startsWith('maxRank_') || k.startsWith('selRank_')) {
        await _p.setInt(k, (_p.getInt(k) ?? 0) + 1);
      } else if (k.startsWith('best_')) {
        await _bumpJson(k, (m) => m['rank'] = ((m['rank'] as num?)?.toInt() ?? 0) + 1);
      } else if (k.startsWith('history_')) {
        await _bumpJsonList(k, (m) => m['rank'] = ((m['rank'] as num?)?.toInt() ?? 0) + 1);
      } else if (k.startsWith('friends_')) {
        await _bumpJsonList(k, (m) => m['bestRank'] = ((m['bestRank'] as num?)?.toInt() ?? 0) + 1);
      }
    }
    await _p.setInt('rankSchema', targetVersion);
  }

  Future<void> _bumpJson(String key, void Function(Map<String, dynamic>) f) async {
    try {
      final m = jsonDecode(_p.getString(key)!) as Map<String, dynamic>;
      f(m);
      await _p.setString(key, jsonEncode(m));
    } catch (_) {}
  }

  Future<void> _bumpJsonList(String key, void Function(Map<String, dynamic>) f) async {
    try {
      final list = (jsonDecode(_p.getString(key)!) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      list.forEach(f);
      await _p.setString(key, jsonEncode(list));
    } catch (_) {}
  }

  // ---- Thông báo bạn bè vượt kỷ lục ----

  /// Kỷ lục của từng bạn ở lần đồng bộ trước: uid → "hạng:điểm".
  Map<String, String>? seenFriendBest(String pid) {
    final raw = _p.getString('seenFriends_$pid');
    if (raw == null) return null;
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSeenFriendBest(String pid, Map<String, String> v) =>
      _p.setString('seenFriends_$pid', jsonEncode(v));

  List<FriendEntry> overtakeAlerts(String pid) =>
      _readList('alerts_$pid', FriendEntry.fromJson);
  Future<void> setOvertakeAlerts(String pid, List<FriendEntry> v) =>
      _p.setString('alerts_$pid', jsonEncode(v.map((e) => e.toJson()).toList()));

  /// Tài khoản đăng nhập gần nhất trên máy (để mang dữ liệu sang khi đổi tài khoản).
  String? get lastAccountId => _p.getString('lastAccountId');
  Future<void> setLastAccountId(String v) => _p.setString('lastAccountId', v);

  // ---- Dữ liệu theo profile ----
  bool hasData(String pid) => _p.containsKey('history_$pid');

  List<GameResult> history(String pid) =>
      _readList('history_$pid', GameResult.fromJson);
  Future<void> setHistory(String pid, List<GameResult> v) =>
      _p.setString('history_$pid', jsonEncode(v.map((e) => e.toJson()).toList()));

  GameResult? best(String pid) {
    final raw = _p.getString('best_$pid');
    if (raw == null) return null;
    try {
      return GameResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setBest(String pid, GameResult v) =>
      _p.setString('best_$pid', jsonEncode(v.toJson()));

  int gamesPlayed(String pid) => _p.getInt('games_$pid') ?? 0;
  Future<void> setGamesPlayed(String pid, int v) => _p.setInt('games_$pid', v);

  List<FriendEntry> friends(String pid) =>
      _readList('friends_$pid', FriendEntry.fromJson);
  Future<void> setFriends(String pid, List<FriendEntry> v) =>
      _p.setString('friends_$pid', jsonEncode(v.map((e) => e.toJson()).toList()));

  DateTime? lastSync(String pid) {
    final v = _p.getInt('lastSync_$pid');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  Future<void> setLastSync(String pid, DateTime v) =>
      _p.setInt('lastSync_$pid', v.millisecondsSinceEpoch);

  /// Hạng cao nhất đã mở khóa, và hạng đang chọn để chơi.
  int maxRank(String pid) => _p.getInt('maxRank_$pid') ?? 0;
  Future<void> setMaxRank(String pid, int v) => _p.setInt('maxRank_$pid', v);

  int? selectedRank(String pid) => _p.getInt('selRank_$pid');
  Future<void> setSelectedRank(String pid, int v) => _p.setInt('selRank_$pid', v);

  /// Tên/ảnh đã ghi lên máy chủ lần gần nhất (để khỏi ghi lại khi không đổi).
  String? syncedProfileKey(String pid) => _p.getString('profileKey_$pid');
  Future<void> setSyncedProfileKey(String pid, String v) => _p.setString('profileKey_$pid', v);

  /// Kỷ lục/hạng đã đẩy lên máy chủ lần gần nhất ("hạng:điểm:hạngCaoNhất").
  String? pushedKey(String pid) => _p.getString('pushed_$pid');
  Future<void> setPushedKey(String pid, String v) => _p.setString('pushed_$pid', v);

  /// Những người mình đã gửi lời mời kết bạn (để xóa khi xóa tài khoản).
  List<String> sentRequests(String pid) => _p.getStringList('sent_$pid') ?? const [];
  Future<void> addSentRequest(String pid, String uid) {
    final list = {...sentRequests(pid), uid}.toList();
    return _p.setStringList('sent_$pid', list);
  }

  /// Xóa toàn bộ dữ liệu của một tài khoản trên máy (khi xóa tài khoản).
  Future<void> clearProfileData(String pid) async {
    for (final k in _p.getKeys().toList()) {
      if (k.endsWith('_$pid')) await _p.remove(k);
    }
    if (lastAccountId == pid) await _p.remove('lastAccountId');
  }

  String? friendCode(String pid) => _p.getString('code_$pid');
  Future<void> setFriendCode(String pid, String v) => _p.setString('code_$pid', v);

  /// Chuyển dữ liệu chế độ khách sang tài khoản vừa đăng nhập lần đầu.
  Future<void> copyProfileData(String from, String to) async {
    await setHistory(to, history(from));
    final b = best(from);
    if (b != null) await setBest(to, b);
    await setGamesPlayed(to, gamesPlayed(from));
    await setMaxRank(to, maxRank(from));
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) f) {
    final raw = _p.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
