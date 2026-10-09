import 'package:flutter_test/flutter_test.dart';
import 'package:math_jump/models/names.dart';
import 'package:math_jump/models/social.dart';

void main() {
  test('names are normalized for search (no Vietnamese accents, lowercase)', () {
    expect(normalizeName('  Nguyễn  Minh Đức '), 'nguyen minh duc');
    expect(normalizeName('Phạm Trường Tùng'), 'pham truong tung');
    expect(normalizeName('BÉ NA'), 'be na');
  });

  test('display name validation', () {
    expect(validateDisplayName('A'), 'nameTooShort');
    expect(validateDisplayName('   '), 'nameTooShort');
    expect(validateDisplayName('x' * 21), 'nameTooLong');
    expect(validateDisplayName('Bé Lớn'), isNull); // "Lớn" là tên bình thường
    expect(validateDisplayName('Minh Anh 2015'), isNull);
    expect(validateDisplayName('đéo biết'), 'nameBad');
    expect(validateDisplayName('Fuck you'), 'nameBad');
    expect(cleanDisplayName('  Bé   Na  '), 'Bé Na');
  });

  test('email hash is one-way, stable and case-insensitive', () {
    final h = emailHash('Test.User@Gmail.com ');
    expect(h, hasLength(64));
    expect(h, emailHash('test.user@gmail.com'));
    expect(h, isNot(contains('gmail')));
    expect(emailHash('a@gmail.com'), isNot(emailHash('b@gmail.com')));
  });

  test('friend suggestions: friends of friends, ranked by mutual friends', () {
    FriendEntry f(String uid, List<String> friendIds) => FriendEntry(
        uid: uid, name: uid, bestScore: 0, bestLevel: 0, bestTimeMs: 0, friendIds: friendIds);
    final friends = [
      f('a', ['me', 'b', 'x', 'y']),
      f('b', ['me', 'a', 'x', 'z']),
      f('c', ['me', 'x', 'y']),
    ];
    final s = friendSuggestions(myUid: 'me', friends: friends, exclude: {'z'});
    expect(s.keys.first, 'x'); // 3 bạn chung
    expect(s['x'], 3);
    expect(s['y'], 2);
    expect(s.containsKey('me'), isFalse); // không gợi ý chính mình
    expect(s.containsKey('a'), isFalse); // đã là bạn
    expect(s.containsKey('z'), isFalse); // đã gửi lời mời / đã mời mình
  });
}
