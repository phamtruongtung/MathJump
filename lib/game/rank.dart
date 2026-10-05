import 'dart:math';
import 'dart:ui';

/// Hạng chơi. Hạng càng thấp càng dễ: phạm vi số nhỏ, thời gian dài, chủ yếu
/// cộng trừ. Hạng Đồng hợp với trẻ từ lớp 3 trở xuống. Bên trong mỗi hạng,
/// độ khó vẫn tăng dần theo level (đạt mức cao nhất ở level [rampLevels] + 1).
class Rank {
  const Rank({
    required this.index,
    required this.emoji,
    required this.key,
    required this.color,
    required this.startTime,
    required this.endTime,
    required this.addStart,
    required this.addEnd,
    required this.factorMin,
    required this.factorStart,
    required this.factorEnd,
    required this.weights,
    this.subFrom = 1,
    required this.mulFrom,
    required this.divFrom,
    this.promoteLevel,
    this.promoteScore,
  });

  final int index;
  final String emoji;

  /// Khóa bản dịch tên hạng (rank_0, rank_1, ...).
  final String key;
  final Color color;

  /// Số giây mỗi câu ở level 1 và mức thấp nhất.
  final double startTime;
  final double endTime;

  /// Phạm vi cộng/trừ: kết quả lớn nhất ở level 1 và ở level cao.
  final int addStart;
  final int addEnd;

  /// Thừa số nhân/chia: nhỏ nhất, và lớn nhất ở level 1 / level cao.
  final int factorMin;
  final int factorStart;
  final int factorEnd;

  /// Tỉ lệ xuất hiện của + − × ÷ (theo thứ tự).
  final List<int> weights;

  /// Level bắt đầu có phép trừ / phép nhân / phép chia.
  final int subFrom;
  final int mulFrom;
  final int divFrom;

  /// Điều kiện thăng hạng trong MỘT ván: đạt level này và số điểm này.
  /// null với hạng cao nhất.
  final int? promoteLevel;
  final int? promoteScore;

  static const rampLevels = 19;

  double _progress(int level) => min(1.0, (level - 1) / rampLevels);

  double timeFor(int level) => startTime - (startTime - endTime) * _progress(level);

  int addMaxAt(int level) => (addStart + (addEnd - addStart) * _progress(level)).round();

  int factorMaxAt(int level) =>
      (factorStart + (factorEnd - factorStart) * _progress(level)).round();

  /// Tỉ lệ + − × ÷ ở level này (phép chưa mở thì tỉ lệ 0).
  List<int> weightsAt(int level) => [
        weights[0],
        level >= subFrom ? weights[1] : 0,
        level >= mulFrom ? weights[2] : 0,
        level >= divFrom ? weights[3] : 0,
      ];

  bool get isTop => promoteLevel == null;

  bool canPromote(int level, int score) =>
      !isTop && level >= promoteLevel! && score >= promoteScore!;
}

/// Không bao giờ mở (dùng cho hạng không có nhân/chia).
const _never = 1 << 20;

const kRanks = <Rank>[
  // Tân Binh: chỉ cộng trừ trong phạm vi 10 → 50, thời gian rộng rãi.
  Rank(index: 0, emoji: '🐣', key: 'rank_0', color: Color(0xFF51CF66),
      startTime: 40, endTime: 20,
      addStart: 10, addEnd: 50, factorMin: 2, factorStart: 2, factorEnd: 2,
      weights: [50, 50, 0, 0], subFrom: 2, mulFrom: _never, divFrom: _never,
      promoteLevel: 8, promoteScore: 500),
  // Lớp 1–3: cộng trừ trong 10 → 100, bảng cửu chương 2–9.
  Rank(index: 1, emoji: '🥉', key: 'rank_1', color: Color(0xFFCD7F32),
      startTime: 30, endTime: 15,
      addStart: 10, addEnd: 100, factorMin: 2, factorStart: 5, factorEnd: 9,
      weights: [40, 40, 12, 8], subFrom: 2, mulFrom: 4, divFrom: 6,
      promoteLevel: 10, promoteScore: 700),
  Rank(index: 2, emoji: '🥈', key: 'rank_2', color: Color(0xFF8E9AAF),
      startTime: 20, endTime: 10,
      addStart: 20, addEnd: 200, factorMin: 2, factorStart: 9, factorEnd: 10,
      weights: [35, 35, 18, 12], mulFrom: 2, divFrom: 3,
      promoteLevel: 12, promoteScore: 1000),
  Rank(index: 3, emoji: '🥇', key: 'rank_3', color: Color(0xFFF2B705),
      startTime: 15, endTime: 8,
      addStart: 50, addEnd: 500, factorMin: 2, factorStart: 10, factorEnd: 12,
      weights: [30, 30, 22, 18], mulFrom: 1, divFrom: 1,
      promoteLevel: 14, promoteScore: 1300),
  Rank(index: 4, emoji: '💠', key: 'rank_4', color: Color(0xFF3BC9DB),
      startTime: 12, endTime: 6,
      addStart: 100, addEnd: 1000, factorMin: 3, factorStart: 12, factorEnd: 15,
      weights: [25, 25, 25, 25], mulFrom: 1, divFrom: 1,
      promoteLevel: 16, promoteScore: 1650),
  Rank(index: 5, emoji: '💎', key: 'rank_5', color: Color(0xFF7950F2),
      startTime: 10, endTime: 5,
      addStart: 200, addEnd: 2000, factorMin: 4, factorStart: 15, factorEnd: 20,
      weights: [25, 25, 25, 25], mulFrom: 1, divFrom: 1,
      promoteLevel: 18, promoteScore: 2050),
  Rank(index: 6, emoji: '👑', key: 'rank_6', color: Color(0xFFE8590C),
      startTime: 8, endTime: 4,
      addStart: 500, addEnd: 5000, factorMin: 6, factorStart: 20, factorEnd: 25,
      weights: [25, 25, 25, 25], mulFrom: 1, divFrom: 1),
];

/// Phiên bản đánh số hạng. v2: thêm hạng Tân Binh ở vị trí 0 (các hạng cũ +1).
const kRankSchemaVersion = 2;

Rank rankAt(int i) => kRanks[i.clamp(0, kRanks.length - 1)];
