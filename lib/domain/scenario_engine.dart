import 'financial_engine.dart';
import 'models/models.dart';

enum ScenarioActionType {
  increaseIncomePercent,
  reduceExpensePercent,
  addOneTimeIncome,
  addOneTimeExpense,
  deferLiability,
}

class ScenarioAction {
  const ScenarioAction({
    required this.id,
    required this.type,
    this.targetId,
    this.percent,
    this.amountRials,
    this.date,
  });

  final String id;
  final ScenarioActionType type;
  final String? targetId;
  final int? percent;
  final int? amountRials;
  final String? date;
}

class ScenarioMetrics {
  const ScenarioMetrics({required this.current, required this.minimum, required this.minimumDate, required this.negativeDays, required this.finalBalance});
  final int current;
  final int minimum;
  final String minimumDate;
  final int negativeDays;
  final int finalBalance;
}

class ScenarioComparison {
  const ScenarioComparison({required this.baseline, required this.scenario});
  final ScenarioMetrics baseline;
  final ScenarioMetrics scenario;

  int get minimumDelta => scenario.minimum - baseline.minimum;
  int get finalBalanceDelta => scenario.finalBalance - baseline.finalBalance;
  int get negativeDaysDelta => scenario.negativeDays - baseline.negativeDays;
  bool get improves => minimumDelta > 0 || finalBalanceDelta > 0 || negativeDaysDelta < 0;
  bool get worsens => minimumDelta < 0 || finalBalanceDelta < 0 || negativeDaysDelta > 0;
}

/// Pure What-If engine. It creates copies/overlays and never writes to the repository.
class ScenarioEngine {
  const ScenarioEngine._();

  static ScenarioComparison compare({
    required FinancialProfile profile,
    required List<Income> incomes,
    required List<Expense> expenses,
    required List<Liability> liabilities,
    required ScenarioAction action,
    DateTime? today,
    int forecastDays = 180,
  }) {
    final baseline = FinancialEngine.calculate(
      profile: profile,
      incomes: incomes,
      expenses: expenses,
      liabilities: liabilities,
      today: today,
      forecastDays: forecastDays,
    );
    final overlay = _apply(incomes, expenses, liabilities, action, today ?? DateTime.now());
    final scenario = FinancialEngine.calculate(
      profile: profile,
      incomes: overlay.incomes,
      expenses: overlay.expenses,
      liabilities: overlay.liabilities,
      today: today,
      forecastDays: forecastDays,
    );
    return ScenarioComparison(baseline: _metrics(baseline), scenario: _metrics(scenario));
  }

  static _Overlay _apply(List<Income> incomes, List<Expense> expenses, List<Liability> liabilities, ScenarioAction action, DateTime today) {
    final nextIncomes = List<Income>.from(incomes);
    final nextExpenses = List<Expense>.from(expenses);
    final nextLiabilities = List<Liability>.from(liabilities);
    switch (action.type) {
      case ScenarioActionType.increaseIncomePercent:
        final i = nextIncomes.indexWhere((x) => x.id == action.targetId);
        if (i >= 0) {
          final x = nextIncomes[i];
          nextIncomes[i] = Income(id: x.id, title: x.title, amountRials: x.amountRials + _percent(x.amountRials, action.percent ?? 0), frequency: x.frequency, start: x.start, payDay: x.payDay);
        }
      case ScenarioActionType.reduceExpensePercent:
        final i = nextExpenses.indexWhere((x) => x.id == action.targetId);
        if (i >= 0) {
          final x = nextExpenses[i];
          nextExpenses[i] = Expense(id: x.id, title: x.title, amountRials: x.amountRials - _percent(x.amountRials, action.percent ?? 0), frequency: x.frequency, category: x.category, date: x.date, startDate: x.startDate, paymentDay: x.paymentDay);
        }
      case ScenarioActionType.addOneTimeIncome:
        nextIncomes.add(Income(id: action.id, title: 'درآمد سناریویی', amountRials: action.amountRials ?? 0, frequency: 'یک‌بار', start: action.date ?? _iso(today)));
      case ScenarioActionType.addOneTimeExpense:
        nextExpenses.add(Expense(id: action.id, title: 'هزینه سناریویی', amountRials: action.amountRials ?? 0, frequency: 'یک‌بار', category: 'سناریو', date: action.date ?? _iso(today), startDate: action.date ?? _iso(today)));
      case ScenarioActionType.deferLiability:
        final i = nextLiabilities.indexWhere((x) => x.id == action.targetId);
        if (i >= 0) {
          final x = nextLiabilities[i];
          final shifted = _shiftOneOccurrence(x.paymentDate, x.frequency);
          nextLiabilities[i] = Liability(id: x.id, title: x.title, type: x.type, totalRials: x.totalRials, paymentDate: shifted, installmentRials: x.installmentRials, remainingInstallments: x.remainingInstallments, frequency: x.frequency, paymentDay: x.paymentDay);
        }
    }
    return _Overlay(nextIncomes, nextExpenses, nextLiabilities);
  }

  static ScenarioMetrics _metrics(FinancialSnapshot s) => ScenarioMetrics(current: s.currentBalanceRials, minimum: s.minimumBalanceRials, minimumDate: s.minimumPoint.date, negativeDays: s.negativeDays, finalBalance: s.points.isEmpty ? s.currentBalanceRials : s.points.last.balanceRials);
  static int _percent(int value, int p) => (value * p) ~/ 100;
  static String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _shiftOneOccurrence(String raw, String frequency) {
    final start = DateTime.tryParse(raw);
    if (start == null) return raw;
    final f = frequency.replaceAll('‌', '').replaceAll(' ', '').toLowerCase();
    if (f == 'روزانه' || f == 'daily') return _iso(start.add(const Duration(days: 1)));
    if (f == 'هفتگی' || f == 'weekly') return _iso(start.add(const Duration(days: 7)));
    if (f == 'سالانه' || f == 'yearly' || f == 'annual') return _iso(DateTime(start.year + 1, start.month, _clampDay(start.year + 1, start.month, start.day)));
    if (f == 'ماهانه' || f == 'monthly') return _iso(DateTime(start.year, start.month + 1, _clampDay(start.year, start.month + 1, start.day)));
    return _iso(start.add(const Duration(days: 30)));
  }
  static int _clampDay(int year, int month, int day) => day > DateTime(year, month + 1, 0).day ? DateTime(year, month + 1, 0).day : day;
}

class _Overlay {
  const _Overlay(this.incomes, this.expenses, this.liabilities);
  final List<Income> incomes;
  final List<Expense> expenses;
  final List<Liability> liabilities;
}
