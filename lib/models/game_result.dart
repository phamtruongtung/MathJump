class GameResult {
  final int score;
  final int level;
  final int correct;
  final int durationMs;
  final DateTime playedAt;

  const GameResult({
    required this.score,
    required this.level,
    required this.correct,
    required this.durationMs,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'level': level,
        'correct': correct,
        'durationMs': durationMs,
        'playedAt': playedAt.millisecondsSinceEpoch,
      };

  factory GameResult.fromJson(Map<String, dynamic> j) => GameResult(
        score: (j['score'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 1,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        playedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['playedAt'] as num?)?.toInt() ?? 0),
      );
}
