import 'package:flutter_test/flutter_test.dart';
import 'package:math_jump/l10n/strings.dart';

void main() {
  test('translations fill placeholders', () {
    expect(trLang('vi', 'hello', {'name': 'Bin'}), 'Xin chào, Bin!');
    expect(trLang('en', 'hello', {'name': 'Bin'}), 'Hi, Bin!');
    expect(fmtDuration(83000, 'vi'), '1 phút 23 giây');
    expect(fmtDuration(83000, 'en'), '1m 23s');
  });
}
