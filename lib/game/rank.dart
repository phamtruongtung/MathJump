import 'dart:math';
import 'dart:ui';

/// Hạng chơi. Các hạng chỉ khác nhau ở thời gian trả lời mỗi câu:
/// hạng càng thấp thời gian càng dài. Hạng Đồng hợp với trẻ từ lớp 3 trở xuống.
class Rank {
  const Rank({
    required this.index,
    required this.emoji,
    required this.key,
    required this.color,
    required this.startTime,
    required this.endTime,
    this.promoteLevel,
    this.promoteScore,
  });

  final int index;
  final String emoji;

  /// Khóa bản dịch tên hạng (rank_0, rank_1, ...).
  final String key;
  final Color color;

  /// Số giây mỗi câu ở level 1 và mức thấp nhất (đạt tới ở level [rampLevels] + 1).
  final double startTime;
  final double endTime;

  /// Điều kiện thăng hạng trong MỘT ván: đạt level này và số điểm này.
  /// null với hạng cao nhất.
  final int? promoteLevel;
  final int? promoteScore;

  static const rampLevels = 19;

  double timeFor(int level) =>
      max(endTime, startTime - (startTime - endTime) * (level - 1) / rampLevels);

  bool get isTop => promoteLevel == null;

  bool canPromote(int level, int score) =>
      !isTop && level >= promoteLevel! && score >= promoteScore!;
}

const kRanks = <Rank>[
  Rank(index: 0, emoji: '🥉', key: 'rank_0', color: Color(0xFFCD7F32),
      startTime: 30, endTime: 15, promoteLevel: 10, promoteScore: 700),
  Rank(index: 1, emoji: '🥈', key: 'rank_1', color: Color(0xFF8E9AAF),
      startTime: 20, endTime: 10, promoteLevel: 12, promoteScore: 1000),
  Rank(index: 2, emoji: '🥇', key: 'rank_2', color: Color(0xFFF2B705),
      startTime: 15, endTime: 7, promoteLevel: 14, promoteScore: 1300),
  Rank(index: 3, emoji: '💠', key: 'rank_3', color: Color(0xFF3BC9DB),
      startTime: 10, endTime: 5, promoteLevel: 16, promoteScore: 1650),
  Rank(index: 4, emoji: '💎', key: 'rank_4', color: Color(0xFF7950F2),
      startTime: 8, endTime: 4, promoteLevel: 18, promoteScore: 2050),
  Rank(index: 5, emoji: '👑', key: 'rank_5', color: Color(0xFFE8590C),
      startTime: 6, endTime: 3),
];

Rank rankAt(int i) => kRanks[i.clamp(0, kRanks.length - 1)];
