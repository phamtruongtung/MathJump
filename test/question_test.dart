import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_jump/game/question.dart';

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

  test('difficulty increases with level', () {
    expect(const LevelConfig(5).addMax, greaterThan(const LevelConfig(1).addMax));
    expect(const LevelConfig(5).timeLimit, lessThan(const LevelConfig(1).timeLimit));
    expect(const LevelConfig(5).pointsToNext, greaterThan(const LevelConfig(1).pointsToNext));
    expect(const LevelConfig(1).ops, [Op.add]);
    expect(const LevelConfig(4).ops, Op.values);
  });
}
