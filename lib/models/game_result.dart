class GameResult {
  final int score;
  final int level;
  final int correct;
  final int durationMs;
  final DateTime playedAt;

  /// Hạng chơi của ván này (xem kRanks).
  final int rank;

  const GameResult({
    required this.score,
    required this.level,
    required this.correct,
    required this.durationMs,
    required this.playedAt,
    this.rank = 0,
  });

  /// So sánh thành tích: hạng cao hơn thắng (kể cả khi vừa thăng hạng, 0 điểm),
  /// cùng hạng thì điểm cao hơn thắng.
  bool beats(GameResult? other) {
    if (other == null) return score > 0 || rank > 0;
    if (rank != other.rank) return rank > other.rank;
    return score > other.score;
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level,
        'correct': correct,
        'durationMs': durationMs,
        'playedAt': playedAt.millisecondsSinceEpoch,
        'rank': rank,
      };

  factory GameResult.fromJson(Map<String, dynamic> j) => GameResult(
        score: (j['score'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        playedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['playedAt'] as num?)?.toInt() ?? 0),
        rank: (j['rank'] as num?)?.toInt() ?? 0,
      );
}
