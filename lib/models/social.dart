/// Người chơi hiện tại. `id` là 'guest' với chế độ khách, hoặc Firebase uid.
class Profile {
  final String id;
  final String name;
  final String? photoUrl;
  final bool isGuest;

  const Profile({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.isGuest,
  });

  static const guestId = 'guest';
}

/// Một dòng trong bảng xếp hạng bạn bè (được cache trên máy để xem offline).
class FriendEntry {
  final String uid;
  final String name;
  final String? photoUrl;
  final int bestScore;
  final int bestLevel;
  final int bestTimeMs;

  /// Hạng của ván đạt kỷ lục.
  final int bestRank;
  final bool isMe;

  const FriendEntry({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.bestScore,
    required this.bestLevel,
    required this.bestTimeMs,
    this.bestRank = 0,
    this.isMe = false,
  });

  /// Đọc hồ sơ trên Firestore.
  factory FriendEntry.fromMap(String uid, Map<String, dynamic> m) =>
      FriendEntry(
        uid: uid,
        name: (m['name'] as String?) ?? '?',
        photoUrl: m['photoUrl'] as String?,
        bestScore: (m['bestScore'] as num?)?.toInt() ?? 0,
        bestLevel: (m['bestLevel'] as num?)?.toInt() ?? 0,
        bestTimeMs: (m['bestTimeMs'] as num?)?.toInt() ?? 0,
        bestRank: cloudTier(m, 'tierBest', 'bestRank'),
      );

  /// Hạng lưu trên Firestore. Bản mới ghi trường `tier…` (Tân Binh = 0);
  /// bản cũ ghi `bestRank`/`maxRank` với Đồng = 0 nên phải cộng 1.
  static int cloudTier(Map<String, dynamic> m, String field, String legacyField) {
    final v = m[field] as num?;
    if (v != null) return v.toInt();
    final old = m[legacyField] as num?;
    if (old != null) return old.toInt() + 1;
    return m['bestScore'] != null ? 1 : 0;
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'photoUrl': photoUrl,
        'bestScore': bestScore,
        'bestLevel': bestLevel,
        'bestTimeMs': bestTimeMs,
        'bestRank': bestRank,
      };

  /// Đọc bản lưu trên máy (đã đúng cách đánh số mới).
  factory FriendEntry.fromJson(Map<String, dynamic> j) => FriendEntry(
        uid: j['uid'] as String,
        name: (j['name'] as String?) ?? '?',
        photoUrl: j['photoUrl'] as String?,
        bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
        bestLevel: (j['bestLevel'] as num?)?.toInt() ?? 0,
        bestTimeMs: (j['bestTimeMs'] as num?)?.toInt() ?? 0,
        bestRank: (j['bestRank'] as num?)?.toInt() ?? 0,
      );

  /// Kỷ lục của người này cao hơn kỷ lục [score] ở hạng [rank] không.
  bool beatsRecord(int rank, int score) =>
      bestRank > rank || (bestRank == rank && bestScore > score);
}

class FriendRequest {
  final String fromUid;
  final String name;
  final String? photoUrl;

  const FriendRequest({required this.fromUid, required this.name, this.photoUrl});
}
