import 'models/models.dart';

/// Deterministic local financial ledger/forecast engine.
/// Money is always integer Rial. UI formatting belongs outside this layer.
class FinancialEngine {
  const FinancialEngine._();

  static FinancialSnapshot calculate({
    required FinancialProfile profile,
    required List<Income> incomes,
    required List<Expense> expenses,
    required List<Liability> liabilities,
    DateTime? today,
    int forecastDays = 180,
  }) {
    final now = _dateOnly(today ?? DateTime.now());
    final openingDate = _parseDate(profile.openingBalanceDate ?? '') ?? _earliestActivity(incomes, expenses, liabilities) ?? now;
    final current = _balanceOnDate(
      openingBalance: profile.openingBalanceRials,
      openingDate: openingDate,
      target: now,
      incomes: incomes,
      expenses: expenses,
      liabilities: liabilities,
    );

    final points = <ForecastPoint>[];
    var balance = current;
    for (var offset = 1; offset <= forecastDays; offset++) {
      final date = now.add(Duration(days: offset));
      balance += _netForDate(date, incomes, expenses, liabilities);
      points.add(ForecastPoint(date: _iso(date), balanceRials: balance));
    }
    return FinancialSnapshot(currentBalanceRials: current, currentDate: _iso(now), points: points);
  }

  static int _balanceOnDate({
    required int openingBalance,
    required DateTime openingDate,
    required DateTime target,
    required List<Income> incomes,
    required List<Expense> expenses,
    required List<Liability> liabilities,
  }) {
    if (target.isBefore(openingDate)) return openingBalance;
    var balance = openingBalance;
    for (var date = openingDate; !date.isAfter(target); date = date.add(const Duration(days: 1))) {
      balance += _netForDate(date, incomes, expenses, liabilities);
    }
    return balance;
  }

  static int _netForDate(DateTime date, List<Income> incomes, List<Expense> expenses, List<Liability> liabilities) {
    var net = 0;
    for (final x in incomes) {
      if (_occurs(x.start, x.frequency, x.payDay, date)) net += x.amountRials;
    }
    for (final x in expenses) {
      final start = x.startDate.trim().isEmpty ? x.date : x.startDate;
      if (_occurs(start, x.frequency, x.paymentDay, date)) net -= x.amountRials;
    }
    for (final x in liabilities) {
      if (_liabilityOccurs(x, date)) {
        net -= x.type == 'قسط' ? x.installmentRials : x.totalRials;
      }
    }
    return net;
  }

  static bool _liabilityOccurs(Liability x, DateTime date) {
    if (!_occurs(x.paymentDate, x.frequency, x.paymentDay, date)) return false;
    if (x.type != 'قسط' || x.remainingInstallments <= 0) return x.type != 'قسط';
    final start = _parseDate(x.paymentDate);
    if (start == null) return false;
    final n = _occurrenceIndex(start, x.frequency, x.paymentDay, date);
    return n != null && n >= 0 && n < x.remainingInstallments;
  }

  static int? _occurrenceIndex(DateTime start, String frequency, int? day, DateTime date) {
    if (date.isBefore(start)) return null;
    final f = _normalizeFrequency(frequency);
    if (f == 'once') return _same(start, date) ? 0 : null;
    if (f == 'daily') return date.difference(start).inDays;
    if (f == 'weekly') return date.difference(start).inDays % 7 == 0 ? date.difference(start).inDays ~/ 7 : null;
    if (f == 'yearly') {
      if (date.month != start.month || date.day != start.day) return null;
      return date.year - start.year;
    }
    if (f == 'monthly') {
      final months = (date.year - start.year) * 12 + date.month - start.month;
      final wanted = day ?? start.day;
      final actual = _clampDay(date.year, date.month, wanted);
      return date.day == actual ? months : null;
    }
    return null;
  }

  static bool _occurs(String rawStart, String frequency, int? day, DateTime date) {
    final start = _parseDate(rawStart);
    if (start == null || date.isBefore(start)) return false;
    return _occurrenceIndex(start, frequency, day, date) != null;
  }

  static String _normalizeFrequency(String value) {
    final f = value.trim().replaceAll('‌', '').replaceAll(' ', '');
    if (f == 'یکبار' || f == 'همینماه' || f == 'یکبارها' || f == 'one-time') return 'once';
    if (f == 'روزانه' || f == 'daily') return 'daily';
    if (f == 'هفتگی' || f == 'weekly') return 'weekly';
    if (f == 'ماهانه' || f == 'monthly') return 'monthly';
    if (f == 'سالانه' || f == 'yearly' || f == 'annual') return 'yearly';
    return 'once';
  }

  static DateTime? _earliestActivity(List<Income> incomes, List<Expense> expenses, List<Liability> liabilities) {
    final dates = <DateTime>[];
    for (final x in incomes) { final d = _parseDate(x.start); if (d != null) dates.add(d); }
    for (final x in expenses) { final d = _parseDate(x.startDate.trim().isEmpty ? x.date : x.startDate); if (d != null) dates.add(d); }
    for (final x in liabilities) { final d = _parseDate(x.paymentDate); if (d != null) dates.add(d); }
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  static DateTime? _parseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final d = DateTime.tryParse(raw);
    return d == null ? null : _dateOnly(d);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static int _clampDay(int year, int month, int day) {
    final last = DateTime(year, month + 1, 0).day;
    return day > last ? last : (day < 1 ? 1 : day);
  }
  static String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class FinancialSnapshot {
  const FinancialSnapshot({required this.currentBalanceRials, required this.currentDate, required this.points});
  final int currentBalanceRials;
  final String currentDate;
  final List<ForecastPoint> points;

  int get minimumBalanceRials => points.isEmpty ? currentBalanceRials : points.map((x) => x.balanceRials).reduce((a, b) => a < b ? a : b);
  ForecastPoint get minimumPoint => points.isEmpty ? ForecastPoint(date: currentDate, balanceRials: currentBalanceRials) : points.firstWhere((x) => x.balanceRials == minimumBalanceRials);
  int get negativeDays => points.where((x) => x.balanceRials < 0).length;
  bool get isCritical => negativeDays > 0;
}
