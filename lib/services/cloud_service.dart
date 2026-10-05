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
    // Android: chọn tài khoản Google trên máy, rồi đổi sang tài khoản Firebase.
    // Mã client lấy tự động từ google-services.json.
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
    final uc = await FirebaseAuth.instance
        .signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    return uc.user!;
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

  /// Đẩy kỷ lục và hạng trên máy lên server (chỉ khi cao hơn). Nếu server đang
  /// giữ kỷ lục / hạng cao hơn (chơi trên máy khác) thì trả về để cập nhật máy.
  Future<({GameResult? best, int maxRank})> syncBest({
    required String uid,
    GameResult? localBest,
    required int gamesPlayed,
    required int maxRank,
  }) {
    final ref = _user(uid);
    return _db.runTransaction<({GameResult? best, int maxRank})>((tx) async {
      final snap = await tx.get(ref);
      final d = snap.data() ?? const <String, dynamic>{};
      final remoteGames = (d['gamesPlayed'] as num?)?.toInt() ?? 0;
      final remoteMaxRank = (d['maxRank'] as num?)?.toInt() ?? 0;
      final hasRemote = d['bestScore'] != null;
      final remoteBest = !hasRemote
          ? null
          : GameResult(
              score: (d['bestScore'] as num).toInt(),
              level: (d['bestLevel'] as num?)?.toInt() ?? 1,
              correct: (d['bestCorrect'] as num?)?.toInt() ?? 0,
              durationMs: (d['bestTimeMs'] as num?)?.toInt() ?? 0,
              playedAt: (d['bestAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              rank: (d['bestRank'] as num?)?.toInt() ?? 0,
            );
      final update = <String, dynamic>{
        'gamesPlayed': max(remoteGames, gamesPlayed),
        'maxRank': max(remoteMaxRank, maxRank),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      GameResult? remoteBetter;
      if (localBest != null && localBest.beats(remoteBest)) {
        update.addAll({
          'bestScore': localBest.score,
          'bestLevel': localBest.level,
          'bestCorrect': localBest.correct,
          'bestTimeMs': localBest.durationMs,
          'bestRank': localBest.rank,
          'bestAt': Timestamp.fromDate(localBest.playedAt),
        });
      } else if (remoteBest != null && remoteBest.beats(localBest)) {
        remoteBetter = remoteBest;
      }
      tx.set(ref, update, SetOptions(merge: true));
      return (best: remoteBetter, maxRank: remoteMaxRank);
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

  Future<FriendOp> sendRequest({
    required String uid,
    required String name,
    String? photoUrl,
    required String code,
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
