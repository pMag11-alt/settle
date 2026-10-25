import 'package:flutter_test/flutter_test.dart';
import 'package:settle/domain/model.dart';

void main() {
  test('equal', () {
    expect(Split.equal(['a', 'b', 'c']).shares(1000), {'a': 334, 'b': 333, 'c': 333});
  });

  test('exact amounts must add up', () {
    const s = Split(SplitMode.exact, {'a': 700, 'b': 300});
    expect(s.shares(1000), {'a': 700, 'b': 300});
    expect(() => s.shares(1001), throwsA(isA<SplitError>()));
  });

  test('percentages in basis points', () {
    const s = Split(SplitMode.percent, {'a': 3333, 'b': 3333, 'c': 3334});
    final shares = s.shares(10000);
    expect(shares.values.reduce((a, b) => a + b), 10000);
    expect(shares, {'a': 3333, 'b': 3333, 'c': 3334});
    expect(() => const Split(SplitMode.percent, {'a': 5000}).shares(100), throwsA(isA<SplitError>()));
  });

  test('shares as weights', () {
    expect(const Split(SplitMode.shares, {'a': 2, 'b': 1, 'c': 0}).shares(900), {'a': 600, 'b': 300});
  });

  test('nobody to split with is an error', () {
    expect(() => const Split(SplitMode.equal, {}).shares(100), throwsA(isA<SplitError>()));
  });

  test('JSON round trip', () {
    const s = Split(SplitMode.shares, {'a': 2, 'b': 1});
    expect(Split.fromJson(s.toJson()).shares(300), {'a': 200, 'b': 100});
  });
}
