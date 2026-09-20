import 'financial_engine.dart';
import 'models/models.dart';

/// Deterministic, local-only recommendations derived from the forecast.
/// Recommendations are returned only when the simulated action objectively
/// improves the forecast. Source records are never mutated.
class RecommendationEngine {
  const RecommendationEngine._();

  static List<FinancialRecommendation> build({
    required FinancialProfile profile,
    required List<Income> incomes,
    required List<Expense> expenses,
    required List<Liability> liabilities,
    DateTime? today,
    int forecastDays = 180,
    Map<String, bool>? selection,
    int limit = 5,
  }) {
    final selectedIncomes = _selected(incomes, selection);
    final selectedExpenses = _selected(expenses, selection);
    final selectedLiabilities = _selected(liabilities, selection);
    final baseline = FinancialEngine.calculate(
      profile: profile,
      incomes: selectedIncomes,
      expenses: selectedExpenses,
      liabilities: selectedLiabilities,
      today: today,
      forecastDays: forecastDays,
    );
    final base = _metrics(baseline);
    final candidates = <FinancialRecommendation>[];

    for (final expense in selectedExpenses) {
      if (!_isRecurring(expense.frequency)) continue;
      for (final percent in const [10, 20]) {
        final changed = [...selectedExpenses];
        final index = changed.indexWhere((x) => x.id == expense.id);
        if (index < 0) continue;
        changed[index] = Expense(
          id: expense.id,
          title: expense.title,
          amountRials: _reduced(expense.amountRials, percent),
          frequency: expense.frequency,
          category: expense.category,
          date: expense.date,
          startDate: expense.startDate,
          paymentDay: expense.paymentDay,
        );
        final simulated = FinancialEngine.calculate(
          profile: profile,
          incomes: selectedIncomes,
          expenses: changed,
          liabilities: selectedLiabilities,
          today: today,
          forecastDays: forecastDays,
        );
        final metrics = _metrics(simulated);
        if (_improves(base, metrics)) {
          candidates.add(FinancialRecommendation(
            id: 'reduce-expense-${expense.id}-$percent',
            type: RecommendationType.reduceRecurringExpense,
            title: 'کاهش $percent٪ هزینه «${expense.title}»',
            assumption: 'قابل کاهش بودن این هزینه بدون ایجاد تعهد جدید',
            targetId: expense.id,
            percent: percent,
            impact: _impact(base, metrics),
          ));
        }
      }
    }

    for (final income in selectedIncomes) {
      if (!_isRecurring(income.frequency)) continue;
      for (final percent in const [5, 10]) {
        final changed = [...selectedIncomes];
        final index = changed.indexWhere((x) => x.id == income.id);
        if (index < 0) continue;
        changed[index] = Income(
          id: income.id,
          title: income.title,
          amountRials: income.amountRials + _increase(income.amountRials, percent),
          frequency: income.frequency,
          start: income.start,
          payDay: income.payDay,
        );
        final simulated = FinancialEngine.calculate(
          profile: profile,
          incomes: changed,
          expenses: selectedExpenses,
          liabilities: selectedLiabilities,
          today: today,
          forecastDays: forecastDays,
        );
        final metrics = _metrics(simulated);
        if (_improves(base, metrics)) {
          candidates.add(FinancialRecommendation(
            id: 'increase-income-${income.id}-$percent',
            type: RecommendationType.increaseRecurringIncome,
            title: 'افزایش $percent٪ درآمد «${income.title}»',
            assumption: 'امکان افزایش پایدار این درآمد',
            targetId: income.id,
            percent: percent,
            impact: _impact(base, metrics),
          ));
        }
      }
    }

    candidates.sort((a, b) => b.impact.score.compareTo(a.impact.score));
    final safeLimit = limit.clamp(1, 20);
    return candidates.take(safeLimit).toList(growable: false);
  }

  static List<T> _selected<T>(List<T> records, Map<String, bool>? selection) {
    if (selection == null) return List<T>.from(records);
    return records.where((record) {
      final id = switch (record) {
        Income x => x.id,
        Expense x => x.id,
        Liability x => x.id,
        _ => '',
      };
      return selection[id] != false;
    }).toList();
  }

  static bool _isRecurring(String frequency) => const {'روزانه', 'هفتگی', 'ماهانه', 'سالانه', 'weekly', 'monthly', 'yearly', 'daily'}.contains(frequency.trim());

  static int _reduced(int amount, int percent) => (amount * (100 - percent) / 100).round().clamp(1, amount) as int;
  static int _increase(int amount, int percent) => (amount * percent / 100).round().clamp(1, amount) as int;

  static _Metrics _metrics(FinancialSnapshot snapshot) => _Metrics(
    negativeDays: snapshot.negativeDays,
    minimumBalanceRials: snapshot.minimumBalanceRials,
    finalBalanceRials: snapshot.points.isEmpty ? snapshot.currentBalanceRials : snapshot.points.last.balanceRials,
    critical: snapshot.isCritical,
  );

  static bool _improves(_Metrics base, _Metrics candidate) {
    if (base.critical && !candidate.critical) return true;
    if (candidate.negativeDays > base.negativeDays) return false;
    return candidate.minimumBalanceRials > base.minimumBalanceRials || candidate.finalBalanceRials > base.finalBalanceRials;
  }

  static RecommendationImpact _impact(_Metrics base, _Metrics candidate) {
    final statusImprovement = base.critical && !candidate.critical ? 1000000000 : 0;
    final negativeDayImprovement = (base.negativeDays - candidate.negativeDays) * 1000000;
    final minimumImprovement = (candidate.minimumBalanceRials - base.minimumBalanceRials) * 10;
    final finalImprovement = candidate.finalBalanceRials - base.finalBalanceRials;
    return RecommendationImpact(
      minimumBalanceDeltaRials: candidate.minimumBalanceRials - base.minimumBalanceRials,
      finalBalanceDeltaRials: finalImprovement,
      negativeDaysDelta: candidate.negativeDays - base.negativeDays,
      statusBeforeCritical: base.critical,
      statusAfterCritical: candidate.critical,
      score: statusImprovement + negativeDayImprovement + minimumImprovement + finalImprovement,
    );
  }
}

class _Metrics {
  const _Metrics({required this.negativeDays, required this.minimumBalanceRials, required this.finalBalanceRials, required this.critical});
  final int negativeDays;
  final int minimumBalanceRials;
  final int finalBalanceRials;
  final bool critical;
}

enum RecommendationType { reduceRecurringExpense, increaseRecurringIncome }

class FinancialRecommendation {
  const FinancialRecommendation({required this.id, required this.type, required this.title, required this.assumption, required this.targetId, required this.percent, required this.impact});
  final String id;
  final RecommendationType type;
  final String title;
  final String assumption;
  final String targetId;
  final int percent;
  final RecommendationImpact impact;
}

class RecommendationImpact {
  const RecommendationImpact({required this.minimumBalanceDeltaRials, required this.finalBalanceDeltaRials, required this.negativeDaysDelta, required this.statusBeforeCritical, required this.statusAfterCritical, required this.score});
  final int minimumBalanceDeltaRials;
  final int finalBalanceDeltaRials;
  final int negativeDaysDelta;
  final bool statusBeforeCritical;
  final bool statusAfterCritical;
  final int score;
}
