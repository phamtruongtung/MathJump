import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_jump/game/question.dart';
import 'package:math_jump/game/rank.dart';
import 'package:math_jump/models/game_result.dart';
import 'package:math_jump/services/cloud_service.dart';

/// Mô phỏng một ván chơi thật theo đúng luật tính điểm của GameScreen:
/// mỗi câu đúng 10 + (0..5) điểm, dừng 0,3 giây sau mỗi câu đúng.
GameResult simulate(Random rng, {required int rank, required int answers, required bool fast}) {
  var level = 1, score = 0, levelPoints = 0, ms = 0;
  for (var i = 0; i < answers; i++) {
    final limit = kRanks[rank].questionTime(1.5, level);
    final used = fast ? 0.05 : rng.nextDouble(); // tỉ lệ thời gian đã dùng
    ms += (limit * 1000 * used).round() + 300;
    final gain = 10 + ((1 - used) * 5).round();
    score += gain;
    levelPoints += gain;
    final goal = LevelConfig(level, rank: rank).pointsToNext;
    if (levelPoints >= goal) {
      levelPoints -= goal;
      level++;
    }
  }
  return GameResult(
      score: score, level: level, correct: answers, durationMs: ms,
      playedAt: DateTime(2026), rank: rank);
}

void main() {
  test('real games always pass the anti-cheat check', () {
    final rng = Random(1);
    for (var rank = 0; rank < 7; rank++) {
      for (final n in [0, 1, 5, 40, 200]) {
        expect(CloudService.plausible(simulate(rng, rank: rank, answers: n, fast: true)), isTrue);
        expect(CloudService.plausible(simulate(rng, rank: rank, answers: n, fast: false)), isTrue);
      }
    }
  });

  test('a higher rank beats any lower-rank record, even with 0 points', () {
    GameResult g(int rank, int score) => GameResult(
        score: score, level: 1, correct: score ~/ 10, durationMs: 99999,
        playedAt: DateTime(2026), rank: rank);
    expect(g(1, 0).beats(g(0, 500)), isTrue); // vừa lên Đồng rồi thua ngay
    expect(g(0, 500).beats(g(1, 0)), isFalse);
    expect(g(1, 120).beats(g(1, 100)), isTrue);
    expect(g(1, 100).beats(g(1, 100)), isFalse);
    expect(g(0, 0).beats(null), isFalse); // ván 0 điểm ở hạng đầu: chưa phải kỷ lục
    expect(g(1, 0).beats(null), isTrue);
    expect(CloudService.plausible(g(1, 0)), isTrue);
  });

  test('obviously fake scores are rejected', () {
    GameResult r(int score, int level, int correct, int ms) => GameResult(
        score: score, level: level, correct: correct, durationMs: ms, playedAt: DateTime(2026));
    expect(CloudService.plausible(r(999999, 50, 10, 60000)), isFalse); // điểm quá cao so với số câu
    expect(CloudService.plausible(r(150, 3, 10, 500)), isFalse); // 10 câu trong 0,5 giây
    expect(CloudService.plausible(r(150, 40, 10, 60000)), isFalse); // level quá cao
    expect(CloudService.plausible(r(150, 3, 10, 60000)), isTrue);
  });
}
