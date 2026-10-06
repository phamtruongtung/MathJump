import 'package:flutter_test/flutter_test.dart';
import 'package:math_jump/models/social.dart';
import 'package:math_jump/services/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old saved ranks are shifted up by one when Tân Binh is added', () async {
    SharedPreferences.setMockInitialValues({
      // Khách chơi ở bản cũ, chưa thăng hạng lần nào (đang ở Đồng = 0 cũ).
      'history_guest': '[{"score":120,"level":4,"rank":0}]',
      'best_guest': '{"score":120,"level":4,"rank":0}',
      // Tài khoản đã lên Vàng (2 cũ), đang chọn chơi Bạc (1 cũ).
      'history_u1': '[{"score":900,"level":12,"rank":2}]',
      'maxRank_u1': 2,
      'selRank_u1': 1,
      'friends_u1': '[{"uid":"f1","name":"An","bestScore":500,"bestRank":1}]',
    });
    final s = LocalStore();
    await s.init();
    await s.migrateRanks(2);

    expect(s.maxRank('guest'), 1); // Đồng
    expect(s.best('guest')!.rank, 1);
    expect(s.history('guest').first.rank, 1);
    expect(s.maxRank('u1'), 3); // Vàng
    expect(s.selectedRank('u1'), 2); // Bạc
    expect(s.history('u1').first.rank, 3);
    expect(s.friends('u1').first.bestRank, 2);

    // Chạy lại không cộng thêm lần nữa.
    await s.migrateRanks(2);
    expect(s.maxRank('u1'), 3);
  });

  test('a fresh install starts at Tân Binh', () async {
    SharedPreferences.setMockInitialValues({});
    final s = LocalStore();
    await s.init();
    await s.migrateRanks(2);
    expect(s.maxRank('guest'), 0);
  });

  test('deleting an account clears only that account on the device', () async {
    SharedPreferences.setMockInitialValues({
      'history_u1': '[]',
      'maxRank_u1': 3,
      'code_u1': 'ABC234',
      'sent_u1': <String>['u9'],
      'lastAccountId': 'u1',
      'history_guest': '[{"score":50}]',
      'history_u2': '[]',
      'lang': 'vi',
    });
    final s = LocalStore();
    await s.init();
    await s.clearProfileData('u1');
    expect(s.hasData('u1'), isFalse);
    expect(s.maxRank('u1'), 0);
    expect(s.friendCode('u1'), isNull);
    expect(s.sentRequests('u1'), isEmpty);
    expect(s.lastAccountId, isNull);
    expect(s.hasData('guest'), isTrue);
    expect(s.hasData('u2'), isTrue);
    expect(s.lang, 'vi');
  });

  test('cloud rank fields: new tier fields win, legacy ones are shifted', () {
    expect(FriendEntry.cloudTier({'tierBest': 0, 'bestRank': 3}, 'tierBest', 'bestRank'), 0);
    expect(FriendEntry.cloudTier({'bestRank': 2, 'bestScore': 1}, 'tierBest', 'bestRank'), 3);
    expect(FriendEntry.cloudTier({'bestScore': 10}, 'tierBest', 'bestRank'), 1);
    expect(FriendEntry.cloudTier({}, 'tierBest', 'bestRank'), 0);
  });
}
