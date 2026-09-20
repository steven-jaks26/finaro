import 'package:flutter_test/flutter_test.dart';
import 'package:finaro/domain/scenario_engine.dart';
import 'package:finaro/domain/models/models.dart';

void main() {
  final profile = FinancialProfile(openingBalanceRials: 100000000, openingBalanceDate: '2026-01-01');
  final income = Income(id: 'i1', title: 'حقوق', amountRials: 10000000, frequency: 'ماهانه', start: '2026-01-01');
  final expense = Expense(id: 'e1', title: 'اجاره', amountRials: 8000000, frequency: 'ماهانه', category: 'خانه', date: '2026-01-01', startDate: '2026-01-01');

  test('scenario improves forecast without mutating source records', () {
    final original = expense.amountRials;
    final result = ScenarioEngine.compare(
      profile: profile,
      incomes: [income],
      expenses: [expense],
      liabilities: const [],
      action: const ScenarioAction(id: 's1', type: ScenarioActionType.reduceExpensePercent, targetId: 'e1', percent: 20),
      today: DateTime(2026, 1, 2),
      forecastDays: 180,
    );
    expect(result.improves, isTrue);
    expect(expense.amountRials, original);
  });

  test('one-time scenario income changes only the scenario result', () {
    final result = ScenarioEngine.compare(
      profile: profile,
      incomes: [income],
      expenses: [expense],
      liabilities: const [],
      action: const ScenarioAction(id: 's2', type: ScenarioActionType.addOneTimeIncome, amountRials: 50000000, date: '2026-02-15'),
      today: DateTime(2026, 1, 2),
      forecastDays: 180,
    );
    expect(result.finalBalanceDelta, 50000000);
  });

  test('worsening scenario is detected', () {
    final result = ScenarioEngine.compare(
      profile: profile,
      incomes: [income],
      expenses: [expense],
      liabilities: const [],
      action: const ScenarioAction(id: 's3', type: ScenarioActionType.addOneTimeExpense, amountRials: 90000000, date: '2026-02-15'),
      today: DateTime(2026, 1, 2),
      forecastDays: 180,
    );
    expect(result.worsens, isTrue);
  });
}
