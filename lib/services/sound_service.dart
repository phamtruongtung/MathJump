import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum Sfx { correct, wrong, levelup, record }

/// Nhạc nền (lặp) và hiệu ứng âm thanh. File nằm trong assets/audio,
/// được tạo bởi tools/gen_audio.ps1.
class SoundService with WidgetsBindingObserver {
  final _music = AudioPlayer();
  final _sfx = <Sfx, List<AudioPlayer>>{};
  final _next = <Sfx, int>{};

  bool _musicOn = true;
  bool _sfxOn = true;
  bool _musicStarted = false;

  bool get musicOn => _musicOn;
  bool get sfxOn => _sfxOn;

  // Trộn tiếng với nhau: tiếng hiệu ứng không làm dừng nhạc nền.
  static final _ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  /// Không chờ âm thanh nạp xong: trình duyệt khóa âm thanh cho tới lần chạm
  /// đầu tiên, nếu chờ thì game kẹt ở màn hình trắng. Âm thanh được chuẩn bị
  /// ngầm; trên web chỉ phát sau khi người chơi chạm vào màn hình.
  Future<void> init({required bool musicOn, required bool sfxOn}) async {
    _musicOn = musicOn;
    _sfxOn = sfxOn;
    WidgetsBinding.instance.addObserver(this);
    for (final s in Sfx.values) {
      // Hai player mỗi hiệu ứng để các lần bấm nhanh liên tiếp không cắt tiếng nhau.
      _sfx[s] = [AudioPlayer(), AudioPlayer()];
      _next[s] = 0;
    }
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    if (kIsWeb) return; // web: nạp file khi phát lần đầu (sau khi người chơi chạm)
    try {
      await _music.setAudioContext(_ctx);
      await _music.setReleaseMode(ReleaseMode.loop);
      for (final s in Sfx.values) {
        for (final p in _sfx[s]!) {
          await p.setAudioContext(_ctx);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('audio/${s.name}.wav'));
        }
      }
      if (_musicOn) await _startMusic();
    } catch (e) {
      debugPrint('[Sound] $e');
    }
  }

  bool _starting = false;

  Future<void> _startMusic() async {
    if (_starting) return;
    _starting = true;
    try {
      const wait = Duration(seconds: 5); // trình duyệt có thể treo lệnh phát
      if (_musicStarted) {
        await _music.resume().timeout(wait);
      } else {
        if (kIsWeb) await _music.setReleaseMode(ReleaseMode.loop).timeout(wait);
        await _music.play(AssetSource('audio/music.wav'), volume: 0.35).timeout(wait);
        _musicStarted = true;
      }
    } catch (e) {
      debugPrint('[Sound] $e');
    } finally {
      _starting = false;
    }
  }

  /// Trình duyệt (nhất là Safari trên iPhone) chặn tự phát nhạc cho tới khi
  /// người dùng chạm vào màn hình; gọi hàm này ở mỗi lần chạm để bật nhạc.
  void ensureMusic() {
    if (_musicOn && !_musicStarted) _startMusic();
  }

  Future<void> setMusicOn(bool v) async {
    _musicOn = v;
    if (v) {
      await _startMusic();
    } else {
      await _music.pause();
    }
  }

  void setSfxOn(bool v) => _sfxOn = v;

  void play(Sfx s) {
    if (!_sfxOn) return;
    final players = _sfx[s];
    if (players == null) return;
    final i = _next[s]!;
    _next[s] = (i + 1) % players.length;
    final p = players[i];
    final Future<void> f = kIsWeb
        ? p.play(AssetSource('audio/${s.name}.wav'))
        : p.stop().then((_) => p.resume());
    f.catchError((Object e) => debugPrint('[Sound] $e'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Web: chỉ phát lại nếu nhạc đã chạy (lần đầu phải đợi người chơi chạm).
      if (_musicOn && (!kIsWeb || _musicStarted)) _startMusic();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _music.pause();
    }
  }
}
