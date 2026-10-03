import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_jump/game/question.dart';
import 'package:math_jump/game/rank.dart';

void main() {
  test('every generated question has exactly one correct choice', () {
    final rng = Random(42);
    for (var level = 1; level <= 20; level++) {
      for (var i = 0; i < 500; i++) {
        final q = QuestionGenerator.generate(level, rng);
        expect(q.op.apply(q.a, q.b), q.c, reason: 'equation must hold');
        expect(q.choices.length, 4);
        expect(q.choices.toSet().length, 4);
        expect(q.choices, contains(q.answer));

        // Thay từng lựa chọn vào chỗ trống: chỉ đúng một lựa chọn.
        final valid = q.choices.where((ch) {
          if (q.isOperator) {
            final op = Op.values.firstWhere((o) => o.symbol == ch);
            return op.apply(q.a, q.b) == q.c;
          }
          final v = int.parse(ch);
          return switch (q.missing) {
            Slot.a => q.op.apply(v, q.b) == q.c,
            Slot.b => q.op.apply(q.a, v) == q.c,
            Slot.c => q.op.apply(q.a, q.b) == v,
            Slot.op => false,
          };
        }).length;
        expect(valid, 1, reason: '${q.a} ${q.op.symbol} ${q.b} = ${q.c} missing ${q.missing}');
      }
    }
  });

  test('ranks: lower rank gives more time, promotion is reachable', () {
    expect(const LevelConfig(1, rank: 0).timeLimit, 30);
    expect(const LevelConfig(1, rank: 1).timeLimit, 20);
    for (var r = 0; r < kRanks.length; r++) {
      for (var l = 1; l < 40; l++) {
        final t = LevelConfig(l, rank: r).timeLimit;
        expect(t, lessThanOrEqualTo(LevelConfig(l - 1 < 1 ? 1 : l - 1, rank: r).timeLimit));
        expect(t, greaterThanOrEqualTo(kRanks[r].endTime));
        if (r > 0) expect(t, lessThan(LevelConfig(l, rank: r - 1).timeLimit));
      }
      final rank = kRanks[r];
      if (rank.isTop) continue;
      // Điểm tối thiểu (10/câu) và tối đa (15/câu) khi vừa chạm level thăng hạng.
      var minPts = 0;
      for (var l = 1; l < rank.promoteLevel!; l++) {
        minPts += LevelConfig(l, rank: r).pointsToNext;
      }
      expect(rank.promoteScore, greaterThanOrEqualTo(minPts));
      expect(rank.promoteScore, lessThan(minPts * 1.5));
    }
  });

  test('difficulty increases with level', () {
    expect(const LevelConfig(5).addMax, greaterThan(const LevelConfig(1).addMax));
    expect(const LevelConfig(5).timeLimit, lessThan(const LevelConfig(1).timeLimit));
    expect(const LevelConfig(5).pointsToNext, greaterThan(const LevelConfig(1).pointsToNext));
    expect(const LevelConfig(1).ops, [Op.add]);
    expect(const LevelConfig(4).ops, Op.values);
  });
}
