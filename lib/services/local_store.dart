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
