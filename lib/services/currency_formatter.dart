import 'package:intl/intl.dart';

class CurrencyFormatter {
  const CurrencyFormatter._();

  static String formatRand(
    dynamic value, {
    String fallback = 'Budget not set',
  }) {
    if (value == null) return fallback;

    if (value is num) {
      return _formatNumber(value);
    }

    final text = value.toString().trim();
    if (text.isEmpty) return fallback;

    final amount = _parseAmount(text);
    if (amount != null) {
      return _formatNumber(amount);
    }

    if (text.startsWith(r'$')) {
      return 'R${text.substring(1).trim()}';
    }

    if (text.toUpperCase().startsWith('USD')) {
      return 'R${text.substring(3).trim()}';
    }

    return text;
  }

  static num? _parseAmount(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'\bzar\b|\busd\b', caseSensitive: false), '')
        .replaceAll('R', '')
        .replaceAll(r'$', '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return null;
    return num.tryParse(cleaned);
  }

  static String _formatNumber(num value) {
    final decimalDigits = value % 1 == 0 ? 0 : 2;
    return NumberFormat.currency(
      locale: 'en_ZA',
      symbol: 'R',
      decimalDigits: decimalDigits,
    ).format(value);
  }
}
