import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/format.dart';

void main() {
  test('fmtBytes 单位换算', () {
    expect(fmtBytes(512), '512 B');
    expect(fmtBytes(2048, digits: 0), '2 KB');
    expect(fmtBytes(1536 * 1024, digits: 1), '1.5 MB');
  });

  test('fmtDuration', () {
    expect(fmtDuration(const Duration(seconds: 45)), '45s');
    expect(fmtDuration(const Duration(minutes: 3, seconds: 5)), '3m 5s');
  });
}
