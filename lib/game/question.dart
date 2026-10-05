import 'dart:math';

import 'rank.dart';

enum Op { add, sub, mul, div }

extension OpX on Op {
  String get symbol => switch (this) {
        Op.add => '+',
        Op.sub => '−',
        Op.mul => '×',
        Op.div => '÷',
      };

  /// Kết quả của `a op b`, hoặc null nếu phép chia không hợp lệ / không chia hết.
  int? apply(int a, int b) => switch (this) {
        Op.add => a + b,
        Op.sub => a - b,
        Op.mul => a * b,
        Op.div => (b != 0 && a % b == 0) ? a ~/ b : null,
      };
}

/// Vị trí bị khuyết trong phép tính `a op b = c`.
enum Slot { a, op, b, c }

class Question {
  final int a;
  final int b;
  final int c;
  final Op op;
  final Slot missing;
  final List<String> choices;

  const Question({
    required this.a,
    required this.b,
    required this.c,
    required this.op,
    required this.missing,
    required this.choices,
  });

  bool get isOperator => missing == Slot.op;

  String get answer => switch (missing) {
        Slot.a => '$a',
        Slot.b => '$b',
        Slot.c => '$c',
        Slot.op => op.symbol,
      };

  bool sameAs(Question o) =>
      a == o.a && b == o.b && c == o.c && op == o.op && missing == o.missing;
}

/// Độ khó của một level trong một hạng: phép tính, phạm vi số, thời gian và
/// điểm cần để lên level. Thông số theo hạng nằm trong [kRanks].
class LevelConfig {
  final int level;
  final int rank;
  const LevelConfig(this.level, {this.rank = 0});

  Rank get _r => rankAt(rank);

  /// Tỉ lệ xuất hiện của + − × ÷ (theo thứ tự [Op.values]).
  List<int> get weights => _r.weightsAt(level);

  /// Các phép tính có thể xuất hiện ở level này.
  List<Op> get ops => [
        for (var i = 0; i < Op.values.length; i++)
          if (weights[i] > 0) Op.values[i],
      ];

  /// Kết quả lớn nhất của phép cộng / số bị trừ lớn nhất.
  int get addMax => _r.addMaxAt(level);

  /// Phạm vi thừa số cho nhân/chia.
  int get factorMin => _r.factorMin;
  int get factorMax => _r.factorMaxAt(level);

  /// Số giây cho mỗi câu.
  double get timeLimit => _r.timeFor(level);

  /// Điểm cần tích lũy trong level này để lên level kế tiếp: 30, 40, 50, ...
  int get pointsToNext => 30 + (level - 1) * 10;

  double get operatorQuestionChance => rank <= 1 || level <= 1 ? 0.15 : 0.25;

  Op pickOp(Random rng) {
    final w = weights;
    var x = rng.nextInt(w.fold(0, (a, b) => a + b));
    for (var i = 0; i < w.length; i++) {
      if (x < w[i]) return Op.values[i];
      x -= w[i];
    }
    return Op.add;
  }
}

class QuestionGenerator {
  static Question generate(int level, Random rng, {int rank = 0, Question? avoid}) {
    final cfg = LevelConfig(level, rank: rank);
    while (true) {
      final op = cfg.pickOp(rng);
      final (a, b, c) = switch (op) {
        Op.add => _add(cfg, rng),
        Op.sub => _sub(cfg, rng),
        Op.mul => _mul(cfg, rng),
        Op.div => _div(cfg, rng),
      };

      final Question q;
      if (rng.nextDouble() < cfg.operatorQuestionChance) {
        // Chỉ hỏi dấu khi đúng MỘT dấu thỏa mãn (loại 2+2=4 / 2×2=4, x+0=x ...).
        final valid = Op.values.where((o) => o.apply(a, b) == c).length;
        if (valid != 1) continue;
        q = Question(
          a: a, b: b, c: c, op: op, missing: Slot.op,
          choices: Op.values.map((o) => o.symbol).toList(),
        );
      } else {
        final slot = const [Slot.a, Slot.b, Slot.c][rng.nextInt(3)];
        final ans = switch (slot) { Slot.a => a, Slot.b => b, _ => c };
        q = Question(
          a: a, b: b, c: c, op: op, missing: slot,
          choices: _numberChoices(ans, rng),
        );
      }
      if (avoid != null && q.sameAs(avoid)) continue;
      return q;
    }
  }

  static (int, int, int) _add(LevelConfig cfg, Random rng) {
    final m = cfg.addMax;
    final a = rng.nextInt(m + 1);
    final b = rng.nextInt(m - a + 1);
    return (a, b, a + b);
  }

  static (int, int, int) _sub(LevelConfig cfg, Random rng) {
    final a = rng.nextInt(cfg.addMax + 1);
    final b = rng.nextInt(a + 1);
    return (a, b, a - b);
  }

  static int _factor(LevelConfig cfg, Random rng) =>
      cfg.factorMin + rng.nextInt(cfg.factorMax - cfg.factorMin + 1);

  static (int, int, int) _mul(LevelConfig cfg, Random rng) {
    final a = _factor(cfg, rng);
    final b = _factor(cfg, rng);
    return (a, b, a * b);
  }

  static (int, int, int) _div(LevelConfig cfg, Random rng) {
    final b = _factor(cfg, rng);
    final c = _factor(cfg, rng);
    return (b * c, b, c);
  }

  static List<String> _numberChoices(int ans, Random rng) {
    final set = <int>{ans};
    if (ans >= 20 && rng.nextBool()) set.add(rng.nextBool() ? ans + 10 : ans - 10);
    final spread = max(3, (ans * 0.25).round());
    var guard = 0;
    while (set.length < 4 && guard++ < 100) {
      final d = 1 + rng.nextInt(spread);
      final v = rng.nextBool() ? ans + d : ans - d;
      if (v >= 0) set.add(v);
    }
    var x = ans + 1;
    while (set.length < 4) {
      set.add(x++);
    }
    return set.map((e) => '$e').toList()..shuffle(rng);
  }
}
