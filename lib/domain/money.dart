import 'package:intl/intl.dart';

/// A currency. Amounts are always stored as integers in its minor unit
/// (paise, cents), so sums never drift the way doubles do.
class Currency {
  const Currency(this.code, this.symbol, this.decimals, this.locale, this.name);

  final String code;
  final String symbol;
  final int decimals;
  final String locale;
  final String name;

  int get unit {
    var u = 1;
    for (var i = 0; i < decimals; i++) {
      u *= 10;
    }
    return u;
  }

  /// Formats [minor] units, e.g. 123456 paise as "₹1,234.56".
  String format(int minor, {bool compact = false}) {
    final f = compact
        ? NumberFormat.compactCurrency(locale: locale, symbol: symbol, decimalDigits: 0)
        : NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: decimals);
    return f.format(minor / unit);
  }

  /// Formats without the symbol, for editable text fields.
  String plain(int minor) {
    if (decimals == 0) return '$minor';
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    final whole = abs ~/ unit;
    final frac = (abs % unit).toString().padLeft(decimals, '0');
    return '$sign$whole.$frac';
  }

  /// Parses user input into minor units without going through doubles.
  /// Accepts "12", "12.5", "12.50", "1,234.56". Returns null if invalid.
  int? parse(String text) {
    final s = text.trim().replaceAll(',', '').replaceAll(symbol, '').trim();
    final m = RegExp(r'^(\d{0,12})(?:\.(\d*))?$').firstMatch(s);
    if (m == null || (m.group(1)!.isEmpty && (m.group(2) ?? '').isEmpty)) return null;
    final whole = m.group(1)!.isEmpty ? 0 : int.parse(m.group(1)!);
    var frac = m.group(2) ?? '';
    if (frac.length > decimals) return null;
    frac = frac.padRight(decimals, '0');
    return whole * unit + (frac.isEmpty ? 0 : int.parse(frac));
  }

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

const currencies = [
  Currency('INR', '₹', 2, 'en_IN', 'Indian rupee'),
  Currency('USD', r'$', 2, 'en_US', 'US dollar'),
  Currency('EUR', '€', 2, 'en_IE', 'Euro'),
  Currency('GBP', '£', 2, 'en_GB', 'Pound sterling'),
  Currency('JPY', '¥', 0, 'ja_JP', 'Japanese yen'),
  Currency('AED', 'AED ', 2, 'en_AE', 'UAE dirham'),
  Currency('SGD', r'S$', 2, 'en_SG', 'Singapore dollar'),
  Currency('AUD', r'A$', 2, 'en_AU', 'Australian dollar'),
  Currency('CAD', r'C$', 2, 'en_CA', 'Canadian dollar'),
];

Currency currencyFor(String code) => currencies.firstWhere((c) => c.code == code, orElse: () => currencies.first);

/// Splits [total] in proportion to [weights] with the largest-remainder
/// method: everyone gets the floor of their exact share, then the leftover
/// units go to the largest fractional parts (earlier entries win ties).
/// The parts always sum to exactly [total].
List<int> allocate(int total, List<int> weights) {
  if (weights.isEmpty) throw ArgumentError('no weights');
  if (weights.any((w) => w < 0)) throw ArgumentError('negative weight');
  final sum = weights.fold<int>(0, (a, b) => a + b);
  if (sum == 0) throw ArgumentError('weights sum to zero');
  final sign = total < 0 ? -1 : 1;
  final t = total.abs();
  final parts = List<int>.filled(weights.length, 0);
  final remainders = <(int, int)>[]; // (remainder, index)
  var assigned = 0;
  for (var i = 0; i < weights.length; i++) {
    // BigInt keeps t * w exact even for large amounts.
    final exact = BigInt.from(t) * BigInt.from(weights[i]);
    final q = exact ~/ BigInt.from(sum);
    parts[i] = q.toInt();
    assigned += parts[i];
    remainders.add(((exact - q * BigInt.from(sum)).toInt(), i));
  }
  remainders.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
  for (var k = 0; k < t - assigned; k++) {
    parts[remainders[k].$2]++;
  }
  return [for (final p in parts) p * sign];
}
