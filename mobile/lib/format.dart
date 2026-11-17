import 'package:intl/intl.dart';

// Mirrors frontend/src/lib/format.ts.

// Yahoo quotes London in pence (GBp) and Johannesburg in cents (ZAc).
const _currencyLabels = {'GBp': 'GBX', 'ZAc': 'ZAC'};

String currencyLabel(String? currency) {
  if (currency == null || currency.isEmpty) return '';
  return _currencyLabels[currency] ?? currency;
}

int _priceDigits(num value) {
  final abs = value.abs();
  if (abs >= 1) return 2;
  if (abs >= 0.01) return 4;
  return 6;
}

String formatNumber(num? value, [int? digits]) {
  if (value == null || (value is double && value.isNaN)) return '—';
  final d = digits ?? _priceDigits(value);
  return NumberFormat.decimalPatternDigits(locale: 'en_US', decimalDigits: d).format(value);
}

String formatPrice(num? value, [String? currency]) {
  if (value == null) return '—';
  final label = currencyLabel(currency);
  return label.isEmpty ? formatNumber(value) : '${formatNumber(value)} $label';
}

String _sign(num value) => value > 0 ? '+' : (value < 0 ? '−' : '');

String formatSigned(num? value, [int? digits]) {
  if (value == null || (value is double && value.isNaN)) return '—';
  return '${_sign(value)}${formatNumber(value.abs(), digits)}';
}

String formatPercent(num? value, [int digits = 2]) {
  if (value == null || (value is double && value.isNaN)) return '—';
  return '${_sign(value)}${value.abs().toStringAsFixed(digits)}%';
}

/// Fractions (0.123) → "12.30%" — for backtest statistics.
String formatRatioPercent(num? value, {int digits = 2, bool signed = false}) {
  if (value == null || (value is double && value.isNaN)) return '—';
  return signed ? formatPercent(value * 100, digits) : '${(value * 100).toStringAsFixed(digits)}%';
}

String formatCompact(num? value) {
  if (value == null || (value is double && value.isNaN)) return '—';
  return NumberFormat.compact(locale: 'en_US').format(value);
}

/// The API sends naive UTC timestamps; show them in the device's local time.
DateTime? parseApiTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final hasZone = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(iso);
  final parsed = DateTime.tryParse(hasZone ? iso : '${iso}Z');
  return parsed?.toLocal();
}

String formatDateTime(String? iso) {
  final time = parseApiTime(iso);
  return time == null ? '—' : DateFormat('MMM d, HH:mm').format(time);
}

/// "10:42" in local time.
String formatClock(DateTime time) => DateFormat('HH:mm').format(time);

String formatInterval(int seconds) {
  if (seconds % 3600 == 0) return '${seconds ~/ 3600}h';
  if (seconds % 60 == 0) return '${seconds ~/ 60}m';
  return '${seconds}s';
}

String isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime yearsAgo(int years) {
  final now = DateTime.now();
  return DateTime(now.year - years, now.month, now.day);
}
