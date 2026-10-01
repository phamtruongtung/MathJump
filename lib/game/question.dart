import 'dart:math';

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

/// Độ khó của từng level: phạm vi số, phép tính, thời gian và điểm cần để lên level.
class LevelConfig {
  final int level;
  const LevelConfig(this.level);

  List<Op> get ops => switch (level) {
        1 => const [Op.add],
        2 => const [Op.add, Op.sub],
        3 => const [Op.add, Op.sub, Op.mul],
        _ => Op.values,
      };

  /// Giới hạn trên cho phép cộng/trừ: 10, 25, 40, 55, ...
  int get addMax => 10 + (level - 1) * 15;

  /// Thừa số lớn nhất cho nhân/chia: lv3 → 5, lv10 → 12, sau đó tăng dần tới 20.
  int get factorMax =>
      level <= 10 ? min(12, 2 + level) : min(20, 12 + (level - 10));

  /// Số giây cho mỗi câu: 10s ở level 1, giảm 0.7s mỗi level, tối thiểu 3s.
  double get timeLimit => max(3.0, 10.0 - (level - 1) * 0.7);

  /// Điểm cần tích lũy trong level này để lên level kế tiếp.
  int get pointsToNext => 50 + (level - 1) * 30;

  double get operatorQuestionChance => level <= 1 ? 0.15 : 0.25;
}

class QuestionGenerator {
  static Question generate(int level, Random rng, {Question? avoid}) {
    final cfg = LevelConfig(level);
    while (true) {
      final op = cfg.ops[rng.nextInt(cfg.ops.length)];
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

  static (int, int, int) _mul(LevelConfig cfg, Random rng) {
    final a = 2 + rng.nextInt(cfg.factorMax - 1);
    final b = 2 + rng.nextInt(cfg.factorMax - 1);
    return (a, b, a * b);
  }

  static (int, int, int) _div(LevelConfig cfg, Random rng) {
    final b = 2 + rng.nextInt(cfg.factorMax - 1);
    final c = 1 + rng.nextInt(cfg.factorMax);
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
