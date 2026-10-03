import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_jump/game/question.dart';
import 'package:math_jump/game/rank.dart';

void main() {
  test('every generated question has exactly one correct choice and fits its rank', () {
    final rng = Random(42);
    for (var rank = 0; rank < kRanks.length; rank++) {
     for (var level = 1; level <= 20; level++) {
      final cfg = LevelConfig(level, rank: rank);
      for (var i = 0; i < 300; i++) {
        final q = QuestionGenerator.generate(level, rng, rank: rank);
        expect(q.op.apply(q.a, q.b), q.c, reason: 'equation must hold');
        expect(cfg.ops, contains(q.op));
        switch (q.op) {
          case Op.add:
            expect(q.c, lessThanOrEqualTo(cfg.addMax));
          case Op.sub:
            expect(q.a, lessThanOrEqualTo(cfg.addMax));
          case Op.mul:
            expect([q.a, q.b].every((f) => f >= cfg.factorMin && f <= cfg.factorMax), isTrue);
          case Op.div:
            expect([q.b, q.c].every((f) => f >= cfg.factorMin && f <= cfg.factorMax), isTrue);
        }
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
    }
  });

  test('higher rank means bigger numbers; low ranks are mostly + and −', () {
    for (var r = 1; r < kRanks.length; r++) {
      for (final l in [1, 10, 20]) {
        expect(LevelConfig(l, rank: r).addMax, greaterThan(LevelConfig(l, rank: r - 1).addMax));
        expect(LevelConfig(l, rank: r).factorMax,
            greaterThanOrEqualTo(LevelConfig(l, rank: r - 1).factorMax));
      }
    }
    for (final r in [0, 1]) {
      final w = LevelConfig(20, rank: r).weights;
      expect(w[0] + w[1], greaterThan(w[2] + w[3]));
    }
    // Hạng Đồng: level 1 chỉ có cộng; nhân từ level 4, chia từ level 6.
    expect(const LevelConfig(1).ops, [Op.add]);
    expect(const LevelConfig(3).ops, [Op.add, Op.sub]);
    expect(const LevelConfig(4).ops, [Op.add, Op.sub, Op.mul]);
    expect(const LevelConfig(6).ops, Op.values);
    expect(const LevelConfig(1, rank: 1).ops, [Op.add, Op.sub]);
    expect(const LevelConfig(1, rank: 2).ops, Op.values);
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
  });
}
