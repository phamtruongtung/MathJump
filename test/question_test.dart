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
        final cur = LevelConfig(l, rank: r).addMax;
        final prev = LevelConfig(l, rank: r - 1).addMax;
        expect(cur, l == 1 ? greaterThanOrEqualTo(prev) : greaterThan(prev));
        expect(LevelConfig(l, rank: r).factorMax,
            greaterThanOrEqualTo(LevelConfig(l, rank: r - 1).factorMax));
      }
    }
    for (final r in [0, 1, 2]) {
      final w = LevelConfig(20, rank: r).weights;
      expect(w[0] + w[1], greaterThan(w[2] + w[3]));
    }
    // Tân Binh: chỉ cộng trừ, phạm vi tối đa 50.
    expect(const LevelConfig(1).ops, [Op.add]);
    expect(const LevelConfig(3).ops, [Op.add, Op.sub]);
    expect(const LevelConfig(30).ops, [Op.add, Op.sub]);
    expect(const LevelConfig(30).addMax, 50);
    // Đồng: level 1 chỉ có cộng; nhân từ level 4, chia từ level 6.
    expect(const LevelConfig(1, rank: 1).ops, [Op.add]);
    expect(const LevelConfig(3, rank: 1).ops, [Op.add, Op.sub]);
    expect(const LevelConfig(4, rank: 1).ops, [Op.add, Op.sub, Op.mul]);
    expect(const LevelConfig(6, rank: 1).ops, Op.values);
    expect(const LevelConfig(1, rank: 2).ops, [Op.add, Op.sub]);
    expect(const LevelConfig(1, rank: 3).ops, Op.values);
  });

  test('question difficulty follows the numbers in the question', () {
    Question q(int a, int b, int c, Op op, Slot missing) =>
        Question(a: a, b: b, c: c, op: op, missing: missing, choices: const []);
    expect(q(4, 5, 9, Op.add, Slot.a).difficulty, closeTo(0.8, 1e-9));
    expect(q(347, 586, 933, Op.add, Slot.c).difficulty, closeTo(2.2, 1e-9));
    expect(q(17, 23, 391, Op.mul, Slot.c).difficulty, closeTo(8.0, 1e-9));
    expect(q(4, 5, 9, Op.add, Slot.op).difficulty, closeTo(1.2, 1e-9)); // điền dấu
    expect(q(12, 4, 3, Op.div, Slot.b).difficulty, closeTo(1.4, 1e-9));
  });

  test('time bank: per-question time by rank, level and difficulty', () {
    // Ví dụ trong bảng đã thống nhất: Tân Binh level 1, "4 + ? = 9" → 7,2 giây.
    expect(kRanks[0].questionTime(0.8, 1), closeTo(7.2, 1e-9));
    expect(kRanks[0].questionTime(0.8, 20), closeTo(5.4, 1e-9));
    for (var r = 0; r < kRanks.length; r++) {
      for (final d in [0.8, 1.5, 2.2, 4.0, 8.0]) {
        for (var l = 1; l < 60; l++) {
          final t = kRanks[r].questionTime(d, l);
          expect(t, greaterThanOrEqualTo(1.2));
          expect(t, lessThanOrEqualTo(kRanks[r].questionTime(d, l == 1 ? 1 : l - 1)));
          if (r > 0) expect(t, lessThanOrEqualTo(kRanks[r - 1].questionTime(d, l)));
          // Câu khó hơn có nhiều thời gian hơn (trừ khi đã chạm mức tối thiểu).
          expect(kRanks[r].questionTime(d + 1, l), greaterThanOrEqualTo(t));
        }
      }
      // Sau level 20 vẫn tiếp tục siết (người giỏi không sống mãi).
      expect(kRanks[r].questionTime(2.2, 40), lessThan(kRanks[r].questionTime(2.2, 20)));
    }
  });

  test('ranks: promotion is reachable', () {
    for (var r = 0; r < kRanks.length; r++) {
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
    expect(const LevelConfig(5).pointsToNext, greaterThan(const LevelConfig(1).pointsToNext));
  });
}
