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

  Future<void> init({required bool musicOn, required bool sfxOn}) async {
    _musicOn = musicOn;
    _sfxOn = sfxOn;
    WidgetsBinding.instance.addObserver(this);
    try {
      await _music.setAudioContext(_ctx);
      await _music.setReleaseMode(ReleaseMode.loop);
      for (final s in Sfx.values) {
        // Hai player mỗi hiệu ứng để các lần bấm nhanh liên tiếp không cắt tiếng nhau.
        final players = <AudioPlayer>[];
        for (var i = 0; i < 2; i++) {
          final p = AudioPlayer();
          await p.setAudioContext(_ctx);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('audio/${s.name}.wav'));
          players.add(p);
        }
        _sfx[s] = players;
        _next[s] = 0;
      }
      if (_musicOn) await _startMusic();
    } catch (e) {
      debugPrint('[Sound] $e');
    }
  }

  Future<void> _startMusic() async {
    try {
      if (_musicStarted) {
        await _music.resume();
      } else {
        await _music.play(AssetSource('audio/music.wav'), volume: 0.35);
        _musicStarted = true;
      }
    } catch (e) {
      debugPrint('[Sound] $e');
    }
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
    p.stop().then((_) => p.resume()).catchError((Object e) => debugPrint('[Sound] $e'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_musicOn) _startMusic();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _music.pause();
    }
  }
}
