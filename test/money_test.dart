import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:settle/domain/money.dart';

void main() {
  final inr = currencyFor('INR');
  final jpy = currencyFor('JPY');

  group('parsing', () {
    test('accepts the usual ways people type amounts', () {
      expect(inr.parse('12'), 1200);
      expect(inr.parse('12.5'), 1250);
      expect(inr.parse('12.05'), 1205);
      expect(inr.parse('1,234.56'), 123456);
      expect(inr.parse('₹99'), 9900);
      expect(inr.parse('.5'), 50);
      expect(jpy.parse('1500'), 1500);
    });

    test('rejects what it cannot represent exactly', () {
      expect(inr.parse(''), isNull);
      expect(inr.parse('abc'), isNull);
      expect(inr.parse('1.234'), isNull);
      expect(inr.parse('-5'), isNull);
      expect(jpy.parse('10.5'), isNull);
    });

    test('plain() round-trips through parse()', () {
      final r = Random(1);
      for (var i = 0; i < 1000; i++) {
        final v = r.nextInt(1 << 30);
        expect(inr.parse(inr.plain(v)), v);
      }
    });
  });

  test('formats with Indian digit grouping', () {
    expect(inr.format(12345678), '₹1,23,456.78');
  });

  group('allocate', () {
    test('equal split hands out the leftover paise first come, first served', () {
      expect(allocate(1000, [1, 1, 1]), [334, 333, 333]);
      expect(allocate(100, [1, 1, 1, 1, 1, 1]), [17, 17, 17, 17, 16, 16]);
    });

    test('weights are honoured with largest remainders', () {
      // 3:1 of 999 is 749.25 / 249.75: the 0.75 remainder gets the unit.
      expect(allocate(999, [3, 1]), [749, 250]);
    });

    test('parts always sum to the total and never differ by more than one unit from exact', () {
      final r = Random(2);
      for (var i = 0; i < 5000; i++) {
        final n = r.nextInt(8) + 1;
        final weights = [for (var j = 0; j < n; j++) r.nextInt(10)];
        if (weights.every((w) => w == 0)) weights[0] = 1;
        final total = r.nextInt(1000000);
        final parts = allocate(total, weights);
        expect(parts.reduce((a, b) => a + b), total);
        final sum = weights.reduce((a, b) => a + b);
        for (var j = 0; j < n; j++) {
          final exact = total * weights[j] / sum;
          expect((parts[j] - exact).abs() < 1, isTrue);
        }
      }
    });

    test('handles amounts too large for doubles to multiply exactly', () {
      const big = 900719925474099; // ~2^49 minor units
      expect(allocate(big, [1, 1, 1]).reduce((a, b) => a + b), big);
    });
  });
}
