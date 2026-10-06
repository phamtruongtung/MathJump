import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_web_options.dart';
import '../models/game_result.dart';
import '../models/social.dart';

class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Khi xác nhận xóa tài khoản, người dùng chọn một tài khoản Google khác.
class AccountMismatch implements Exception {
  const AccountMismatch();
}

enum FriendOp { sent, accepted, notFound, self, already, offline, error }

/// Firebase: đăng nhập Google, hồ sơ công khai, kết bạn và điểm của bạn bè.
///
/// Firestore:
///   users/{uid}                          name, photoUrl, friendCode, bestScore, bestLevel, ...
///   users/{uid}/friends/{friendUid}      since
///   friendCodes/{CODE}                   uid
///   friendRequests/{toUid}/incoming/{fromUid}  name, photoUrl, createdAt
class CloudService {
  bool _ready = false;
  bool get ready => _ready;

  static const _timeout = Duration(seconds: 12);
  static const _server = GetOptions(source: Source.server);

  Future<void> init() async {
    try {
      if (kIsWeb) {
        if (!webFirebaseConfigured) throw StateError('webFirebaseOptions not filled in');
        await Firebase.initializeApp(options: webFirebaseOptions);
      } else {
        await Firebase.initializeApp();
      }
      _ready = true;
    } catch (e) {
      debugPrint('[Cloud] Firebase chưa được cấu hình, chạy offline: $e');
    }
  }

  User? get currentUser => _ready ? FirebaseAuth.instance.currentUser : null;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> _friends(String uid) =>
      _user(uid).collection('friends');
  CollectionReference<Map<String, dynamic>> _requests(String uid) =>
      _db.collection('friendRequests').doc(uid).collection('incoming');

  // ---------------- Auth ----------------

  bool _googleReady = false;

  Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      // Trình duyệt: Firebase mở cửa sổ đăng nhập Google.
      try {
        final uc = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
        return uc.user!;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          throw const AuthCancelled();
        }
        rethrow;
      }
    }
    final uc = await FirebaseAuth.instance.signInWithCredential(await _googleCredential());
    return uc.user!;
  }

  /// Android: chọn tài khoản Google trên máy, lấy chứng thực cho Firebase.
  /// Mã client lấy tự động từ google-services.json.
  Future<AuthCredential> _googleCredential() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthCancelled();
      }
      throw Exception(e.toString());
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception('Google did not return an ID token');
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  /// Bắt người dùng chọn lại tài khoản Google để xác nhận (bắt buộc trước khi
  /// xóa tài khoản đăng nhập).
  Future<void> reauthenticate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        await user.reauthenticateWithCredential(await _googleCredential());
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-mismatch') throw const AccountMismatch();
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        throw const AuthCancelled();
      }
      rethrow;
    }
  }

  /// Xóa vĩnh viễn mọi dữ liệu của người chơi trên máy chủ rồi xóa tài khoản
  /// đăng nhập. Phải gọi [reauthenticate] ngay trước đó.
  /// [sentTo]: những người mình đã gửi lời mời (để xóa lời mời còn treo).
  Future<void> deleteAccount({
    required String uid,
    String? friendCode,
    required List<String> sentTo,
  }) async {
    final friendIds =
        (await _friends(uid).get(_server).timeout(_timeout)).docs.map((d) => d.id).toList();
    final incomingIds =
        (await _requests(uid).get(_server).timeout(_timeout)).docs.map((d) => d.id).toList();

    final refs = <DocumentReference<Map<String, dynamic>>>[
      for (final f in friendIds) ...[_friends(uid).doc(f), _friends(f).doc(uid)],
      for (final r in incomingIds) _requests(uid).doc(r),
      for (final t in sentTo) _requests(t).doc(uid),
      if (friendCode != null) _db.collection('friendCodes').doc(friendCode),
    ];
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(400)) {
        batch.delete(r);
      }
      await batch.commit().timeout(_timeout);
    }
    await _user(uid).delete().timeout(_timeout);
    await FirebaseAuth.instance.currentUser?.delete();
    await signOut();
  }

  Future<void> signOut() async {
    if (!kIsWeb && _googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    if (_ready) await FirebaseAuth.instance.signOut();
  }

  // ---------------- Profile & best score ----------------

  /// Tạo/cập nhật hồ sơ công khai và trả về mã kết bạn (6 ký tự).
  Future<String?> ensureProfile({
    required String uid,
    required String name,
    String? photoUrl,
  }) async {
    final ref = _user(uid);
    final snap = await ref.get(_server).timeout(_timeout);
    var code = snap.data()?['friendCode'] as String?;
    for (var i = 0; i < 10 && code == null; i++) {
      final candidate = _randomCode();
      final codeRef = _db.collection('friendCodes').doc(candidate);
      final ok = await _db.runTransaction<bool>((tx) async {
        final s = await tx.get(codeRef);
        if (s.exists) return false;
        tx.set(codeRef, {'uid': uid});
        return true;
      }).timeout(_timeout);
      if (ok) code = candidate;
    }
    await ref.set({
      'name': name,
      'photoUrl': photoUrl,
      'friendCode': code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(_timeout);
    return code;
  }

  /// Kỷ lục có hợp lý không — giống hệt điều kiện trong firestore.rules
  /// (mỗi câu đúng được 10–15 điểm, mỗi câu mất ít nhất 0,3 giây...).
  static bool plausible(GameResult r) =>
      r.score >= 0 &&
      r.score <= 2000000 &&
      r.score <= r.correct * 15 &&
      r.score >= r.correct * 10 &&
      r.durationMs >= r.correct * 300 &&
      r.level >= 1 &&
      r.level <= r.correct + 1 &&
      r.rank >= 0;

  /// Đẩy kỷ lục và hạng trên máy lên server (chỉ khi cao hơn). Nếu server đang
  /// giữ kỷ lục / hạng cao hơn (chơi trên máy khác) thì trả về để cập nhật máy.
  /// Hạng chỉ được tăng 1 bậc mỗi lần ghi (luật chống gian lận); [complete] =
  /// false nghĩa là còn phải đẩy tiếp ở lần đồng bộ sau.
  Future<({GameResult? best, int maxRank, bool complete})> syncBest({
    required String uid,
    GameResult? localBest,
    required int gamesPlayed,
    required int maxRank,
  }) {
    final ref = _user(uid);
    return _db.runTransaction<({GameResult? best, int maxRank, bool complete})>((tx) async {
      final snap = await tx.get(ref);
      final d = snap.data() ?? const <String, dynamic>{};
      final remoteGames = (d['gamesPlayed'] as num?)?.toInt() ?? 0;
      final remoteMaxRank = FriendEntry.cloudTier(d, 'tierMax', 'maxRank');
      final hasRemote = d['bestScore'] != null;
      final remoteBest = !hasRemote
          ? null
          : GameResult(
              score: (d['bestScore'] as num).toInt(),
              level: (d['bestLevel'] as num?)?.toInt() ?? 1,
              correct: (d['bestCorrect'] as num?)?.toInt() ?? 0,
              durationMs: (d['bestTimeMs'] as num?)?.toInt() ?? 0,
              playedAt: (d['bestAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              rank: FriendEntry.cloudTier(d, 'tierBest', 'bestRank'),
            );
      final newMax = max(remoteMaxRank, min(maxRank, remoteMaxRank + 1));
      var complete = newMax >= maxRank;
      final update = <String, dynamic>{};
      if (newMax > remoteMaxRank) update['tierMax'] = newMax;
      if (gamesPlayed > remoteGames) update['gamesPlayed'] = gamesPlayed;

      GameResult? remoteBetter;
      if (localBest != null && localBest.beats(remoteBest)) {
        if (!plausible(localBest)) {
          // Dữ liệu cũ thiếu thông tin: bỏ qua, không đẩy lên nữa.
        } else if (localBest.rank <= newMax) {
          update.addAll({
            'bestScore': localBest.score,
            'bestLevel': localBest.level,
            'bestCorrect': localBest.correct,
            'bestTimeMs': localBest.durationMs,
            'tierBest': localBest.rank,
            'bestAt': Timestamp.fromDate(localBest.playedAt),
          });
        } else {
          complete = false; // đợi hạng được đẩy lên đủ rồi mới ghi kỷ lục
        }
      } else if (remoteBest != null && remoteBest.beats(localBest)) {
        remoteBetter = remoteBest;
      }

      // Không có gì mới thì chỉ đọc, không ghi (tiết kiệm lượt ghi).
      if (update.isNotEmpty) {
        update['updatedAt'] = FieldValue.serverTimestamp();
        tx.set(ref, update, SetOptions(merge: true));
      }
      return (best: remoteBetter, maxRank: remoteMaxRank, complete: complete);
    }).timeout(_timeout);
  }

  // ---------------- Friends ----------------

  Future<List<FriendEntry>> fetchFriends(String uid) async {
    final fs = await _friends(uid).get(_server).timeout(_timeout);
    final ids = fs.docs.map((d) => d.id).toList();
    final out = <FriendEntry>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, min(i + 10, ids.length));
      final q = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get(_server)
          .timeout(_timeout);
      out.addAll(q.docs.map((d) => FriendEntry.fromMap(d.id, d.data())));
    }
    return out;
  }

  Future<List<FriendRequest>> fetchIncoming(String uid) async {
    final q = await _requests(uid).get(_server).timeout(_timeout);
    return q.docs
        .map((d) => FriendRequest(
              fromUid: d.id,
              name: (d.data()['name'] as String?) ?? '?',
              photoUrl: d.data()['photoUrl'] as String?,
            ))
        .toList();
  }

  /// Gửi lời mời theo mã kết bạn. [onSent] nhận uid người được mời.
  Future<FriendOp> sendRequest({
    required String uid,
    required String name,
    String? photoUrl,
    required String code,
    void Function(String targetUid)? onSent,
  }) async {
    final c = code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (c.isEmpty) return FriendOp.notFound;
    return _guard(() async {
      final codeSnap =
          await _db.collection('friendCodes').doc(c).get(_server).timeout(_timeout);
      final target = codeSnap.data()?['uid'] as String?;
      if (target == null) return FriendOp.notFound;
      if (target == uid) return FriendOp.self;
      final already = await _friends(uid).doc(target).get(_server).timeout(_timeout);
      if (already.exists) return FriendOp.already;
      // Người kia đã mời mình trước → đồng ý luôn.
      final reverse = await _requests(uid).doc(target).get(_server).timeout(_timeout);
      if (reverse.exists) {
        await accept(uid: uid, fromUid: target);
        return FriendOp.accepted;
      }
      await _requests(target).doc(uid).set({
        'name': name,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
      onSent?.call(target);
      return FriendOp.sent;
    });
  }

  Future<void> accept({required String uid, required String fromUid}) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    batch.set(_friends(uid).doc(fromUid), {'since': now});
    batch.set(_friends(fromUid).doc(uid), {'since': now});
    batch.delete(_requests(uid).doc(fromUid));
    await batch.commit().timeout(_timeout);
  }

  Future<void> decline({required String uid, required String fromUid}) =>
      _requests(uid).doc(fromUid).delete().timeout(_timeout);

  Future<void> removeFriend({required String uid, required String friendUid}) async {
    final batch = _db.batch();
    batch.delete(_friends(uid).doc(friendUid));
    batch.delete(_friends(friendUid).doc(uid));
    await batch.commit().timeout(_timeout);
  }

  Future<FriendOp> _guard(Future<FriendOp> Function() body) async {
    try {
      return await body();
    } on TimeoutException {
      return FriendOp.offline;
    } on FirebaseException catch (e) {
      debugPrint('[Cloud] $e');
      return e.code == 'unavailable' ? FriendOp.offline : FriendOp.error;
    } catch (e) {
      debugPrint('[Cloud] $e');
      return FriendOp.error;
    }
  }

  static String _randomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // bỏ O/0, I/1 dễ nhầm
    final r = Random.secure();
    return List.generate(6, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }
}
