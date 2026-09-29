import 'package:intl/intl.dart';

String formatPrice(double? value, [String currency = 'USD']) {
  if (value == null) return '—';
  final format = NumberFormat.simpleCurrency(name: currency);
  return format.format(value);
}

String formatPercent(double? value) {
  if (value == null) return '—';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String formatCompact(double? value) {
  if (value == null) return '—';
  return NumberFormat.compact().format(value);
}
