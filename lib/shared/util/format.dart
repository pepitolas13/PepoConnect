import 'package:intl/intl.dart';

/// "12,4 MB" style sizes (1024-based, locale-aware decimal separator).
String formatBytes(int bytes, {String locale = 'es'}) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit <= 1 ? 0 : (value >= 100 ? 0 : 1);
  return '${formatNumber(value, digits: digits, locale: locale)} ${units[unit]}';
}

/// "68 %" from a 0..1 fraction (non-breaking space before the sign).
String formatPercent(double fraction) => '${(fraction.clamp(0, 1) * 100).round()} %';

/// Locale-aware number with a fixed number of decimals; falls back to a
/// manual format when the locale data is not loaded (tests).
String formatNumber(double value, {int digits = 1, String locale = 'es'}) {
  try {
    return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: digits).format(value);
  } catch (_) {
    final text = value.toStringAsFixed(digits);
    return locale.startsWith('es') ? text.replaceAll('.', ',') : text;
  }
}

/// "hoy, 15:51" / "ayer, 09:12" / "12 de marzo" / "12 de marzo de 2025".
/// [today] and [yesterday] come from the localizations.
String formatDayTime(
  DateTime at, {
  required String today,
  required String yesterday,
  String locale = 'es',
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final local = at.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final nowDay = DateTime(n.year, n.month, n.day);
  final diff = nowDay.difference(day).inDays;
  final time = _time(local, locale);
  if (diff == 0) return '$today, $time';
  if (diff == 1) return '$yesterday, $time';
  return formatDate(local, locale: locale, now: n);
}

/// "12 de marzo" this year, "12 de marzo de 2025" otherwise.
String formatDate(DateTime at, {String locale = 'es', DateTime? now}) {
  final n = now ?? DateTime.now();
  final local = at.toLocal();
  try {
    return local.year == n.year
        ? DateFormat.MMMMd(locale).format(local)
        : DateFormat.yMMMMd(locale).format(local);
  } catch (_) {
    final es = locale.startsWith('es');
    final month = es ? _monthsEs[local.month - 1] : _monthsEn[local.month - 1];
    final base = es ? '${local.day} de $month' : '$month ${local.day}';
    if (local.year == n.year) return base;
    return es ? '$base de ${local.year}' : '$base, ${local.year}';
  }
}

/// Month heading for gallery groups: "Marzo de 2026".
String formatMonth(DateTime at, {String locale = 'es'}) {
  try {
    final text = DateFormat.yMMMM(locale).format(at);
    return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
  } catch (_) {
    final es = locale.startsWith('es');
    final month = es ? _monthsEs[at.month - 1] : _monthsEn[at.month - 1];
    final cap = '${month[0].toUpperCase()}${month.substring(1)}';
    return es ? '$cap de ${at.year}' : '$cap ${at.year}';
  }
}

String _time(DateTime local, String locale) {
  try {
    return DateFormat.Hm(locale).format(local);
  } catch (_) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// "18 s" / "47 min" / "3 h 12 min": how long something has been going.
/// The units read the same in Spanish and English, so this needs no
/// localization.
String formatShortDuration(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds.clamp(0, 59)} s';
  if (d.inHours < 1) return '${d.inMinutes} min';
  final minutes = d.inMinutes.remainder(60);
  return minutes == 0 ? '${d.inHours} h' : '${d.inHours} h $minutes min';
}

/// "1:05" / "12:07:30" for video lengths.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return h > 0 ? '$h:$mm:${s.toString().padLeft(2, '0')}' : '$mm:${s.toString().padLeft(2, '0')}';
}

const _monthsEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
