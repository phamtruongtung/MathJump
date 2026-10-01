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
  final bool isMe;

  const FriendEntry({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.bestScore,
    required this.bestLevel,
    required this.bestTimeMs,
    this.isMe = false,
  });

  factory FriendEntry.fromMap(String uid, Map<String, dynamic> m) =>
      FriendEntry(
        uid: uid,
        name: (m['name'] as String?) ?? '?',
        photoUrl: m['photoUrl'] as String?,
        bestScore: (m['bestScore'] as num?)?.toInt() ?? 0,
        bestLevel: (m['bestLevel'] as num?)?.toInt() ?? 0,
        bestTimeMs: (m['bestTimeMs'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'photoUrl': photoUrl,
        'bestScore': bestScore,
        'bestLevel': bestLevel,
        'bestTimeMs': bestTimeMs,
      };

  factory FriendEntry.fromJson(Map<String, dynamic> j) =>
      FriendEntry.fromMap(j['uid'] as String, j);
}

class FriendRequest {
  final String fromUid;
  final String name;
  final String? photoUrl;

  const FriendRequest({required this.fromUid, required this.name, this.photoUrl});
}
