/// Người chơi hiện tại. `id` là 'guest' với chế độ khách, hoặc Firebase uid.
class Profile {
  final String id;
  final String name;
  final String? photoUrl;
  final bool isGuest;

  /// Email tài khoản Google — chỉ dùng trên máy để tạo mã tìm kiếm, không
  /// lưu dạng chữ lên máy chủ.
  final String? email;

  const Profile({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.isGuest,
    this.email,
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

  /// Danh sách bạn của người này (để gợi ý "bạn của bạn").
  final List<String> friendIds;

  /// Người này cho phép người khác tìm thấy / gợi ý không.
  final bool searchable;

  const FriendEntry({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.bestScore,
    required this.bestLevel,
    required this.bestTimeMs,
    this.bestRank = 0,
    this.isMe = false,
    this.friendIds = const [],
    this.searchable = true,
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
        friendIds: ((m['friendIds'] as List?) ?? const []).whereType<String>().toList(),
        searchable: m['searchable'] != false,
      );

  /// Hạng lưu trên Firestore. Bản mới ghi trường `tier…` (Tân Binh = 0);
  /// bản cũ ghi `bestRank`/`maxRank` với Đồng = 0 nên phải cộng 1.
  static int cloudTier(Map<String, dynamic> m, String field, String legacyField) {
    final v = m[field] as num?;
    if (v != null) return v.toInt();
    final old = m[legacyField] as num?;
    if (old != null) return old.toInt() + 1;
    // Hồ sơ bản mới (có tierBest) nhưng chưa ghi tierMax: hạng cao nhất ít
    // nhất bằng hạng của kỷ lục — KHÔNG được coi là dữ liệu bản cũ.
    final tierBest = m['tierBest'] as num?;
    if (tierBest != null) return tierBest.toInt();
    // Chỉ dữ liệu bản cũ (chưa có hạng Tân Binh) mới có điểm mà không có hạng.
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
        'friendIds': friendIds,
        'searchable': searchable,
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
        friendIds: ((j['friendIds'] as List?) ?? const []).whereType<String>().toList(),
        searchable: j['searchable'] != false,
      );

  /// Kỷ lục của người này cao hơn kỷ lục [score] ở hạng [rank] không.
  bool beatsRecord(int rank, int score) =>
      bestRank > rank || (bestRank == rank && bestScore > score);
}

/// Gợi ý kết bạn: những người là bạn của bạn mình, chưa là bạn của mình,
/// xếp theo số bạn chung (nhiều trước). Trả về uid → số bạn chung.
Map<String, int> friendSuggestions({
  required String myUid,
  required List<FriendEntry> friends,
  Set<String> exclude = const {},
  int limit = 10,
}) {
  final mine = {for (final f in friends) f.uid};
  final counts = <String, int>{};
  for (final f in friends) {
    for (final id in f.friendIds) {
      if (id == myUid || mine.contains(id) || exclude.contains(id)) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
  return {for (final e in sorted.take(limit)) e.key: e.value};
}

class FriendRequest {
  final String fromUid;
  final String name;
  final String? photoUrl;

  const FriendRequest({required this.fromUid, required this.name, this.photoUrl});
}
